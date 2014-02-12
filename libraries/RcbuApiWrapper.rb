# Cookbook Name:: rackspace_cloudbackup
#
# Copyright 2014, Rackspace, US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'json'
require 'rest_client'

module Opscode
  module Rackspace
    module CloudBackup
      class RcbuApiWrapper
        attr_accessor :token, :rcbu_api_url, :agent_id, :configurations

        def initialize(api_username, api_key, region, agent_id)
          @agent_id = agent_id

          identity = identity_data(api_username, api_key)
          @token = identity['access']['token']['id']

          backup_catalog = identity['access']['serviceCatalog'].find { |c| c['name'] == 'cloudBackup' }
          fail 'Opscode::Rackspace::CloudBackup::RcbuBinding.initialize: Unable to locate cloudBackup service catalog' if backup_catalog.nil?

          region.upcase!
          backup_catalog_region = backup_catalog['endpoints'].find { |e| e['region'] == region }
          fail "Opscode::Rackspace::CloudBackup::RcbuBinding.initialize: Unable to locate CloudBackup details from service catalog for region #{region}" if backup_catalog_region.nil?
          @rcbu_api_url = backup_catalog_region['publicURL']
          fail "Opscode::Rackspace::CloudBackup::RcbuBinding.initialize: Unable to locate CloudBackup API URL from service catalog for region #{region}" if @rcbu_api_url.nil?
        end

        def identity_data(api_username, api_key, api_url = 'https://identity.api.rackspacecloud.com/v2.0/tokens')
          req = { 'auth' =>
            { 'RAX-KSKEY:apiKeyCredentials' =>
              { 'username' => api_username,
                'apiKey'   => api_key
              }
            }
          }
          
          return JSON.parse(RestClient.post(api_url, req.to_json,  content_type: :json, accept: :json))
        end

        def lookup_configurations
          @configurations = JSON.parse(RestClient.get("#{@rcbu_api_url}/backup-configuration/system/#{@agent_id}",
                                                      'Content-Type' => :json, 'X-Auth-Token' => @token))
        end

        def locate_existing_config(label)
          unless @configurations.nil?
            config = @configurations.find { |c| c['BackupConfigurationName'] == label }
            unless config.nil?
              return config
            end
          end

          lookup_configurations
          @configurations.find { |c| c['BackupConfigurationName'] == label }
        end

        def create_config(config)
          RestClient.post("#{@rcbu_api_url}/backup-configuration/",
                          config.to_json,
                          'Content-Type' => :json, 'X-Auth-Token' => @token)
        end

        def update_config(config_id, config)
          RestClient.put("#{@rcbu_api_url}/backup-configuration/#{config_id}",
                         config.to_json,
                         'Content-Type' => :json, 'X-Auth-Token' => @token)
        end
      end
    end
  end
end