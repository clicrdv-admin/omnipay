require 'rack'

module Omnipay

  # Gateway middleware
  class Gateway

    BASE_PATH = '/pay'

    def initialize(app, options={}, &block)
      @app = app
      @env = nil

      if block
        @dynamic_config = block
      else
        @uid = options[:uid]
        @adapter = options[:adapter].new(options[:config])
      end
    end


    def call(env)
      @env = env
      @request = nil   

      # Check if the middleware has to do something (request or callback)
      if phase = check_matching_path!

        # Are we on the request phase?
        return response_for_request_phase if phase == :request

        # Are we on the callback phase?
        request.env['omnipay.response'] = callback_phase_response_hash if phase == :callback

      end

      # Otherwise, continue down the middleware chain
      @app.call(@env)
    end



    private

    # Request phase : returns a Rack::Response
    def response_for_request_phase
      amount = request.GET['amount']
      raise ArgumentError.new('No amount specified') unless amount

      context = request.GET['context']
      store_context(context) if context

      method, url, params = @adapter.request_phase(amount.to_i)

      case method
      when 'GET'
        get_redirection(url, params)
      when 'POST'
        post_redirection(url, params)
      else
        raise TypeError.new('request_phase returned http method must be \'GET\' or \'POST\'')
      end
    end


    # GET redirection : 302 redirect
    def get_redirection(url, params)
      redirect_url = url + '?' + Rack::Utils.build_query(params)
      Rack::Response.new.tap{|response| response.redirect(redirect_url)}
    end


    # POST redirection : autosubmitted form
    def post_redirection(url, params)
      form = AutosubmitForm.new(url, params)
      Rack::Response.new([form.html], 200)
    end


    # Store and restores the request's context
    def store_context(context)
      request.session['omnipay.context'] ||= {}
      request.session['omnipay.context'][@uid] = context
    end

    def pop_stored_context
      request.session['omnipay.context'] && request.session['omnipay.context'].delete(@uid)
    end


    # Builds the 'omnipay.response' hash for the callback phase
    def callback_phase_response_hash

      # Get the hash from the gateway implementation
      hash = @adapter.callback_hash(request.params)
      hash[:raw] = request.params

      context = pop_stored_context
      hash[:context] = context if context

      hash

    end


    # Check if the url matches the request or callback phase for the gateway
    # Also extracts the configuration for dynamic gateways
    # Returns :request or :callback if the path matches, nil otherwise
    def check_matching_path!

      path = request.path

      return unless path.start_with? BASE_PATH

      if @dynamic_config
        @uid, @adapter = extract_uid_and_adapter(path)
        return unless @uid
      end

      return :request  if path == "#{BASE_PATH}/#{@uid}" && request.request_method == 'GET'
      return :callback if path == "#{BASE_PATH}/#{@uid}/callback"

    end


    # For the dynamic config, tries to get an adapter for a given uid
    def extract_uid_and_adapter(path)
      # We know the request starts with '/pay' . The second path component is the uid
      uid = path.split('/')[2]
      return unless uid

      opts = @dynamic_config.call(uid)
      return unless opts

      [uid, opts[:adapter].new(opts[:config])]
    end


    # The current Rack::Request
    def request
      @request ||= Rack::Request.new(@env)
    end

  end
end