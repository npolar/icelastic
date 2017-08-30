require 'spec_helper'

describe Icelastic::ResponseWriter::GeoJSON do

  def response
    {
      "feed" => {
        "opensearch" => {},
        "facets" => [
          {
          "year-positioned": [
          {
          "term": "2015",
          "count": 9,
          "uri": ""}
          ]
          }],
        "entries" => [{
          "latitude" => 69,
          "longitude" => 18,
          "prop1" => "val1",
          "sea_surface_temperature" => -1,
        },{
          "lat" => -90,
          "lng" => -180,
          "alt" => -1000,
          "sea_surface_temperature" => 0,
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

  context "format=geojson" do

    let!(:fc) { geojson(mock_request("q=&format=geojson")).build }
    let!(:features) { fc["features"] }
    let!(:feature) { features[0] }

    it "should return a GeoJSON FeatureCollection" do
      expect(fc.keys).to eq(["type", "features"])
      fc["type"].should eq("FeatureCollection")
    end

    it "where all features have a geometry and type" do
      features.size.should eq(response["feed"]["entries"].size)
      expect(features.all? {|f| f.key? "geometry"}).to be(true)
      expect(features.all? {|f| f.key? "geometry"}).to be(true)
    end

    it "use longitude, latitude as default keys for coordinates" do
      expect(feature["geometry"]).to eq({"type"=>"Point", "coordinates"=>[18, 69]})
    end

    context "geometry" do

      it "Point featured is set when requested via geometry=Point or when geometry is blank" do
        expect(features.map {|f|f["geometry"]}.all? {|g| g["type"] == "Point"}).to be(true) # blank
        g = geojson(mock_request("q=&format=geojson&geometry=Point")).build
        expect(g["features"].map {|f|f["geometry"]}.all? {|g| g["type"] == "Point"}).to be(true)
      end

      it "LineString features are returned when geometry=LineString" do
        g = geojson(mock_request("q=&format=geojson&geometry=LineString")).build
        expect(g["features"].map {|f|f["geometry"]}.all? {|g| g["type"] == "LineString"}).to be(true)
      end

      it "MultiPoint features are returned when &geometry=MultiPoint" do
        g = geojson(mock_request("q=&format=geojson&geometry=MultiPoint")).build
        expect(g["features"].map {|f|f["geometry"]}.all? {|g| g["type"] == "MultiPoint"}).to be(true)
      end

      it "should set geometry to null when &geometry=null" do
        g = geojson(mock_request("q=&format=geojson&geometry=null")).build
        expect(g["features"].map {|f| f["geometry"]}.all? {|g| g.nil? }).to be(true)
      end
    end

    it "return facets when requested" do
      g = geojson(mock_request("q=&format=geojson&facets=positioned")).build
      g.should have_key("facets")
    end

    context "feature" do
      it { expect(feature).not_to have_key("longitude") }
      it { expect(feature).not_to have_key("latitude") }
      it { expect(feature).not_to have_key("altitude") }
      context "properties" do
        it { expect(feature["properties"]).not_to have_key("longitude") }
        it { expect(feature["properties"]).not_to have_key("latitude") }
        it { expect(feature["properties"]).not_to have_key("altitude") }
        it { expect(feature["properties"]).to eq( {"prop1"=>"val1", "sea_surface_temperature"=>-1} )}
      end

    end

    it "override keys with coordinates=lng,lat,alt" do
      response = { "feed" => { "entries" => [{"lat" => -90,"lng" => -180, "alt" => -1000}] } }
      g = geojson(mock_request("q=&format=geojson&coordinates=lng,lat,alt"), response).build
      g["features"][0].should eq( {"type"=>"Feature", "geometry"=>{"type"=>"Point", "coordinates"=>[-180, -90, -1000]}, "properties"=>nil})
    end
end
  context "variant=atom" do
    it "response should include feed object with collection links and opensearch object" do
      g = geojson(mock_request("q=&format=geojson&variant=atom")).build
      g.should have_key("feed")
      g["feed"].should have_key("opensearch")
    end
    # it "response without &variant=atom should not include a feed object" do
    #   it { expect(fc).to_not have_key("feed") }
    # end
  end

  context "LineString" do
    let!(:feed) {
      JSON.parse('{ "feed": { "entries": [{
"sea_surface_temperature": -7.9,
"buoy": "SNOW_2015b",
"measured": "2015-04-23T18:00:00Z",
"longitude": 2.9088047574879434,
"latitude": 79.45492190977492
},
{
"buoy": "SNOW_2015b",
"measured": "2015-04-23T19:00:00Z",
"longitude": 2.9331071457802356,
"latitude": 79.46223555222599
},
{
"sea_surface_temperature": -6.8,
"buoy": "SNOW_2015b",
"measured": "2015-04-23T20:00:00Z",
"longitude": 2.927528373433181,
"latitude": 79.47636862975541
}]}')
    }
    let!(:ls) { geojson(mock_request("q=&format=geojson&geometry=LineString&variables=sea_surface_temperature,measured&filter-buoy=SNOW_2015b"), feed).build }
    let!(:geometry) { ls["features"][0]["geometry"]}

    describe "geometry" do
      it("type = LineString") { expect(geometry["type"]).to eq("LineString") }
      describe "coordinates" do
        it { expect(geometry["coordinates"]).to eq([[2.9088047574879434, 79.45492190977492],[2.9331071457802356, 79.46223555222599],[2.927528373433181, 79.47636862975541]]) }
      end
    end

    describe "properties" do
      it { expect(ls["features"][0]["properties"]).to eq( {"buoy"=>"SNOW_2015b", "measured"=>["2015-04-23T18:00:00Z", "2015-04-23T19:00:00Z", "2015-04-23T20:00:00Z"], "sea_surface_temperature"=>[-7.9, nil, -6.8]}) }
    end

  end

  # context "stats" do
  #   #@todo
  # end

end
