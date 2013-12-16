require 'rack'

module Omnipay

  # Generic gateway logic
  # Included in specific gateway classes
  module Gateway

    def initialize(app, gateway_uid, options = {})
      @app = app
      @uid = gateway_uid
      @env = nil
    end


    def call(env)
      @env = env
      @request = nil

      # Are we on the request phase?
      return gateway_redirection if request_phase?

      # Are we on the callback phase?
      request.env['omnipay.response'] = extract_response_hash if callback_phase?

      # Otherwise, continue down the middleware chain
      @app.call(@env)
    end


    def request_phase(amount)
      raise RuntimeError.new('request_phase must be defined')
    end


    def callback_hash(params)
      raise RuntimeError.new('callback_hash must be defined')
    end


    private


    def gateway_redirection
      amount = request.GET['amount']
      raise ArgumentError.new('No amount specified') unless amount

      context = request.GET['context']
      store_context(context) if context

      method, url, params = request_phase(amount.to_i)

      case method
      when 'GET'
        return get_redirection(url, params)
      when 'POST'
        return post_redirection(url, params)
      else
        raise TypeError.new('request_phase returned http method must be \'GET\' or \'POST\'')
      end
    end


    def get_redirection(url, params)
      redirect_url = url + '?' + Rack::Utils.build_query(params)
      Rack::Response.new.tap{|response| response.redirect(redirect_url)}
    end


    def post_redirection(url, params)
      form = AutosubmitForm.new(url, params)
      Rack::Response.new([form.html], 200)
    end


    def store_context(context)
      request.session['omnipay.context'] ||= {}
      request.session['omnipay.context'][@uid] = context
    end

    def get_context
      request.session['omnipay.context'] && request.session['omnipay.context'].delete(@uid)
    end


    def extract_response_hash

      # Get the hash from the gateway implementation
      hash = callback_hash(request.params)
      hash[:raw] = request.params

      context = get_context
      hash[:context] = context if context

      hash

    end


    def request_phase?
      request.request_method == 'GET' && request.path == "/pay/#{@uid}"
    end


    def callback_phase?
      request.path == "/pay/#{@uid}/callback"
    end


    def request
      @request ||= Rack::Request.new(@env)
    end

  end
end