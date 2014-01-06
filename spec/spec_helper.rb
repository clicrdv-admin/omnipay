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
  c.allow_http_connections_when_no_cassette = true
end
