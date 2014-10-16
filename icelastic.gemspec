# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'icelastic/version'

Gem::Specification.new do |spec|
  spec.name          = "icelastic"
  spec.version       = Icelastic::VERSION
  spec.authors       = ["RDux", "Anders Bälter"]
  spec.email         = ["data@npolar.no"]
  spec.description   = "Library that provides advanced Elasticsearch query functionality through the url."
  spec.summary       = "Offers a set of query parameters that expose more advanced Elasticsearch functionality through the url. Provides a Rack middleware for easy usage in the server stack."
  spec.homepage      = "https://github.com/npolar/icelastic"
  spec.license       = "GPLv3"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

  spec.add_development_dependency "rspec", "~> 2.9"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "elasticsearch-extensions"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-byebug"


  spec.add_dependency "rack"
  spec.add_dependency "yajl-ruby"
  spec.add_dependency "elasticsearch"
end
