require 'rack'

module Omnipay

  # This is the actual Rack middleware
  # 
  # It is associated with an adapter instance, and 
  # responsible for monitoring the incoming request
  # and - depending on their path - forwarding them
  # for processing to a RequestPhase or CallbackPhase
  # instance for processing
  class Gateway

    BASE_PATH = '/pay'

    # @param app [Rack application] : The rack app it should forward to if the request doens't match a monitored path
    # 
    # @param options [Hash] : must contains the following configuration options
    #  * :uid : the subpath to monitor
    #  * :adapter : the adapter class to use 
    #  * :config : the config hash which will be passed at the adapter for initialization
    # 
    # The gateway may be initialized with a block returning a hash instead of a hash. In this case, the
    # block's only argument is the uid, and the returned hash must contain the adapter class and its configuration

    def initialize(app, options={}, &block)
      @app = app

      @adapter_options = options
      @adapter_config_block = block

      # Refreshed at each request
      @uid = nil
      @request = nil
    end

    # The standard rack middleware call. Will be processed by an instance of RequestPhase or CallbackPhase if the
    # path matches the adapter's uid. Will forward to the app otherwise
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