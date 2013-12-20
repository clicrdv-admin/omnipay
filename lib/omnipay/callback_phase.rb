# Class responsible for updating the request env in the callback phase

module Omnipay
  class CallbackPhase

    def initialize(request, adapter)
      @request = request
      @adapter = adapter
    end


    def update_env!
      @request.env['omnipay.response'] = response_hash
      @request.env['REQUEST_METHOD'] = 'GET'      
    end


    private

    def response_hash
      # Symbolize the keys
      params = Hash[@request.params.map{|k,v|[k.to_sym,v]}]

      hash = @adapter.callback_hash(params)
      hash[:raw] = params
      hash[:context] = context if context
      hash
    end

    def context
      @context ||= @request.session['omnipay.context'] && @request.session['omnipay.context'].delete(@adapter.uid)
    end

  end
end
