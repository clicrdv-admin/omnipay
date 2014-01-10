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

  s.add_dependency 'rack'

  # For adapters implementations
  s.add_dependency 'httparty', '< 1.0'
end
