# Glue between the rack middleware and the adapter implementation
# Responsible for initializing, configuring the adapter, and formatting
# the responses for use in the middleware

module Omnipay

  class Adapter

    attr_reader :uid

    def initialize(uid, callback_url, config, dynamic_config)
      @uid = uid
      @callback_url = callback_url
      @config = config
      @dynamic_config = dynamic_config

      @strategy = build_strategy
    end

    def valid?
      @strategy != nil
    end

    def request_phase(amount, opts)
      @strategy.request_phase(amount, opts)
    end

    def callback_hash(params)
      @strategy.callback_hash(params)
    end


    private

    def build_strategy
      return nil unless strategy_class

      strategy_class.new(strategy_config)
    end

    def strategy_class
      params[:adapter]
    end

    def strategy_config
      (params[:config] || {}).merge(
        :callback_url => @callback_url
      )
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