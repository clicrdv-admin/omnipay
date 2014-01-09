# Client for the mangopay API

require 'httparty'

module Omnipay
  module Adapters
    class Mangopay

      class Client

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

          response.parsed_response.merge("code" => response.code)          
        end

        def post(path, params = {})
          response = self.class.post "/#{@key}#{path}", 
            :body => params.to_json,
            :basic_auth => {:username => @key, :password => @secret},
            :base_uri => @base_uri

          response.parsed_response.merge("code" => response.code)
        end

      end

    end
  end
end
