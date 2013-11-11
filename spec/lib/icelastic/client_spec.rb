require "spec_helper"
require "icelastic/client"

require "elasticsearch"

describe Icelastic::Client do

  def search_request
    Rack::Request.new(
      Rack::MockRequest.env_for(
        "/", "HTTP_HOST" => "example.org", "REQUEST_PATH" => "", "QUERY_STRING" => "q=bear"
      )
    )
  end

  def index_request
    Rack::Request.new(
      Rack::MockRequest.env_for(
        "/", "HTTP_HOST" => "example.org", "REQUEST_METHOD" => "POST", "REQUEST_PATH" => "",
        "rack.input" => StringIO.new({:id => 1, :title => "My test document"}.to_json)
      )
    )
  end

  def update_request
    Rack::Request.new(
      Rack::MockRequest.env_for(
        "/", "HTTP_HOST" => "example.org", "REQUEST_METHOD" => "POST", "REQUEST_PATH" => "",
        "rack.input" => StringIO.new({:id => 1, :title => "Updated test document"}.to_json)
      )
    )
  end

  def bulk_request
    Rack::Request.new(
      Rack::MockRequest.env_for(
        "/", "HTTP_HOST" => "example.org", "REQUEST_METHOD" => "POST", "REQUEST_PATH" => "",
        "rack.input" => StringIO.new([
          {:id => 2, :title => "Bulk a"},
          {:id => 3, :title => "Bulk b"}
        ].to_json)
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
        }
      }
      @client = Icelastic::Client.new(config)
    end

    context "#initialize" do

      context "defaults" do

        before(:each) do
          @client = Icelastic::Client.new
        end

        it "try localhost:9200 without arguments" do
          @client.client.cluster.health.should_not be(nil)
        end

        it "use default params when not overriden" do
          @client.params.should include(:start => 0, :limit => 25)
        end

      end

      context "configuration" do

        it "override default params if provided" do
          @client.params.should include(:start => 1, :limit => 2)
        end

      end

    end

    context "#search" do

      it "return a feed response" do
        JSON.parse(@client.search(search_request)).should include("opensearch","entries")
      end

    end

    context "#index" do

      it "add document" do
        @client.index(index_request).should include("ok" => true)
      end

      it "update document" do
        @client.index(update_request).should include("ok" => true)
      end

    end

    context "#bulk" do

      it "index multiple items" do
        @client.bulk(bulk_request)["items"][0]["index"].should include("ok" => true)
      end

    end

  end

end