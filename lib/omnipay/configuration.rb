require 'singleton'

module Omnipay

  # The global Omnipay configuration singleton
  # Can be assigned the following values : 
  # - +base_path+ (default "/pay") : the base path which will be hit in the payment providers callbacks
  class Configuration
    include Singleton
    attr_accessor :base_path

    def initialize
      @base_path = "/pay"
    end
  end

end