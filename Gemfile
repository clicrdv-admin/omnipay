source "https://rubygems.org"

gemspec

gem 'rspec'
gem 'rack-test'
gem 'vcr'
gem 'webmock'

if RUBY_VERSION < '1.9'
  gem 'active_support' # Ordered hash for ruby 1.8.7 specs
end

if RUBY_VERSION >= '1.9'
  gem 'coveralls', :require => false
end

