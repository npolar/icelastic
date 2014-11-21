require "feed_helper"
require "spec_helper"

describe Icelastic::ResponseWriter::Feed do
  
  def feed_factory(request=nil, r = elastic_response_hash)
    if request.nil? or request.is_a? String
      request = mock_request(request)
    end
    Icelastic::Default.params = Icelastic::Default::DEFAULT_PARAMS # Reset the defaults from the client
    Icelastic::ResponseWriter::Feed.new(request, r)
  end

  QUERY_STRING = "q=&limit=100&start=0&facets=tags,temperature"

  describe "#build" do
  
    subject(:query_string) {QUERY_STRING}
    
    subject(:feed) { feed_factory(mock_request(query_string)) }
    
    it "returns a feed Hash" do
      expect(feed.build.keys.first).to eq("feed")
    end
    
    exp = ["entries", "facets", "list", "opensearch", "search", "stats"].sort
    it "feed keys are #{exp.join(',')}" do
      expect(feed.build["feed"].keys.sort).to eq(exp)
    end
    
    it "yields a block" do
      expect( feed.build {|feed|
        [feed.class.name] + feed.entries.map {|e| e["title"] } }).to eq(["Icelastic::ResponseWriter::Feed", "test1","test2"])
    end
  
    context "opensearch" do
  
      it "totalResults (from #total_results)" do
        expect(feed.total_results).to eq(40)
      end
  
      it "itemsPerPage (from #items_per_page)" do
        expect(feed.items_per_page).to eq(100)
      end
  
      it "startIndex (from #start_index)" do
        expect(feed.start_index).to eq(0)
      end
    end

    context "#search" do
      it "return query time" do
        f = feed_factory( mock_request("q=") ).send(:qtime)
        f.should == 34
      end
  
      it "return query" do
        f = feed_factory( mock_request("q=foobar") ).send(:query_term)
        f.should == "foobar"
      end
    
      context "&score" do
        
        subject(:feed) { feed_factory("q=&score") }
        
        it "max_score" do
          expect(feed.search["max_score"]).to eq(0.7834767)
        end
        it "_score" do
          expect(feed.entries.all? {|e| e.key? "_score"}).to eq(true)
        end
        
      end
      context "no score parameter" do
        it "no max_score" do
          feed = feed_factory(mock_request("q="))
          expect(feed.search).not_to have_key("max_score")
        end
      end  
    end
  
  context "variant" do
    
    context "array" do
      
      subject(:feed) { feed_factory("q=&format=json&variant=array") }
      
      it do
        expect(feed.build).to be_a(Array)
      end
      
      it "of source documents" do
        expect(feed.build).to eq([{"title"=>"test1", "highlight"=>"<em><strong>est</strong></em>"}, {"title"=>"test2"}])
      end
      
    end
    
    context "atom" do
      
      subject(:feed) { feed_factory("q=&format=json&variant=atom").build }
      
      it do
        expect(feed["feed"]).to have_key("links")
      end
      
      describe "#links" do
          
          subject(:links) { feed_factory("q=foo").links }
        
          it "returns array of link objects containing \"rel\" and \"href\"" do
            expect(links.map {|l| l.keys }).to include(["rel", "href"])
          end
      
          wanted_relations = ["self", "first", "next", "previous", "last"].sort
          it "link relations include #{wanted_relations.to_json}" do
            expect(links.map {|l| l["rel"] }.sort).to eq(wanted_relations)
          end
      
          it "\"self\" href should contain the search uri" do
            expected_self_uri = "http://example.org/endpoint/?q="
            actual_self_uri = links.first {|l| l["rel"] == "self" }["href"]
            
            expect(actual_self_uri).to eq_uri(expected_self_uri)
          end
          
          it "\"first\" href should equal the first page uri (of the current search)" do
            expected_first_uri = ""
            expect(links.first {|l| l["rel"] == "first" }["href"]).to eq_uri(expected_first_uri)
          end
      
        end
      
    end

  end

  end
  
  describe "#stats" do
    subject(:feed) { feed_factory("q=foo&date-day=created[temperature]") }
      
      #it do
      #  expect(feed.build).to have_key("stats")
      #end
      
      #it do
      #  expect(feed.build).to not_have_key("entries ")
      #end
    
      it do
        expect(feed.stats).to eq([{"doc_count"=>24, "created"=>"2008-07-09", "filter"=>"day-created"}])
      end
   end

  describe "#entries" do
    
    subject(:entries) { feed_factory(mock_request("q=foo")).entries }

    it "returns array corresponding to the _source array" do
      expect(entries.map {|e|e["title"]} ).to eq(["test1", "test2"])
    end
    
    # FIXME _highlight
    it "return highlighted segments with the entry" do
      f = feed_factory( mock_request("q=foo") )
      f.entries.first.should include("highlight" =>"<em><strong>est</strong></em>")
    end

    it "return aggregated buckets when doing statistics" do
      f = feed_factory("q=&date-day=measured[temperature|pressure]")
      f.stats.first.should include("filter" => "day-measured")
    end

  end

  context "#facets" do

    subject(:facets) { feed_factory("q=foo&facets=tags").facets }

    it do
      expect(facets).to be_a(Array)
    end
    
    it "with one object per facet" do
      expect(facets.size).to eq(7) # the mock contains 7 
    end
    
    it "empty array when facets=false" do
      feed = feed_factory("q=foo&facets=false")
      expect(feed.facets).to eq([])
    end
    
    it "returns an array consisting of objects with facet name as keys" do
      expect(facets.map {|f| f.keys}.flatten.sort).to eq(["day-created", "day-measured", "hour-created", "month-created", "tags", "temperature", "year-created"])
    end

    context "all objects under a facet name must have" do
      ["term", "uri", "count"].each do |k|
        it k do
          facets[0]["tags"].all? {|facet| expect(facet).to have_key(k) }
        end
      end
    end
  

    context "object" do

      it "term equals the facet name" do
        expect(facets[0]["tags"][0]).to include("term" => "foo")
      end
      
      it "string formatted term when date" do
        f = feed_factory( mock_request("q=foo&date-day=created") )
        f.facets[2]["day-created"].first.should include("term" => "2008-07-09")
      end

      it "return count" do
        f = feed_factory( mock_request("q=foo&facets=tags") )
        f.facets[0]["tags"].first.should include("count" => 88)
      end

      it "generate filtered facet term uri" do
        f = feed_factory( mock_request("q=foo&facets=tags&filter-tags=bar") )
        f.facets[0]["tags"].first.should include("uri" => "http://example.org/endpoint?q=foo&facets=tags&filter-tags=bar,foo")
      end

      it "replace space with + in uri" do
        f = feed_factory( mock_request("q=foo&facets=tags") )
        f.facets[0]["tags"].last.should include("uri" => "http://example.org/endpoint?q=foo&facets=tags&filter-tags=foo+bar")
      end

      it "generate unfiltered facet term uri" do
        f = feed_factory( mock_request("q=foo&facets=tags&filter-tags=foo,bar") )
        f.facets[0]["tags"].first.should include("uri" => "http://example.org/endpoint?q=foo&facets=tags&filter-tags=bar")
      end

      it "use named facet term in uri" do
        f = feed_factory( mock_request("q=foo&facet-keywords=tags") )
        f.facets[0]["tags"].first.should include("uri" => "http://example.org/endpoint?q=foo&facet-keywords=tags&filter-tags=foo")
      end

      context "temporal facets" do

        it "handle hour interval" do
          f = feed_factory( mock_request("q=foo&date-hour=created") ).facets
          f[1]["hour-created"].first.should include("uri" => "http://example.org/endpoint?q=foo&date-hour=created&filter-created=2008-07-09T00:00:00Z..2008-07-09T01:00:00Z")
        end

        it "handle day interval" do
          f = feed_factory( mock_request("q=foo&date-day=created") ).facets
          f[2]["day-created"].first.should include("uri" => "http://example.org/endpoint?q=foo&date-day=created&filter-created=2008-07-09T00:00:00Z..2008-07-10T00:00:00Z")
        end

        it "handle month interval" do
          f = feed_factory( mock_request("q=foo&date-month=created") ).facets
          f[3]["month-created"].first.should include("uri" => "http://example.org/endpoint?q=foo&date-month=created&filter-created=2008-07-01T00:00:00Z..2008-08-01T00:00:00Z")
        end

        it "handle year interval" do
          f = feed_factory( mock_request("q=foo&date-year=created") ).facets
          f[4]["year-created"].first.should include("uri" => "http://example.org/endpoint?q=foo&date-year=created&filter-created=2008-01-01T00:00:00Z..2009-01-01T00:00:00Z")
        end

      end

      context "when rangefacets is in query" do
        it "handle range" do
          f = feed_factory( mock_request("q=foo&rangefacet-temperature=1") ).facets
          f.find {|i| i.member?("temperature")}["temperature"].first.should include("uri" => "http://example.org/endpoint?q=foo&rangefacet-temperature=1&filter-temperature=-30..-29")
        end

        it "returns terms with ints" do
          f = feed( http_search("q=foo&rangefacet-temperature=1") ).facets
          f["facets"].find {|i| i.member?("temperature")}["temperature"].first.should include("term" => "-30..-29")
        end
      end
    end
  end
  
end
