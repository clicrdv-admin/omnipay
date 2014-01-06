# Client for the mangopay API

require 'httparty'

module Omnipay
  module Adapters
    class Mangopay

      class Client

        include HTTParty

        base_uri 'https://api.sandbox.mangopay.com/v2'
        format :json

        headers 'Accept' => 'application/json'
        headers 'Content-Type' => 'application/json'

        def initialize(key, secret)
          @key = key
          @secret = secret
        end

        def get(path)
          response = self.class.get "/#{@key}#{path}", :basic_auth => {:username => @key, :password => @secret}
          response.parsed_response.merge("code" => response.code)          
        end

        def post(path, params = {})
          response = self.class.post "/#{@key}#{path}", 
            :body => params.to_json,
            :basic_auth => {:username => @key, :password => @secret}

          response.parsed_response.merge("code" => response.code)
        end

      end

    end
  end
end
