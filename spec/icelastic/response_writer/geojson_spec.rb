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

  def mock_request(query)
    Rack::Request.new(
      Rack::MockRequest.env_for(
        "/endpoint", "HTTP_HOST" => "example.org", "REQUEST_PATH" => "/endpoint",
        "QUERY_STRING" => "#{query}"
      )
    )
  end

  def geojson(request, r = response)
    Icelastic::Default.geo_params = Icelastic::Default::GEO_PARAMS
    Icelastic::ResponseWriter::GeoJSON.new(request, r)
  end

  context "normal" do

    it "return a feed header" do
      g = geojson(mock_request("q=&format=geojson")).build
      g.should have_key("feed")
    end

    it "type = FeatureCollection" do
      g = geojson(mock_request("q=&format=geojson")).build
      g["type"].should eq("FeatureCollection")
    end

    it "with Point geometry [default]" do
      g = geojson(mock_request("q=&format=geojson")).build
      expect(g["features"].map {|f|f["geometry"]}.all? {|g| g["type"] == "Point"}).to be(true)
    end
    
    it "with Point geometry when geometry=point" do      
      g = geojson(mock_request("q=&format=geojson&geometry=point")).build
      expect(g["features"].map {|f|f["geometry"]}.all? {|g| g["type"] == "Point"}).to be(true)
    end

    it "with LineString geometry when &geometry=linestring" do
      g = geojson(mock_request("q=&format=geojson&geometry=linestring")).build
      expect(g["features"].map {|f|f["geometry"]}.all? {|g| g["type"] == "LineString"}).to be(true)
    end

    it "return a MultiPoint feature when &geometry=multipoint" do
      g = geojson(mock_request("q=&format=geojson&geometry=MultiPoint")).build
      expect(g["features"].map {|f|f["geometry"]}.all? {|g| g["type"] == "MultiPoint"}).to be(true)
    end

  end

  context "stats" do

    it "should use the avg position" do
      g = geojson(mock_request("q=&format=geojson")).build.to_json
      g.should include('"coordinates":[18,69]')
    end

  end

end
