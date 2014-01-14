# Client for the mangopay API

require 'httparty'
require 'json'

module Omnipay
  module Adapters
    class Mangopay

      class Client

        class Error < ::StandardError ; end

        include HTTParty

        format :json

        headers 'Accept' => 'application/json'
        headers 'Content-Type' => 'application/json'

        def initialize(key, secret, opts = {})
          @key = key
          @secret = secret

          if opts[:sandbox]
            @base_uri = 'https://api.sandbox.mangopay.com/v2'
          else
            @base_uri = 'https://api.mangopay.com/v2'
          end
        end

        def get(path)
          response = self.class.get "/#{@key}#{path}", 
            :basic_auth => {:username => @key, :password => @secret}, 
            :base_uri => @base_uri

          check_errors(response)

          response.parsed_response.merge("code" => response.code)
        end

        def post(path, params = {})
          response = self.class.post "/#{@key}#{path}", 
            :body => params.to_json,
            :basic_auth => {:username => @key, :password => @secret},
            :base_uri => @base_uri

          check_errors(response)

          response.parsed_response.merge("code" => response.code)
        end


        private

        def check_errors(response)
          # nocommit, log the request :/
          if response.code != 200
            error_message = response.parsed_response.merge(
              "code" => response.code
            )

            raise Error, error_message.inspect
          end
        end

      end

    end
  end
end
