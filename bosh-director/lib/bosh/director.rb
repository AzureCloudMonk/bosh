# Copyright (c) 2009-2012 VMware, Inc.

module Bosh
  module Director
  end
end

require 'digest/sha1'
require 'erb'
require 'fileutils'
require 'forwardable'
require 'logger'
require 'monitor'
require 'optparse'
require 'ostruct'
require 'pathname'
require 'pp'
require 'thread'
require 'tmpdir'
require 'yaml'
require 'time'
require 'zlib'

require 'common/runs_commands'
require 'common/exec'
require 'common/properties'

require 'bcrypt'
require 'blobstore_client'
require 'eventmachine'
require 'netaddr'
require 'resque'
require 'sequel'
require 'sinatra/base'
require 'securerandom'
require 'yajl'
require 'nats/client'
require 'securerandom'

require 'common/thread_formatter'
require 'bosh/core/encryption_handler'
require 'bosh/director/api'
require 'bosh/director/dns_helper'
require 'bosh/director/errors'
require 'bosh/director/ext'
require 'bosh/director/ip_util'
require 'bosh/director/lock_helper'
require 'bosh/director/validation_helper'
require 'bosh/director/download_helper'

require 'bosh/director/version'
require 'bosh/director/next_rebase_version'
require 'bosh/director/config'
require 'bosh/director/event_log'
require 'bosh/director/task_result_file'
require 'bosh/director/blob_util'

require 'bosh/director/agent_client'
require 'cloud'
require 'bosh/director/compile_task'
require 'bosh/director/configuration_hasher'
require 'bosh/director/cycle_helper'
require 'bosh/director/encryption_helper'
require 'bosh/director/vm_creator'
require 'bosh/director/vm_metadata_updater'
require 'bosh/director/vm_data'
require 'bosh/director/vm_reuser'
require 'bosh/director/deployment_plan'
require 'bosh/director/deployment_plan/assembler'
require 'bosh/director/duration'
require 'bosh/director/hash_string_vals'
require 'bosh/director/instance_deleter'
require 'bosh/director/instance_updater'
require 'bosh/director/job_runner'
require 'bosh/director/job_updater'
require 'bosh/director/job_queue'
require 'bosh/director/tar_gzipper'
require 'bosh/director/lock'
require 'bosh/director/nats_rpc'
require 'bosh/director/network_reservation'
require 'bosh/director/package_compiler'
require 'bosh/director/problem_scanner'
require 'bosh/director/problem_resolver'
require 'bosh/director/resource_pool_updater'
require 'bosh/director/sequel'
require 'common/thread_pool'

require 'bosh/director/cloudcheck_helper'
require 'bosh/director/problem_handlers/base'
require 'bosh/director/problem_handlers/invalid_problem'
require 'bosh/director/problem_handlers/inactive_disk'
require 'bosh/director/problem_handlers/out_of_sync_vm'
require 'bosh/director/problem_handlers/unresponsive_agent'
require 'bosh/director/problem_handlers/unbound_instance_vm'
require 'bosh/director/problem_handlers/mount_info_mismatch'
require 'bosh/director/problem_handlers/missing_vm'

require 'bosh/director/jobs/base_job'
require 'bosh/director/jobs/backup'
require 'bosh/director/jobs/scheduled_backup'
require 'bosh/director/jobs/create_snapshot'
require 'bosh/director/jobs/snapshot_deployment'
require 'bosh/director/jobs/snapshot_deployments'
require 'bosh/director/jobs/snapshot_self'
require 'bosh/director/jobs/delete_deployment'
require 'bosh/director/jobs/delete_deployment_snapshots'
require 'bosh/director/jobs/delete_release'
require 'bosh/director/jobs/delete_snapshots'
require 'bosh/director/jobs/delete_stemcell'
require 'bosh/director/jobs/update_deployment'
require 'bosh/director/jobs/update_release'
require 'bosh/director/jobs/update_stemcell'
require 'bosh/director/jobs/fetch_logs'
require 'bosh/director/jobs/vm_state'
require 'bosh/director/jobs/cloud_check/scan'
require 'bosh/director/jobs/cloud_check/scan_and_fix'
require 'bosh/director/jobs/cloud_check/apply_resolutions'
require 'bosh/director/jobs/ssh'

require 'bosh/director/models/helpers/model_helper'

require 'bosh/director/db_backup'
require 'bosh/director/blobstores'
require 'bosh/director/app'

module Bosh::Director
  autoload :Models, 'bosh/director/models' # Defining model classes relies on a database connection
end

require 'bosh/director/thread_pool'
require 'bosh/director/api/controller_helpers'
require 'bosh/director/api/controller'
