module Icelastic
  module ResponseWriter

    # Response writer that supports geojson generation based on the
    # libraries feed response
    #
    # [Authors]
    #   - Ruben Dens
    #
    # @example Basic Usage
    #   geojson = Icelastic::ResponseWriter::GeoJSON.new(request, response)
    #   geojson = geojson.build # build a feed hash
    #   geojson.to_json
    #
    # @example Parameter Switches
    #   # Controls the geometry type. Defaults to point
    #   &geometry=(point|multipoint|linestring)
    #
    # @see https://tools.ietf.org/html/rfc7946 GeoJSON (RFC7946)

    class GeoJSON

      attr_accessor :feed, :stats, :facets, :entries, :params

      def self.format  
        "geojson"
      end
      
      def self.type
        "application/geo+json"
      end
      
      def self.from
        ResponseWriter::Feed
      end
      
      def initialize(request, feed)
        self.params = request.params
        self.entries = feed["feed"]["entries"]
        self.facets = feed["feed"]["facets"]
        self.stats = feed["feed"]["stats"]
        self.feed = feed["feed"].delete_if{|k| ["entries", "facets", "stats"].include?(k) }
      end

      def build
        fc = {
          "type" => "FeatureCollection"
        }
        
        bbox = Default.geo_params["bbox"]
        if params.key? bbox and (3..5).include? params[bbox].count(",")
          bbox = params["bbox"].split(",").map {|c| c.to_f}
          fc["bbox"] = bbox # There's no need to validate because ES crashes if the coords are out of bounds of WGS84 decimal degrees
        end
        
        fc["features"] = features
        
        if params.key? "variant" and params["variant"] == "atom"
          fc["feed"] = feed
        end
        if params.key? "facets"
          fc["facets"] = facets
        end
        if params.key? "stats"
          fc["stats"] = stats
        end
        fc
        
      end
      
      private

      def defaults
        Icelastic::Default.geo_params
      end

      # Returns a hash of common items in two hashes
      def common_items(obj1, obj2)
        obj1.select do |k,v|
          obj2.has_key?(k) && v == obj2[k]
        end
      end

      # Check if the object contains the geo fields
      def geo?(obj)
        obj[lat_key] && obj[lng_key]
      end

      # True if the geometry is set by the user
      def geometry?
        params.any?{|k, v| k =~ /^geometry$/}
      end
      
      def generate_points(items = entries)
        items.each_with_index.map do |e, i|
          if geo?(e)
            {
              "type" => "Feature",
              "geometry" => {
                "type" => "Point",
                "coordinates" => [longitude(e), latitude(e)]
              },
              "properties" => e.merge({"sequence" => i}) #stats ? flatten_stats(e) : e
            }
          end
        end
      end

      # Generate a feature with multiple elements like LineString and MultiPoint
      def generate_multi_feature(items = entries, type)
        [
          {
            "type" => "Feature",
            "geometry" => {
              "type" => type,
              "coordinates" => items.map{|e| [longitude(e), latitude(e)] if geo?(e)}
            },
            "properties" => global_properties(items)
          }
        ]
      end

      def global_properties(items)
        p = {
          "start_latitude" => latitude(items.first),
          "start_longitude" => longitude(items.first),
          "stop_latitude" => latitude(items.last),
          "stop_longitde" => longitude(items.last)
        }
        p.merge(common_items(items.first, items.last))
      end

      #def generate_contextline(items = entries)
        #i = items.each_with_index.map do |e, i|
          #if !(items.size - 1 == i) && geo?(e) && geo?(items[i + 1])
            #{
              #:type => :Feature,
              #:geometry => {
                #:type => :LineString,
                #:coordinates => [
                  #[longitude(e), latitude(e)],
                  #[longitude(items[i+1]), latitude(items[i+1])]
                #]
              #},
              #:properties => {
                #"sequence" => i,
                #"start" => e,
                #"stop" => items[i+1]
              #}
            #}
          #end
        #end
        #i.pop
        #i
      #end

      def lat_key
        defaults["latitude"]
      end

      def lng_key
        defaults["longitude"]
      end

      def feature? test
        test.key? "type" and test["type"] == "Feature" and test.key? "geometry" and (test["geometry"].key?("coordinates") || test["geometry"].key?("geometries"))
      end

      # Extract latitude from the object
      def latitude(obj)
        stats ? obj[lat_key]["avg"] : obj[lat_key]
      end

      # Extract longitude from the object
      def longitude(obj)
        stats ? obj[lng_key]["avg"] : obj[lng_key]
      end

      # Return which mode to use
      def mode
        geometry? ? params["geometry"] : defaults["geometry"]
      end

      # Trigger the correct generator depending on the mode
      def features
        if entries.size > 0 and feature?(entries[0])
          entries
        else case mode
          when /LineString/i then stats ? generate_multi_feature(stats, "LineString") : generate_multi_feature(entries, "LineString")
          when /MultiPoint/i then stats ? generate_multi_feature(stats, "MultiPoint") : generate_multi_feature(entries, "MultiPoint")
          #when /ContextLine/i then stats ? generate_contextline(stats) : generate_contextline
          else stats ? generate_points(stats) : generate_points
          end
        end
      end

      #def flatten_stats(stat)
        #obj = {}
        #stat.each do |k,v|
          #if v.is_a?(Hash)
            #obj["header"] ||= ["count", "min", "max", "avg", "sum", "sum_of_squares", "variance", "std_deviation"]
            #obj[k] = [v["count"], v["min"], v["max"], v["avg"], v["sum"], v["sum_of_squares"], v["variance"], v["std_deviation"]]
            #stat.delete(k)
          #end
        #end

        #stat.merge(obj)
      #end

    end
  end
end