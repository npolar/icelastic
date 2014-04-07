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
        :url => "http://localhost:9200/",
        :index => "test",
        :type => "rspec",
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

        it "try localhost:9200 without arguments" do
          @client.client.cluster.health.should_not be(nil)
        end

        it "use default params when not overriden" do
          Icelastic::Default.params.should include("start" => 0, "limit" => 20)
        end

      end

      context "configuration" do

        it "override default params if provided" do
          Icelastic::Default.params.should include("start" => 1, "limit" => 2)
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
