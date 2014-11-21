require "feed_helper"

describe Icelastic::ResponseWriter::HAL do
  
  def es_response_hash
    es_response_hash = elastic_response_hash
    es_response_hash["hits"]["hits"][0]["_source"] = { "title" => "HAL" }
    es_response_hash["hits"]["hits"][1]["_source"] = { "links" => [{"rel" => "edit", "href" => "http://example.com/edit-me", "title" => "Me"}]}
    es_response_hash
  end
  
  subject(:hal) {
    Icelastic::ResponseWriter::HAL.new(mock_request("q=&format=hal"), es_response_hash).build  
  }
  
  context "_links" do
    it do
      expect(hal["_links"]).to eq( {"self"=>{"href"=>"http://example.org/endpoint?start=0&limit=100&size-facet=10&variant=legacy&q=&format=hal"}, "first"=>{"href"=>"http://example.org/endpoint?q=&format=hal"}, "last"=>{"href"=>"http://example.org/endpoint?q=&format=hal"}, "edit"=>[{"href"=>"http://example.com/edit-me", "title"=>"Me"}]})
    end
  end
  
  context "embed" do
    
    context "= false" do
      subject(:hal) {
        Icelastic::ResponseWriter::HAL.new(mock_request("q=&format=hal&embed=false"), es_response_hash).build  
      }
      it "_embedded = {}" do
        expect(hal["_embedded"]).to eq({})
      end
    end
    
    context "= true" do
      subject(:hal) {
        Icelastic::ResponseWriter::HAL.new(mock_request("q=&format=hal&embed=true"), es_response_hash).build  
      }
      it "_embedded contains a document array" do
        expect(hal["_embedded"]).to have_key("document")
      end
    end
    
  end
  
end