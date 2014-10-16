# Test environment
ENV['RACK_ENV'] = 'test'

require 'simplecov'
require 'pry'

SimpleCov.start do
  # Filters
  add_filter "/spec"
  add_filter do |src|
    src.lines.count < 5
  end

  # Groups
  add_group "Lib", "/lib/icelastic"
  add_group "Middleware", "/lib/rack"
end

require "bundler/setup"
require 'rspec'
require 'rack/test'
require 'icelastic'
require 'elasticsearch/extensions/test/cluster'

RSpec.configure do |conf|
  conf.include( Rack::Test::Methods )
end

## Elasticsearch Server Testing

# start a test cluster
Elasticsearch::Extensions::Test::Cluster.start \
  cluster_name: "icespec",
  command:      ENV['ICELASTIC_ELASTICSEARCH_COMMAND'] ||= "tmp/elasticsearch/bin/elasticsearch",
  port:         9350,
  nodes:        1

# create a test index in the test cluster
Elasticsearch::Client.new( url: "http://localhost:9350" ).index index: 'rspec', type: 'spec', id: 1, body: { title: 'IceSpec' }

at_exit{ Elasticsearch::Extensions::Test::Cluster.stop port: 9350 }
