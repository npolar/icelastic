require "spec_helper"

describe Icelastic::Client do

  def search_request(query)
    Rack::Request.new(
      Rack::MockRequest.env_for(
        "/", "HTTP_HOST" => "example.org", "REQUEST_PATH" => "", "QUERY_STRING" => query
      )
    )
  end

  context "Client" do

    before(:each) do
      config = {
        :url => "http://localhost:9350/",
        :index => "rspec",
        :type => "spec",
        :log => false,
        :params => {
          :start => 1,
          :limit => 2
        },
        :geojson => {
          :geometry => "linestring",
          :latitude => "lat",
          :longitude => "lng"
        }
      }
      @client = Icelastic::Client.new(config)
    end

    context "#initialize" do

      context "defaults" do

        before(:each) do
          Icelastic::Default.params = Icelastic::Default::DEFAULT_PARAMS
          @client = Icelastic::Client.new
        end

        it "use default params when not overriden" do
          Icelastic::Default.params.should include("start" => 0, "limit" => 100)
        end

      end

      context "configuration" do

        it "override default params" do
          Icelastic::Default.params.should include("start" => 1, "limit" => 2)
        end

        it "override default geo_params" do
          Icelastic::Default.geo_params.should include("latitude" => "lat", "longitude" => "lng")
        end

      end

    end

    context "#search" do

      it "return a raw response" do
        JSON.parse(@client.search(search_request("q=&format=raw"))).should include("hits")
      end

      it "return a feed response" do
        JSON.parse(@client.search(search_request("q=bear"))).should include("feed")
      end

      it "return a csv response" do
        Icelastic::ResponseWriter::Csv.any_instance.stub(:build).and_return("csv response")
        @client.search(search_request("q=bear&format=csv")).should == "csv response"
      end

      it "return a geojson response" do
        Icelastic::ResponseWriter::GeoJSON.any_instance.stub(:build).and_return("GeoJSON")
        @client.search(search_request("q=bear&format=geojson")).should == "GeoJSON"
      end

      it "return a all documents" do
        JSON.parse(@client.search(search_request("q=bear&limit=all"))).should include("feed")
      end

    end

  end

end
