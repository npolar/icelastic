require "spec_helper"

describe Rack::Icelastic do

  def app
    Rack::Builder.new do |builder|
      use Rack::Icelastic, :index => 'test', :type => 'rspec', :params => {:limit => 1}
      run lambda{|env| [200, {"Content-Type" => "text/plain"}, ["passed"]]}
    end
  end

  def env
    Rack::MockRequest.env_for("/", "HTTP_HOST" => "example.org", "REQUEST_PATH" => "", "QUERY_STRING" => "q=")
  end

  context "#initialize" do

  end

  context "#call" do

    context "GET" do

      it "pass on non search requests" do
        e = Rack::MockRequest.env_for(
          "/", "HTTP_HOST" => "example.org", "REQUEST_PATH" => ""
        )
        status, headers, body = app.call(e)
        body.first.should == "passed"
      end

      it "search when it has a query string" do
        app.call(env)[2].first.should include("feed")
      end

    end

  end

end