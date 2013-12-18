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
        @adapter_class = options[:adapter]
        @adapter_config = options[:config] || {}
      end
    end


    def call(env)
      @env = env
      @request = @adapter = nil # Cleanup memoized instance variables

      # If the config is dynamic, we have to dermine it from the current path (which contains the potential uid)
      extract_config_from_path! if @dynamic_config

      # Are we on the request phase?
      return response_for_request_phase if request_phase?

      # Are we on the callback phase?
      request.env['omnipay.response'] = callback_phase_response_hash if callback_phase?
      @env['REQUEST_METHOD'] = 'GET'

      # Otherwise, continue down the middleware chain
      @app.call(@env)
    end



    private

    # Request phase : returns a Rack::Response
    def response_for_request_phase
      amount = request.GET.delete('amount')
      raise ArgumentError.new('No amount specified') unless amount

      context = request.GET.delete('context')
      store_context(context) if context

      method, url, params = adapter.request_phase(amount.to_i, request.GET)

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
      Rack::Response.new([form.html], 200, {'Content-Type' => 'text/html;charset=utf-8'})
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
      hash = adapter.callback_hash(request.params.dup)
      hash[:raw] = request.params

      context = pop_stored_context
      hash[:context] = context if context

      hash

    end


    # In the case of dynamic config, extract it from the current path
    def extract_config_from_path!     
      uid = request.path.gsub(/^#{BASE_PATH}/, '').split('/')[1]
      return unless uid

      opts = @dynamic_config.call(uid)
      return unless opts
  
      @uid = uid
      @adapter_class = opts[:adapter]
      @adapter_config = opts[:config] || {}
    end


    def adapter
      return unless @uid && @adapter_class # Dynamic config speedup

      adapter_options = @adapter_config.merge(
        :callback_url => callback_url,
      )

      @adapter ||= @adapter_class.new(adapter_options)
    end

    def request_phase?
      adapter && request.path == "#{BASE_PATH}/#{@uid}" && request.request_method == 'GET'
    end

    def callback_phase?
      adapter && request.path == "#{BASE_PATH}/#{@uid}/callback"
    end

    def callback_url
      "#{request.base_url}#{BASE_PATH}/#{@uid}/callback"
    end


    # The current Rack::Request
    def request
      @request ||= Rack::Request.new(@env)
    end

  end
end