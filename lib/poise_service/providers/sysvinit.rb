#
# Copyright 2015, Noah Kantrowitz
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'poise_service/providers/base'


module PoiseService
  module Providers
    class Sysvinit < Base
      poise_service_provides(:sysvinit)

      def self.provides_auto?(node, resource)
        [:debian, :redhat, :invokercd].any? {|name| service_resource_hints.include?(name) }
      end

      private

      def service_resource
        super.tap do |r|
          r.provider(case node['platform_family']
          when 'debian'
            Chef::Provider::Service::Init::Debian
          when 'rhel'
            Chef::Provider::Service::Init::Redhat
          else
            # This will explode later in the template, but better than nothing for later.
            Chef::Provider::Service::Init
          end)
        end
      end

      def create_service
        parts = new_resource.command.split(/ /, 2)
        daemon = ENV['PATH'].split(/:/)
          .map {|path| ::File.absolute_path(parts[0], path) }
          .find {|path| ::File.exist?(path) } || parts[0]
        template "/etc/init.d/#{new_resource.service_name}" do
          owner 'root'
          group 'root'
          mode '755'
          if options['template']
            parts = options['template'].split(/:/, 2)
            if parts.length == 2
              source parts[1]
              cookbook parts[0]
            else
              source parts.first
              cookbook new_resource.cookbook_name.to_s
            end
          else
            source 'sysvinit.sh.erb'
            cookbook 'poise-service'
          end
          variables(
            daemon: daemon,
            daemon_options: parts[1].to_s,
            name: new_resource.service_name,
            new_resource: new_resource,
            options: options,
            pid_file: options['pid_file'] || "/var/run/#{new_resource.service_name}.pid",
            pid_file_external: !!options['pid_file'],
            platform_family: node['platform_family'],
            stop_signal: new_resource.stop_signal,
            user: new_resource.user,
            working_dir: new_resource.directory,
          )
        end
      end
    end
  end
end
