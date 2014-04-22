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
    # - +:base_uri+ : the current http scheme + host (used in the post-payment redirection)
    # - +:amount [Integer]+ : the amount to pay, in cents
    # Depending on the adapter used, the options hash may have other mandatory keys. Refer to the adapter's documentation for more details
    # @return [Rack::Response] the GET or POST redirection to the payment provider
    def payment_redirection(opts = {})
      base_uri = opts.delete :base_uri

      if !base_uri && opts[:host]
        base_uri = opts.delete :host
        Kernel.warn "[DEPRECATION] `host` is deprecated.  Please use `base_uri` instead."
      end

      base_uri ||= Omnipay.configuration.base_uri

      raise ArgumentError.new('Missing parameter :base_uri') unless base_uri

      ipn_url      = "#{base_uri}#{Omnipay.configuration.base_path}/#{uid}/ipn"
      callback_url = "#{base_uri}#{Omnipay.configuration.base_path}/#{uid}/callback"

      method, url, params = @adapter.request_phase(opts, ipn_url, callback_url)

      if method == 'GET'
        redirect_url = url + (url.include?('?') ? '&' : '?') + Rack::Utils.build_query(params)
        Rack::Response.new.tap{|response| response.redirect(redirect_url)}

      elsif method == 'POST'
        form = AutosubmitForm.new(url, params)
        Rack::Response.new([form.html], 200, {'Content-Type' => 'text/html;charset=utf-8'})

      else
        raise ArgumentError.new('the returned method is neither GET nor POST')

      end
    end


    # The formatted response hashes
    # @return [Hash] the processed response which will be present in the request environement under 'omnipay.response'
    def ipn_hash(request)
      @adapter.ipn_hash(request).merge(:raw => request.params)
    end

    def callback_hash(request)
      @adapter.callback_hash(request).merge(:raw => request.params)
    end


    # Is IPN enabled?
    def ipn_enabled?
      @adapter_class.ipn?
    end


  end

end
