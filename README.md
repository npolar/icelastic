# Icelastic

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'icelastic', :git => "git://github.com/npolar/icelastic.git"

And then execute:

    $ bundle

## Usage

### Middleware

```ruby

    use Rack::Icelastic, {
      :url => "http://localhost:9200",
      :index => "example",
      :type => "test",
      :log => false, # Enables logging in elasticsearch-ruby
      :params => {
        "facets" => "topics,tags", # Fields to facet
        "date-month" => "created,updated", # Date facets with a month interval
        "start" => 0, # Start of result page
        "limit" => 20, # Items per page
        "size-facet" => 5 # Number of facet items
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
        "facets" => "topics,tags", # Fields to facet
        "date-year" => "created,updated", # Date facets with a year interval
        "start" => 0, # Start of result page
        "limit" => 10, # Items per page
        "size-facet" => 25 # Number of facet items
      }
    }

```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
