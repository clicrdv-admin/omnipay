require 'rack'

module Omnipay

  # Gateway middleware
  class Gateway

    BASE_PATH = '/pay'

    def initialize(app, options={}, &block)
      @app = app

      @adapter_options = options
      @adapter_config_block = block

      # Refreshed at each request
      @uid = nil
      @request = nil
    end


    def call(env)

      # Get the current request
      @request = Rack::Request.new(env)

      # Check if the path is good, and extract the uid
      @uid = extract_uid_from_path(@request.path)
      return @app.call(env) unless @uid

      # Get the adapter config for this uid (to handle dynamic configuration)
      adapter = Adapter.new(@uid, callback_url, @adapter_options, @adapter_config_block)
      return @app.call(env) unless adapter.valid?

      # Handle the request phase
      if request_phase?
        return RequestPhase.new(@request, adapter).response
      end

      # Handle the callback phase
      if callback_phase?
        CallbackPhase.new(@request, adapter).update_env!
      end

      # Forward to the app
      @app.call(env)

    end


    private

    # Check if the current request matches the request or callback phase
    def request_phase?
      @request.path == "#{BASE_PATH}/#{@uid}" && @request.request_method == 'GET'
    end

    def callback_phase?
      @request.path == "#{BASE_PATH}/#{@uid}/callback"
    end


    # Extract the uid from the path
    # If uid already defined, check if it matches
    # "/pay/foobar/callback" => "foobar"
    def extract_uid_from_path(path)
      if path.start_with? BASE_PATH
        uid = path.gsub(/^#{BASE_PATH}/, '').split('/')[1]
      end

      if !@adapter_options.empty?
        uid = nil unless uid == @adapter_options[:uid]
      end

      uid
    end


    # The callback url for a uid in the current host
    def callback_url
      "#{@request.base_url}#{BASE_PATH}/#{@uid}/callback"
    end

  end
end