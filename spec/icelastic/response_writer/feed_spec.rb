require 'spec_helper'

describe Icelastic::ResponseWriter::Feed do

  def response
    {
      "took"=>34,
      "timed_out"=>false,
      "_shards"=>{"total"=>8, "successful"=>8, "failed"=>0},
      "hits"=> {
        "total"=>40,
        "max_score"=>0.7834767,
        "hits"=> [
          {"_score" => 1, "_source"=> {"title"=>"test1"}, "highlight" => {"_all" => ["<em><strong>est</strong></em>"]}},
          {"_score" => 1, "_source"=> {"title"=>"test2"}}
        ]
      },
      "aggregations" => {
        "tags" => {"buckets" => [{"key" => "foo","doc_count" => 88}, {"key" => "foo bar","doc_count" => 88}]},
        "hour-created" => {"buckets" => [{"key_as_string" => "2008-07-09","key" => 1215561600000,"doc_count" => 24}]},
        "day-created" => {"buckets" => [{"key_as_string" => "2008-07-09","key" => 1215561600000,"doc_count" => 24}]},
        "month-created" => {"buckets" => [{"key_as_string" => "2008-07","key" => 1215561600000,"doc_count" => 24}]},
        "year-created" => {"buckets" => [{"key_as_string" => "2008","key" => 1215561600000,"doc_count" => 24}]},
        "day-measured" => {"buckets" => [{"key_as_string" => "2014-02-22T06:00:00Z","key" => 1393092000000}]},
        "temperature" => {"buckets" => [{"key" => -30.0,"doc_count" => 241}]}
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

  def feed(request, r = response)
    Icelastic::Default.params = Icelastic::Default::DEFAULT_PARAMS # Reset the defaults from the client
    Icelastic::ResponseWriter::Feed.new(request, r)
  end

  it "build a json response" do
    f = feed( http_search("q=") ).build
    f.should include("feed")
  end

  context "opensearch" do

    it "return totalResults" do
      f = feed( http_search("q=") ).send(:total_results)
      f.should == 40
    end

    it "return itemsPerPage" do
      f = feed( http_search("q=&limit=50") ).send(:limit)
      f.should == 50
    end

    it "return startIndex" do
      f = feed( http_search("q=&start=33") ).send(:start)
      f.should == 33
    end

  end

  context "list" do

    it "return the uri for this page (self)" do
      f = feed( http_search("q=foobar") ).send(:self_uri)
      f.should == "http://example.org/endpoint?q=foobar"
    end

    it "return start index for the page" do
      f = feed( http_search("q=&start=10") ).send(:first)
      f.should == 10
    end

    it "return stop index for the page" do
      f = feed( http_search("q=&start=10&limit=5") ).send(:last)
      f.should  == 14
    end

    it "return next page uri" do
      f = feed( http_search("q=foobar&start=10&limit=5&filter-date=2012..2014") ).send(:next_uri)
      f.should == "http://example.org/endpoint?start=15&limit=5&q=foobar&filter-date=2012..2014"
    end

    it "return false when there is no next page" do
      f = feed( http_search("q=foobar&start=30&filter-date=2012..2014") ).send(:next_uri)
      f.should == false
    end

    it "return previous uri" do
      f = feed( http_search("q=foobar&start=20&limit=5&filter-date=2012..2014") ).send(:previous_uri)
      f.should == "http://example.org/endpoint?start=15&limit=5&q=foobar&filter-date=2012..2014"
    end

    it "return false when no previous uri" do
      f = feed( http_search("q=foobar&start=0&filter-date=2012..2014") ).send(:previous_uri)
      f.should == false
    end

  end

  context "search" do

    it "return query time" do
      f = feed( http_search("q=") ).send(:qtime)
      f.should == 34
    end

    it "return query" do
      f = feed( http_search("q=foobar") ).send(:query_term)
      f.should == "foobar"
    end

    context "when score parameter is in query" do
      it "return max_score" do
        f = feed(http_search("q=&score")).send(:search)
        expect(f["search"]["max_score"]).to eq(0.7834767)
      end
    end
    context "when score parameter is not in query" do
      it "not return max_score" do
        f = feed(http_search("q=")).send(:search)
        expect(f["search"]).not_to have_key("max_score")
      end
    end
  end

  context "facets" do

    it "be an array" do
      f = feed( http_search("q=foo&facets=tags") ).facets
      f["facets"].should be_a(Array)
    end

    it "disable when facets=false" do
      f = feed( http_search("q=foo&facets=false") ).build
      f["feed"].should include( "facets" => nil )
    end

    context "structure" do

      it "be a item array" do
        f = feed( http_search("q=foo&facets=tags") ).facets
        f["facets"][0]["tags"].should be_a(Array)
      end

      it "have a term" do
        f = feed( http_search("q=foo&facets=tags") ).facets
        f["facets"][0]["tags"].first.should have_key("term")
      end

      it "have a count" do
        f = feed( http_search("q=foo&facets=tags") ).facets
        f["facets"][0]["tags"].first.should have_key("count")
      end

      it "have a uri" do
        f = feed( http_search("q=foo&facets=tags") ).facets
        f["facets"][0]["tags"].first.should have_key("uri")
      end

    end

    context "object" do

      it "contain term" do
        f = feed( http_search("q=foo&facets=tags") ).facets
        f["facets"][0]["tags"].first.should include("term" => "foo")
      end

      it "string formatted term when date" do
        f = feed( http_search("q=foo&date-day=created") ).facets
        f["facets"][2]["day-created"].first.should include("term" => "2008-07-09")
      end

      it "return count" do
        f = feed( http_search("q=foo&facets=tags") ).facets
        f["facets"][0]["tags"].first.should include("count" => 88)
      end

      it "generate filtered facet term uri" do
        f = feed( http_search("q=foo&facets=tags&filter-tags=bar") ).facets
        f["facets"][0]["tags"].first.should include("uri" => "http://example.org/endpoint?q=foo&facets=tags&filter-tags=bar,foo")
      end

      it "replace space with + in uri" do
        f = feed( http_search("q=foo&facets=tags") ).facets
        f["facets"][0]["tags"].last.should include("uri" => "http://example.org/endpoint?q=foo&facets=tags&filter-tags=foo+bar")
      end

      it "generate unfiltered facet term uri" do
        f = feed( http_search("q=foo&facets=tags&filter-tags=foo,bar") ).facets
        f["facets"][0]["tags"].first.should include("uri" => "http://example.org/endpoint?q=foo&facets=tags&filter-tags=bar")
      end

      it "use named facet term in uri" do
        f = feed( http_search("q=foo&facet-keywords=tags") ).facets
        f["facets"][0]["tags"].first.should include("uri" => "http://example.org/endpoint?q=foo&facet-keywords=tags&filter-tags=foo")
      end

      context "temporal facets" do

        it "handle hour interval" do
          f = feed( http_search("q=foo&date-hour=created") ).facets
          f["facets"][1]["hour-created"].first.should include("uri" => "http://example.org/endpoint?q=foo&date-hour=created&filter-created=2008-07-09T00:00:00Z..2008-07-09T01:00:00Z")
        end

        it "handle day interval" do
          f = feed( http_search("q=foo&date-day=created") ).facets
          f["facets"][2]["day-created"].first.should include("uri" => "http://example.org/endpoint?q=foo&date-day=created&filter-created=2008-07-09T00:00:00Z..2008-07-10T00:00:00Z")
        end

        it "handle month interval" do
          f = feed( http_search("q=foo&date-month=created") ).facets
          f["facets"][3]["month-created"].first.should include("uri" => "http://example.org/endpoint?q=foo&date-month=created&filter-created=2008-07-01T00:00:00Z..2008-08-01T00:00:00Z")
        end

        it "handle year interval" do
          f = feed( http_search("q=foo&date-year=created") ).facets
          f["facets"][4]["year-created"].first.should include("uri" => "http://example.org/endpoint?q=foo&date-year=created&filter-created=2008-01-01T00:00:00Z..2009-01-01T00:00:00Z")
        end

      end

      context "when rangefacets is in query" do
        it "handle range" do
          f = feed( http_search("q=foo&rangefacet-temperature=1") ).facets
          f["facets"].find {|i| i.member?("temperature")}["temperature"].first.should include("uri" => "http://example.org/endpoint?q=foo&rangefacet-temperature=1&filter-temperature=-30..-29")
        end

        it "returns terms with ints" do
          f = feed( http_search("q=foo&rangefacet-temperature=1") ).facets
          f["facets"].find {|i| i.member?("temperature")}["temperature"].first.should include("term" => "-30..-29")
        end
      end
    end

  end

  context "entries" do

    it "return the _source object as entry" do
      f = feed( http_search("q=foo") ).entries
      f["entries"].first.should include("title"=>"test1")
    end

    it "return highlighted segments with the entry" do
      f = feed( http_search("q=foo") ).entries
      f["entries"].first.should include("highlight" =>"<em><strong>est</strong></em>")
    end

    it "return aggregated buckets when doing statistics" do
      f = feed( http_search("q=&date-day=measured[tempearture|pressure]") ).stats
      f["stats"].first.should include("filter" => "day-measured")
    end

    context "when score parameter is in query" do
      it "return scores" do
        f = feed( http_search("q=foo&score") ).entries
        expect(f["entries"].first).to have_key("_score")
      end
    end
    context "when score parameter is not in query" do
      it "not return max_score" do
        f = feed( http_search("q=foo") ).entries
        expect(f["entries"].first).not_to have_key("_score")
      end
    end

  end

end
