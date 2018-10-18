require 'spec_helper'

module Bosh::Director
  describe Lock, truncation: true, :if => ENV.fetch('DB', 'sqlite') != 'sqlite' do
    let!(:task) { Models::Task.make(state: 'processing') }
    before do
      allow(Config).to receive_message_chain(:current_job, :username).and_return('current-user')
      allow(Config).to receive_message_chain(:current_job, :task_id).and_return(task.id)
    end

    it 'should acquire a lock' do
      lock = Lock.new('foo')

      ran_once = false
      lock.lock do
        ran_once = true
      end

      expect(ran_once).to be(true)
    end

    it 'should renew a lock' do
      lock = Lock.new('foo', expiration: 1)

      expected = false

      lock.lock do
        initial_expired_at = Models::Lock.where(name: 'foo').first.expired_at

        sleep 3

        expect(Models::Lock.where(name: 'foo').first.expired_at).to be > initial_expired_at

        expected = true
      end

      expect(expected).to be(true)
    end

    it 'should not let two clients to acquire the same lock at the same time' do
      lock_a = Lock.new('foo', task_id: 1)
      lock_b = Lock.new('foo', timeout: 0.1)

      lock_a_block_run = false
      lock_b_block_run = false
      lock_a.lock do
        lock_a_block_run = true
        expect do
          lock_b.lock { lock_b_block_run = true }
        end.to raise_exception(Lock::TimeoutError, /Failed to acquire lock for foo uid: .* Locking task id is 1/)
      end

      expect(lock_a_block_run).to be(true)
      expect(lock_b_block_run).to be(false)
    end

    it 'should return immediately with lock busy if try lock fails to get lock' do
      lock_a = Lock.new('foo', { timeout: 0, task_id: 1 })
      lock_b = Lock.new('foo', timeout: 0)

      ran_once = false
      lock_a.lock do
        ran_once = true
        expect { lock_b.lock {} }.to raise_exception(Lock::TimeoutError, /Failed to acquire lock for foo uid: .* Locking task id is 1/)
      end

      expect(ran_once).to be(true)
    end

    context 'when using blocked_by' do
      let(:lock_foo) { Lock.new('foo', deployment_name: 'my-deployment', blocked_by: 'bar') }

      context 'no blocked_by lock exist' do
        it 'should acquire lock' do
          lock_foo_acquired = false

          lock_foo.lock do
            lock_foo_acquired = true
          end

          expect(lock_foo_acquired).to be(true)
        end
      end

      context 'blocked_by lock exist' do
        it 'should not acquire lock' do
          lock_foo_acquired = false
          lock_bar = Lock.new('bar', deployment_name: 'my-deployment', task_id: 1)

          expect do
            lock_bar.lock { lock_foo.lock { lock_foo_acquired = true } }
          end.to raise_exception(Lock::TimeoutError, /Failed to acquire lock for foo uid: .* Blocked by other locks/)
          expect(lock_foo_acquired).to be(false)
        end

        context 'blocked_by lock gets created simultaneously with actual lock' do
          let(:lock_foo) { Lock.new('foo', deployment_name: 'my-deployment', blocked_by: 'bar') }

          it 'should not acquire lock' do
            original_method = Models::Lock.method(:create)
            expect(Models::Lock).to receive(:create).at_least(3).times do |*args, &block|
              # should lock 'bar' here as it is used as blocked_by for 'foo'
              if args[0][:name] == 'foo'
                bar_args = [{ :name => 'bar',
                  :uid => SecureRandom.uuid,
                  :expired_at => Time.at(Time.now.to_f + 60),
                  :task_id => '2' }]
                original_method.call(*bar_args, &block)
              end

              original_method.call(*args, &block)
            end

            lock_foo_acquired = false
            expect do
              lock_foo.lock { lock_foo_acquired = true }
            end.to raise_exception(Lock::TimeoutError, /Failed to acquire lock for foo uid: .*/)

            expect(lock_foo_acquired).to be(false)

            # clean up
            expect(Models::Lock.where(name: 'foo').delete).to be(0) # should be no lock on foo
            expect(Models::Lock.where(name: 'bar').delete).to be(1) # blocked_by lock on 'bar' must be manually deleted
          end
        end

      end
    end

    it 'should return info about gone task' do
      lock_a = Lock.new('foo')
      lock_b = Lock.new('foo')

      lock_a.lock do
        allow(lock_b).to receive(:current_lock).and_return(nil)
        expect do
          lock_b.lock { something }
        end.to raise_exception(Lock::TimeoutError, /Failed to acquire lock for foo uid: .* Lock is gone/)
      end
    end

    it 'should record task id' do
      lock = Lock.new('foo', timeout: 0)
      lock.lock do
        expect(Models::Lock.first.task_id).to eq(task.id.to_s)
      end
    end

    describe 'event recordings' do
      before do
        allow(Config).to receive(:record_events).and_return(true)
      end

      context 'when a lock is acquired' do
        it 'should record an event' do
          lock = Lock.new('foo', deployment_name: 'my-deployment')

          expect { lock.lock {} }.to change {
            Models::Event.where(
                action: 'acquire', object_type: 'lock', object_name: 'foo', user: 'current-user', task: "#{task.id}", deployment: 'my-deployment'
            ).count
          }.from(0).to(1)
        end
      end

      context 'when a lock is released' do
        it 'should record an event' do
          lock = Lock.new('foo', deployment_name: 'my-deployment')

          expect { lock.lock {} }.to change {
            Models::Event.where(
                action: 'release', object_type: 'lock', object_name: 'foo', user: 'current-user', task: "#{task.id}", deployment: 'my-deployment'
            ).count
          }.from(0).to(1)
        end

        it 'should not update the state of the running task' do
          lock = Lock.new('foo', deployment_name: 'my-deployment')

          expect(Models::Task.where(state: 'processing').count).to eq 1
          expect(Models::Task.where(state: 'cancelling').count).to eq 0

          lock.lock {}

          expect(Models::Task.where(state: 'processing').count).to eq 1
          expect(Models::Task.where(state: 'cancelling').count).to eq 0
        end
      end

      context 'when a lock is lost' do
        def destroy_lock_record(lock_name)
          Thread.new do
            until false
              x = Models::Lock.where(name: lock_name).delete
              break if x > 0
              sleep 0.1
            end
          end
        end

        it 'should record an event' do
          lock = Lock.new('foo', deployment_name: 'my-deployment', expiration: 1)

          destroy_lock_record('foo')

          expect(Models::Event.where(action: 'lost').count).to eq 0

          lock.lock { sleep 2 }

          expect(Models::Event.where(
              action: 'lost', object_type: 'lock', object_name: 'foo', user: 'current-user', task: "#{task.id}", deployment: 'my-deployment'
          ).count).to eq 1
        end

        it 'should cancel the running task' do
          lock = Lock.new('foo', deployment_name: 'my-deployment', expiration: 1)

          destroy_lock_record('foo')

          expect(Models::Task.where(state: 'cancelling').count).to eq 0

          lock.lock { sleep 2 }

          expect(Models::Task.where(state: 'cancelling').count).to eq 1
        end
      end
    end
  end
end
