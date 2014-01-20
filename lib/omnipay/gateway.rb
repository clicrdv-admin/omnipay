module Omnipay

  # Instance of a gateway connection. Has an uid, and encapsulates an adapter strategy
  class Gateway

    attr_reader :uid, :adapter_class, :config, :adapter

    def initialize(opts = {})
      @uid            = opts[:uid]
      @adapter_class  = opts[:adapter]
      @config         = opts[:config] || {}

      raise ArgumentError.new("missing parameter :uid") unless @uid
      raise ArgumentError.new("missing parameter :adapter") unless @adapter_class

      @adapter = @adapter_class.new(@config)
    end


    # The Rack::Response corresponding to the redirection to the payment page
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


    # The response hash
    def formatted_response_for(params)
      @adapter.callback_hash(params).merge(:raw => params)
    end


  end

end
