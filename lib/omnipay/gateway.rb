module Omnipay

  # Instance of a gateway connection. Has an uid, and encapsulates an adapter strategy.
  class Gateway

    attr_reader :uid, :adapter_class, :config, :adapter

    # @param opts [Hash] 
    #
    # The options hash must include the following keys :
    #  - :uid => the gateways uid
    #  - :adapter => the adapter class
    #
    # The options hash may also include the following keys :
    #  - :config => the configration hash passed to the adapter for its initialization
    def initialize(opts = {})
      @uid            = opts[:uid]
      @adapter_class  = opts[:adapter]
      @config         = opts[:config] || {}

      raise ArgumentError.new("missing parameter :uid") unless @uid
      raise ArgumentError.new("missing parameter :adapter") unless @adapter_class

      @adapter = @adapter_class.new(@config)
    end


    # The Rack::Response corresponding to the redirection to the payment page
    # @param opts [Hash] The attributes of the current payment. Will be passed on to the adapter.
    # The options hash must contain the following keys : 
    # - +:host+ : the current host (used in the post-payment redirection)
    # - +:amount [Integer]+ : the amount to pay, in cents
    # Depending on the adapter used, the options hash may have other mandatory keys. Refer to the adapter's documentation for more details
    # @return [Rack::Response] the GET or POST redirection to the payment provider
    def payment_redirection(opts = {})
      host = opts.delete :host
      amount = opts.delete :amount

      raise ArgumentError.new('Missing parameter :host') unless host
      raise ArgumentError.new('Missing parameter :amount') unless amount

      callback_url = "#{host}#{Omnipay.configuration.base_path}/#{uid}/callback"

      method, url, params = @adapter.request_phase(amount, callback_url, opts)

      if method == 'GET'
        redirect_url = url + '?' + Rack::Utils.build_query(params)
        Rack::Response.new.tap{|response| response.redirect(redirect_url)}

      elsif method == 'POST'
        form = AutosubmitForm.new(url, params)
        Rack::Response.new([form.html], 200, {'Content-Type' => 'text/html;charset=utf-8'})

      else
        raise ArgumentError.new('the returned method is neither GET nor POST')

      end
    end


    # The formatted response hash
    # @param params [Hash] the request GET/POST parameters send with the redirection from the provider
    # @return [Hash] the processed response which will be present in the request environement under 'omnipay.response'
    def formatted_response_for(params)
      @adapter.callback_hash(params).merge(:raw => params)
    end


  end

end
