module Omnipay

  module Helpers

    # Deep hash clone
    def self.deep_dup(hash)
      hash.inject({}) do |clone, (key, value)|
        clone[key] = value.dup
        clone
      end
    end

    # Symbolize hash keys
    def self.symbolize_keys(hash)
      hash.inject({}){|acc,(k,v)| acc[k.to_sym] = v; acc}
    end

    # Return a copy of a hash, with only the given keys
    def self.slice_hash(*args)
      hash = args[0]
      whitelist = args[1..-1]

      hash.dup.keep_if do |key, _|
        whitelist.include? key
      end
    end

  end

end