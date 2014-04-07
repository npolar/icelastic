require 'spec_helper'

describe Icelastic::ResponseWriter::GeoJSON do

  def response
    {
      "feed" => {
        "stats" => [
          {
            "doc_count" => 140,
            "longitude" => {
                "count" => 140,
                "min" => -2.629000000000019,
                "max" => 22.905,
                "avg" => 18,
                "sum" => 2566.348,
                "sum_of_squares" => 49462.788684,
                "variance" => 17.277977482448996,
                "std_deviation" => 4.156678659993937
            },
            "latitude" => {
              "avg" => 69,
            },
            "positioned" => "1991-01-31T12:00:00Z",
            "filter" => "4w-positioned"
          }
        ],
        "entries" => [{
          "latitude" => 69,
          "longitude" => 18,
          "title" => "test"
        }]
      }
    }
  end

  def http_search(query)
    Rack::Request.new(
      Rack::MockRequest.env_for(
        "/endpoint", "HTTP_HOST" => "example.org", "REQUEST_PATH" => "/endpoint",
        "QUERY_STRING" => "#{query}"
      )
    )
  end

  def geojson(request, r = response)
    Icelastic::ResponseWriter::GeoJSON.new(request, r)
  end

  context "normal" do

    it "return a feed header" do
      g = geojson(http_search("q=&format=geojson")).build
      g.should include('"feed":{}')
    end

    it "return a FeatureCollection" do
      g = geojson(http_search("q=&format=geojson")).build
      g.should include('"type":"FeatureCollection"')
    end

    it "return a Point feature by default" do
      g = geojson(http_search("q=&format=geojson")).build
      g.should include('"geometry":{"type":"Point"')
    end

    it "generate a point when geometry=point" do
      g = geojson(http_search("q=&format=geojson&geometry=point")).build
      g.should include('"geometry":{"type":"Point"')
    end

    it "return a LineString feature when &geometry=linestring" do
      g = geojson(http_search("q=&format=geojson&geometry=linestring")).build
      g.should include('"geometry":{"type":"LineString"')
    end

    it "return a MultiPoint feature when &geometry=multipoint" do
      g = geojson(http_search("q=&format=geojson&geometry=MultiPoint")).build
      g.should include('"geometry":{"type":"MultiPoint"')
    end

  end

  context "stats" do

    it "should use the avg position" do
      g = geojson(http_search("q=&format=geojson")).build
      g.should include('"coordinates":[18,69]')
    end

  end

end
