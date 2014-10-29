module Icelastic
  module ResponseWriter
    class HAL
      
      def self.format
        "hal"
      end
      
      def self.type
        "application/hal+json"
      end
      
      def initialize(request, elasticsearch_response_hash)
        @feed = Icelastic::ResponseWriter::Feed.new(request, elasticsearch_response_hash)
      end
            
      def build
        @feed.build do |feed|
          
          _links = hal_links_hash_from_links_array(feed.links)
          
          { "_links" => _links,
            "_embedded" => feed.entries.map {|entry|
              if entry.key? "links"
                entry["_links"] = hal_links_hash_from_links_array(entry["links"])
                entry.delete "links"
              end
              entry
            }
          }
        end
      end
      
      protected
      
      def hal_links_hash_from_links_array(links)
        _links = {}
        links.each do |link|
          _link = {}
          link.each do |k,v|
            _link[k] = v
          end
          _links[link["rel"]] = _link
        end
        _links
      end
      

      
    end
  end
end