module Omnipay

  # Structure responsible for storing and accessing the application's configured gateways
  class Gateways


    def initialize
      @gateways = {}
      @dynamic_configs = [] # Collection of procs which given a uid may or may not return a gateway config hash
    end


    # Add a new gateway, static or dynamic
    def push(opts = {}, &block)
      if block_given?
        @dynamic_configs << Proc.new(&block)

      elsif opts[:uid] && opts[:adapter]
        @gateways[opts[:uid]] = Gateway.new(opts)
    
      else
        raise ArgumentError.new('An omnipay gateway must be given an uid and an adapter, or a dynamic block')
      end
    end


    # Find and/or instanciate a gateway for the given uid
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