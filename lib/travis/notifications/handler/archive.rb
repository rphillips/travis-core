require 'core_ext/module/include'
require 'faraday'
require 'cgi'

module Travis
  module Notifications
    module Handler
      class Archive
        EVENTS = 'build:finished'

        include Logging

        class << self
          def payload_for(build)
            Payload.new(build).to_hash
          end

          def http_client
            @http_client ||= Faraday.new do |f|
              f.request :url_encoded
              f.adapter :net_http
            end
          end

          def http_client=(http_client)
            @http_client = http_client
          end
        end

        include do
          def notify(event, object, *args)
            archive(object)
          rescue Exception => e
            log_exception(e)
          end

          protected

            def archive(build)
              build.touch(:archived_at) if store(build)
            end

            def store(build)
              response = http.put(url_for(build), json_for(build))
              log_request(build, response)
              response.success?
            end

            def config
              Travis.config.archive
            end

            def url_for(build)
              "http://#{config.username}:#{CGI.escape(config.password)}@#{config.host}/builds/#{build.id}"
            end

            def json_for(build)
              Travis::Renderer.json(build, :type => :archive, :template => 'build', :base_dir => base_dir)
            end

            def http
              self.class.http_client
            end

            def log_request(build, response)
              severity, message = if response.success?
                [:info, "Successfully archived #{response.env[:url].to_s}."]
              else
                [:error, "Could not archive to #{response.env[:url].to_s}. Status: #{response.status} (#{response.body.inspect})"]
              end
              send(severity, message)
            end

            def base_dir
              File.expand_path('../../../views', __FILE__)
            end
        end
      end
    end
  end
end
