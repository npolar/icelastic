# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'icelastic/version'

Gem::Specification.new do |spec|
  spec.name          = "icelastic"
  spec.version       = Icelastic::VERSION
  spec.authors       = ["RDux"]
  spec.email         = ["data@npolar.no"]
  spec.description   = "Library that provides advanced elasticsearch query functionality in the url."
  spec.summary       = "Exposes elasticsearch on the url using a Rack middleware for easy injection in server stack."
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "simplecov"

  spec.add_development_dependency "rack"
  spec.add_development_dependency "rack-contrib"
  spec.add_development_dependency "elasticsearch"
end
