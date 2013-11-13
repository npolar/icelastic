# Icelastic

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'icelastic', :git => "git://github.com/npolar/icelastic.git"

And then execute:

    $ bundle

## Usage

### Middlware

```ruby

    use Rack::Icelastic, {
      :url => "http://localhost:9200",
      :index => "example",
      :type => "test",
      :log => false, # Enables logging in elasticsearch-ruby
      :params => {
        "facets" => "topics,tags",
        "date-year" => "created,updated",
        "start" => 0,
        "limit" => 10,
        "size-facet" => 25
      }
    }

```

### App

```ruby

    run Rack::Icelastic.new nil, {
      :url => "http://localhost:9200",
      :index => "example",
      :type => "test",
      :log => false, # Enables logging in elasticsearch-ruby
      :params => {
        "facets" => "topics,tags",
        "date-year" => "created,updated",
        "start" => 0,
        "limit" => 10,
        "size-facet" => 25
      }
    }

```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
