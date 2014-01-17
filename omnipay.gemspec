# encoding: utf-8

$:.unshift File.expand_path('../lib', __FILE__)
require 'omnipay/version'

Gem::Specification.new do |s|
  s.name          = "omnipay"
  s.version       = Omnipay::VERSION
  s.authors       = ["ClicRDV"]
  s.email         = ["contact@clicrdv.com"]
  s.homepage      = "https://github.com/clicrdv/omnipay"
  s.summary       = "Payment gateway abstraction for rack applications."
  s.description   = "Payment gateway abstraction for rack applications.  Think omniauth for off-site payment."

  s.files         = `git ls-files app lib`.split("\n")
  s.platform      = Gem::Platform::RUBY
  s.require_paths = ['lib']
  s.rubyforge_project = '[none]'

  s.add_dependency 'rack', '~> 1.5'

  if RUBY_VERSION < '1.9'
    s.add_dependency 'json', '~> 1.8'
  end

  # For adapters implementations
  s.add_dependency 'httparty', '~> 0.11.0' # 0.12 drops support for ruby 1.8.7
end
