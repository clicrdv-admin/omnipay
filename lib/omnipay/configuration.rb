require 'singleton'

module Omnipay

  # The global Omnipay configuration singleton
  class Configuration
    include Singleton
    attr_accessor :base_path

    def initialize
      @base_path = "/pay"
    end
  end

end