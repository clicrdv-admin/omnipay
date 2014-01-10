# Class responsible for updating the request env in the callback phase

module Omnipay
  class CallbackPhase

    def initialize(request, adapter)
      @request = request
      @adapter = adapter
    end


    def update_env!

      # The request params, keys symbolized
      params = Hash[@request.params.map{|k,v|[k.to_sym,v]}]

      # Get the callback hash
      callback_hash = @adapter.callback_hash(params)

      # Check the signature
      if callback_hash[:success] && !valid_signature?(callback_hash)
        callback_hash = {
          :success => false, 
          :error => Omnipay::WRONG_SIGNATURE, 
          :error_message => "Signatures do not match."
        }
      end

      # If not successful response, add informations to the error message
      if !callback_hash[:success]
        callback_hash[:error_message] = (callback_hash[:error_message] || callback_hash[:error].to_s) +
          "\nAdapter : #{@adapter.uid}" +
          "\nContext : #{context.inspect}" +
          "\nStored signature : #{stored_signature}" +
          "\nRequest : #{@request.inspect}"
      end

      # Store the response in the environment
      @request.env['omnipay.response'] = callback_hash.merge(:raw => params, :context => context)

      # Force GET request
      @request.env['REQUEST_METHOD'] = 'GET'      
    end


    private

    def valid_signature?(callback_hash)
      callback_signature = Signer.new(callback_hash[:transaction_id], callback_hash[:amount], context).signature

      callback_signature == stored_signature
    end

    def stored_signature
      @stored_signature ||= @request.session['omnipay.signature'] && @request.session['omnipay.signature'].delete(@adapter.uid)
    end

    def callback_signature
      @callback_signatureSigner.new(callback_hash[:transaction_id], callback_hash[:amount], context).signature
    end

    def context
      @context ||= @request.session['omnipay.context'] && @request.session['omnipay.context'].delete(@adapter.uid)
      @context ||= {}
    end

  end
end
