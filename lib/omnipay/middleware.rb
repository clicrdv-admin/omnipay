require 'rack'

module Omnipay

  # This is the actual Rack middleware
  # It is responsible for formatting callback responses
  # via a CallbackPhase instance
  class Middleware

    # @param app [Rack application] : The rack app it should forward to if the request doens't match a monitored path
    # 
    # The gateway may be initialized with a block returning a hash instead of a hash. In this case, the
    # block's only argument is the uid, and the returned hash must contain the adapter class and its configuration

    def initialize(app)
      @app = app
    end

    # The standard rack middleware call. Will be processed by an instance of RequestPhase or CallbackPhase if the
    # path matches the adapter's uid. Will forward to the app otherwise
    # @param env [Hash] the request's environment
    # @return [Rack::Reponse]
    def call(env)

      # Get the current request
      request = Rack::Request.new(env)

      # Check if the path is good, and extract the uid
      uid = extract_uid_from_path(request.path)
      return @app.call(env) unless uid

      # Get the gateway for this uid
      gateway = Omnipay.gateways.find(uid)
      return @app.call(env) unless gateway

      # Handle the IPN phase
      return call_ipn(request, gateway) if ipn_phase?(request, uid)

      # Handle the callback phase
      if callback_phase?(request, uid)

        # If no IPN : send the ipn request before
        if !gateway.ipn_enabled?
          call_ipn(request, gateway, :force => true)
        end

        return call_callback(request, gateway)
      end

      # Forward to the app
      @app.call(env)

    end


    private

    def ipn_path(uid)
      "#{Omnipay.configuration.base_path}/#{uid}/ipn"
    end

    def callback_path(uid)
      "#{Omnipay.configuration.base_path}/#{uid}/callback"
    end

    def ipn_phase?(request, uid)
      request.path == ipn_path(uid)
    end

    def callback_phase?(request, uid)
      request.path == callback_path(uid)
    end

    def call_ipn(request, gateway, opts = {})
      # Force : override the path
      if opts[:force]
        request = Rack::Request.new(request.env.dup)
        request.path = ipn_path(gateway.uid)
      end

      # Set the formatted response
      request.env['omnipay.response'] = gateway.ipn_hash(request)

      # Force a POST on the app
      request.env['REQUEST_METHOD'] = 'POST'

      # Call the app
      @app.call(request.env)
    end

    def call_callback(request, gateway)
      # Set the formatted response
      request.env['omnipay.response'] = gateway.callback_hash(request)

      # Force a get request
      request.env['REQUEST_METHOD'] = 'GET'

      # Call the app
      @app.call(request.env)
    end


    # Extract the uid from the path
    # "/pay/foobar/callback" => "foobar"
    def extract_uid_from_path(path)
      if path.start_with? Omnipay.configuration.base_path
        uid = path.gsub(/^#{Omnipay.configuration.base_path}/, '').split('/')[1]
      end
    end

  end
end