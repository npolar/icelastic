require "feed_helper"

describe Icelastic::ResponseWriter::HAL do
    
  context "hal" do
    
    subject(:hal) {
      
      request = mock_request("q=&format=hal")
      es_response_hash = elastic_response_hash
      es_response_hash["hits"]["hits"][0]["_source"] = { "title" => "HAL" }
      es_response_hash["hits"]["hits"][1]["_source"] = { "links" => [{"rel" => "self", "href" => "http://example.com/self", "title" => "Self"}]}
      Icelastic::Default.params = Icelastic::Default::DEFAULT_PARAMS
      Icelastic::ResponseWriter::HAL.new(request, es_response_hash).build  
    }
    
    context "_links" do
      it do
        expect(hal["_links"]).to eq({"self"=>{"rel"=>"self", "href"=>"http://example.org/endpoint?q=&format=hal"}, "first"=>{"rel"=>"first", "href"=>"http://example.org/endpoint?start=0&limit=100&size-facet=10&variant=legacy&q=&format=hal"}, "previous"=>{"rel"=>"previous", "href"=>false}, "next"=>{"rel"=>"next", "href"=>false}, "last"=>{"rel"=>"last", "href"=>"http://example.org/endpoint?start=0&limit=100&size-facet=10&variant=legacy&q=&format=hal"}})
      end
    end
    
    context "_embedded" do
    
      it do
        expect(hal["_embedded"]).to eq([{"title"=>"HAL", "highlight"=>"<em><strong>est</strong></em>"}, {"_links"=> {"self"=>{"rel"=>"self", "href"=>"http://example.com/self", "title"=>"Self"}}}])
      end
    end
    
  end
end