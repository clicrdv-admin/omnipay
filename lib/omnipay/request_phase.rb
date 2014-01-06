# Class responsible for formatting the redirection in the request phase

module Omnipay
  class RequestPhase

    def initialize(request, adapter)
      @request = request
      @adapter = adapter
    end

    def response
      store_context!

      method, url, params = @adapter.request_phase(amount, adapter_params)

      if method == 'GET'
        get_redirect_response(url, params)
      elsif method == 'POST'
        post_redirect_response(url, params)
      else
        raise TypeError.new('request_phase returned http method must be \'GET\' or \'POST\'')
      end
    end


    private

    def amount
      @request.params['amount'].tap{ |amount|
        raise ArgumentError.new('No amount specified') unless amount
      }.to_i
    end

    def adapter_params
      params = @request.params.dup
 
      params.delete 'amount'
      params.delete 'context'

      # Symbolize the keys
      Hash[params.map{|k,v|[k.to_sym,v]}]
    end

    def get_redirect_response(url, params)
      redirect_url = url + '?' + Rack::Utils.build_query(params)
      Rack::Response.new.tap{|response| response.redirect(redirect_url)}
    end

    def post_redirect_response(url, params)
      form = AutosubmitForm.new(url, params)
      Rack::Response.new([form.html], 200, {'Content-Type' => 'text/html;charset=utf-8'})
    end

    # Store the request's context in session
    def store_context!
      context = @request.params.delete('context')
      return unless context
      @request.session['omnipay.context'] ||= {}
      @request.session['omnipay.context'][@adapter.uid] = context
    end

  end
end