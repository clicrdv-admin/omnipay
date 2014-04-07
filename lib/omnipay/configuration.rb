require 'singleton'

module Omnipay

  # The global Omnipay configuration singleton
  # Can be assigned the following values : 
  # - +base_path+ (default "/pay") : the base path which will be hit in the payment providers callbacks.
  # - +base_uri+ (default nil) : the base uri (scheme + host + port) which will be hit in the payment providers callbacks.
  class Configuration
    include Singleton
    attr_accessor :base_path, :base_uri

    def initialize
      @base_uri = nil
      @base_path = "/pay"
    end
  end

end