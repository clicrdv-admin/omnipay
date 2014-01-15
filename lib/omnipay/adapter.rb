module Omnipay

  # Wrapper around an actual adapter implementation. Responsible mainly for handling its initialization with
  # a static or dynamic (block) configuration
  class Adapter

    # The adapter's unique identifier. Will be passed to the dynamic configuration block.
    attr_reader :uid


    # @param uid [String] The adapter's unique identifier
    # @param callback_url [String] The absolute URL to be used for the user redirection after the payment
    # @param config [Hash] A static adapter configuration
    # @param dynamic_config [String => Hash] A dynamic config block. Takes the uid as an input and returns the adapter's configuration
    # @return [Adapter]
    def initialize(uid, callback_url, config, dynamic_config)
      @uid = uid
      @callback_url = callback_url
      @config = config
      @dynamic_config = dynamic_config

      @strategy = build_strategy
    end

    # Is there a valid adapter configuration for the given parameters. Checks notably if the given uid is valid in case of a dyncamic configuration.
    # @return [Boolean]
    def valid?
      @strategy != nil
    end

    # Proxy to the adapter's implementation's request_phase method
    # @param amount [Integer] The amount to pay, in **cents**
    # @param opts [Hash] The custom GET parameters sent to the omnipay payment url
    # @return [Array] The array containing the redirection method (GET or POST), its url, its get or post params, and the unique associated transaction id
    def request_phase(amount, opts = {})
      @strategy.request_phase(amount, opts)
    end

    # Proxy to the adapter's implementation's callback_phase method
    # @param params [Hash] The GET/POST params sent by the payment gateway to the callback url
    # @return [Hash] The omnipay response environment. Contains the response success status, the amount payed, the error message if any, ...
    def callback_hash(params)
      @strategy.callback_hash(params)
    end


    private

    def build_strategy
      return nil unless strategy_class

      strategy_class.new(@callback_url, strategy_config)
    end

    def strategy_class
      params[:adapter]
    end

    def strategy_config
      params[:config] || {}
    end

    def params
      return @params if @params

      if @dynamic_config
        @params = @dynamic_config.call(@uid) || {}
      else
        @params = @config || {}
      end

      @params ||= {}
    end

  end
end