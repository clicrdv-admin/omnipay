module Omnipay

  # Structure responsible for storing and accessing the application's configured gateways
  class Gateways

    def initialize
      @gateways = {}
      @dynamic_configs = [] # Collection of procs which given a uid may or may not return a gateway config hash
    end


    # Add a new gateway, static or dynamic
    #
    # Can be initialized via a config hash, or a block.
    #
    # If initialized with a hash, it must contains the `:uid` and `:adapter` keys
    #
    # If initialized with a block, the block must take the uid as an argument, and return a config hash with an `:adapter` key
    # @param opts [Hash] the gateway configuration, if static.
    # @param block [Proc] the gateway configuration, if dynamic.
    def push(opts = {}, &block)
      if block_given?
        @dynamic_configs << Proc.new(&block)

      elsif opts[:uid] && opts[:adapter]
        @gateways[opts[:uid]] = Gateway.new(opts)
    
      else
        raise ArgumentError.new('An omnipay gateway must be given an uid and an adapter, or a dynamic block')
      end
    end


    # Find a static gateway or instanciate a dynamic gateway for the given uid
    # @param uid [String] the gateway's uid
    # @return [Gateway] the corresponding gateway, or nil if none
    def find(uid)
      gateway = @gateways[uid]
      return gateway if gateway

      # Tries to find a dynamic gateway config for this uid
      config = @dynamic_configs.find do |dynamic_config|
        gateway_config = dynamic_config.call(uid)
        if gateway_config
          return Gateway.new(gateway_config.merge(:uid => uid))
        end
      end

      # Nothing found : return nil
      nil
    end

  end

end