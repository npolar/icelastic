[![Build Status](https://travis-ci.org/npolar/icelastic.svg?branch=master)](https://travis-ci.org/npolar/icelastic)

# Icelastic
[Rack](http://rack.github.io/) middleware that provides [Cool URIs](http://www.w3.org/Provider/Style/URI.html) for Elasticsearch-based web services.

## Features
### Real-world examples
Icelastic is used in production at the Norwegian Polar Institute [API](http://api.npolar.no)s, below are some real-world example queries
* [Searching](http://api.npolar.no/dataset/?q=glacier) **?q=**
* [Filtering](http://api.npolar.no/oceanography/?q=&filter-collection=cast&filter-station=77) filter-{variable}=value 
* [Faceting](http://api.npolar.no/oceanography/?q=&facets=collection,station,sea_water_temperature) facets={variable[,varible2]}
* [Range-faceting](http://api.npolar.no/oceanography/?q=&rangefacet-sea_water_temperature=10,&rangefacet-latitude=10) (aka. bucketing) 

### Multiple response formats 
The default Icelastic response format is a [JSON feed]() modeled after Atom/[OpenSearch](http://www.opensearch.org/Specifications/OpenSearch/1.1#Example_of_OpenSearch_response_elements_in_Atom_1.0).

* [JSON](http://api.npolar.no/dataset/?q=&format=json) format=json
* [CSV](http://api.npolar.no/tracking/deployment/?q=&format=csv&fields=deployed,platform,vendor,terminated) format=csv
* [GeoJSON](http://api.npolar.no/expedition/track/?q=&filter-code=IPY-Traverse-0709&format=geojson&fields=altitude,measured,latitude,longitude) format=geojson
* JSON array - format=json&variant=array
* HAL - format=hal
* raw - format=raw

## Use
### Simple
```ruby
# config.ru
require 'icelastic'

use Rack::Icelastic, {
  :url => "http://localhost:9200", :index => "example", :type => "test" }
}

```
### Advanced

Example of injecting a custom [CDL](https://www.unidata.ucar.edu/software/netcdf/docs/index.html) response writer,
and setting various configuraton options

```ruby
writers = Icelastic::Default.writers
writers << My::ElasticsearchCDLWriter

use ::Rack::Icelastic, {
  :url => "http://localhost:9200",
  :index => "oceanography",
  :log => false, # Logging in elasticsearch-ruby ?
  :type => "point",
  :params => {
    "facets" => "station,cruise,ctd,collection,mooring,serialnumber",
    "date-year" => "measured", # Date facets with a year interval
    "limit" => 10, # Items per page
    "size-facet" => 100 # Number of facet items
  },
  :writers => writers
}
```

```ruby

module My
  class ElasticsearchCDLWriter
    
    def self.format
      "cdl"
    end
    
    def self.type
      "text/plain"
    end
    
    def initialize(request, elasticsearch_response_hash)
      @feed = Icelastic::ResponseWriter::Feed.new(request, elasticsearch_response_hash)
    end
          
    def build
      @feed.build do |feed|
        "netcdf {}" # build response here
      end
    end
  end
end
```

### URI reference
#### Search
```json
  "?q=<value>" # Regular query
  "?q-<field>=<value>" # Field query
  "?q-<field1>,<field2>=<value>" # Multi-field query
```

#### Global parameters (paging, sorting, limiting, scoring)

```ruby
  "?start=10" # Results are shown from the 10th row
  "?limit=50" # Show 50 rows per result page


  "?sort=<field>" # Sort ascending on field
  "?sort=-<field>" # Sort descending on field

  "?fields=<field1>,<field2>,<field3>" # Only show fields 1,2,3 in the response rows
  "?highlight=true" # Enable term highlighting. Injects a highlight key with the relevant sections into the entry
  "?score" # Include relevance scoring in result
```

#### Filtering

```ruby
  "?filter-<field>=<value>" # Basic filter

  "?filter-<field>=<value1>,<value2>" # AND filter
  "?filter-<field>=<value1>|<value2>" # OR filter
  "?not-<field>=<value>" # NOT filter (starts with not instead of filter)

  "?filter-<field>=<value1>..<value2>" # Range filter
  "?filter-<field>=<value>.." # Range filter (greater or equal then)
  "?filter-<field>=..<value>" # Range filter (less or equal then)
```

#### Faceting

```ruby
  "?facets=<field1>,<field2>" # Facet on field1 and field2
  "?facet-<name>=<field>" # Labeled facet (generates a facet with a specific name)

  "?date-<interval>=<field1>,<field2>" # Generate a date facet with the specified interval (year|month|day)

  "?size-facet=<number>" # Specify the number of facets to return
```

#### Aggregations

```ruby
  "?date-<interval>=<field>[<field1>:<field2>]" # Specify a temporal aggregation
  
  "?rangefacet-<field>=<interval>" # Range facet with interval
```

#### Formats

```ruby
  "?format=raw" # Returns the raw elasticsearch response (application/json)

  "?format=geojson" # Return a GeoJSON featureCollection containing point features
  "?format=geojson&geometry=linestring" # Return a GeoJSON featureCollection containing a linestring feature
  "?format=geojson&geometry=multipoint" # Return a GeoJSON featureCollection containing a multipoint feature

  "?format=csv" # Return results as csv (Only basic support)
  "?format=csv&fields=<field1>" # For the best results with csv specify the fields you want in the results
  "?format=csv&fields=<alias>:<field>" # Header fields can be renamed with an alias
```

## Installation

Add this line to your application's Gemfile:

    gem 'icelastic', :git => "git://github.com/npolar/icelastic.git"

And then execute:

    $ bundle


Rangefaceting requires copying `scripts/range.groovy` to your elasticsearch scripts folder, ie. `elasticsearch/config/scripts/range.groovy`.
See also: [Elasticsearch Scripting](http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/modules-scripting.html)

### Testing

The tests need a real Elasticsearch server to run

```sh
  export ICELASTIC_ELASTICSEARCH_COMMAND=tmp/elasticsearch/bin/elasticsearch
  mkdir -p tmp/elasticsearch && wget -O - https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.3.4.tar.gz | tar xz --directory=tmp/elasticsearch/ --strip-components=1
```
Run tests

```sh
  bundle exec rspec
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

[![Code Climate](https://codeclimate.com/github/npolar/icelastic.png)](https://codeclimate.com/github/npolar/icelastic) [![Build Status](https://travis-ci.org/npolar/icelastic.svg?branch=master)](https://travis-ci.org/npolar/icelastic) [rubydoc](http://www.rubydoc.info/github/npolar/icelastic/master/file/README.md)
