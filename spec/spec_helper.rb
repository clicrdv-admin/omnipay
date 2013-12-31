require 'bundler/setup'

require 'rspec'
require 'rack/test'
require 'vcr'

require 'omnipay'

RSpec.configure do |config|

end

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  c.hook_into :webmock
end
