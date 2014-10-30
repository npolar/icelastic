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
        @request = request
        @feed = Icelastic::ResponseWriter::Feed.new(request, elasticsearch_response_hash)
      end
            
      def build(&block)
        @feed.build do |feed|
          
          # feed#links
          _links = hal_links_hash(feed.links)
          # @todo create CURIEs from feed.entries.map {|e| e.key? "schema" ? e["schema"] : nil }.uniq
          
          # "edit" links
          edit_links = feed.entries.select {|e| e.key?("links")}.map {|e|
            e["links"].first {|link| link["rel"] == "edit"}
          }
          if edit_links.any?
            _links = _links.merge hal_links_array(edit_links, "edit")
          end

          if @request["embed"] =~ /true/
            _embedded = {"document" => feed.entries.map {|entry|
              if entry.key? "links"
                entry_links = hal_links_hash(entry["links"])
                entry["_links"] = entry_links
                entry.delete "links"
              end
              entry
              }
            }
          else
            _embedded = {}
          end
          
          { "_links" => _links,
            "_embedded" => _embedded,
            "search" => feed.search
          }
          
        end
      end
      
      protected
      
      # One (1) HAL link hash for each relation
      # @return [Hash]
      def hal_links_hash(links)
        _links = {}
        links.select {|link| link["href"] != false }.each do |link|
          _links[link["rel"]] = _link(link)
        end
        _links
      end
      
      # HAL links array for a relation
      # @return Array
      def hal_links_array(links, rel)
        { rel => links.map {|link| _link(link) } }
      end
      
      # @return [Hash] Link attributes except "rel"
      def _link(link)
        _link = {}
        link.select {|k,v| k != "rel" and link["href"] != false }.each do |k,v|
          _link[k] = v
        end
        _link
      end
      
    end
  end
end