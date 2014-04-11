module Omnipay

  module Helpers

    # Deep hash clone
    def self.deep_dup(hash)
      hash.inject({}) do |clone, (key, value)|
        clone[key] = value.dup
        clone
      end
    end

  end

end