module Icelastic
  module ResponseWriter

    # GeoJSON response writer based on the icelastic feed response
    #
    # [Authors]
    #   - Ruben Dens
    #
    # @example Basic Usage
    #   geojson = Icelastic::ResponseWriter::GeoJSON.new(request, response)
    #   geojson = geojson.build # build a feed hash
    #   geojson.to_json
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

        # Null properties?
        if params["properties"] == "null"
          fc["features"].map! {|f|
            f["properties"]=nil
            f
          }
        end

        # Null geometry?
        if params["geometry"] == "null"
          fc["features"].map! {|f|
            f["geometry"]=nil
            f
          }
        end

        if params.key? "variant" and params["variant"] == "atom"
          fc["feed"] = feed
        end
        if params.key? "facets"
          fc["facets"] = facets
        end
        if params.key? "stats"
          fc["stats"] = stats
        end
        if params.key? "type" and params["type"] =~ /^Feature$/i
          if fc["features"].size > 0
            fc["features"][0]
          else
            { type: "Feature", properties: nil, geometry: nil  }
          end
        else
          fc
        end

      end

      private

      def coordinates e,include_altitude=nil
        coordinates = [longitude(e), latitude(e)]
        if [nil,nil] == coordinates
          coordinates = nil
        end
        if e.key?(alt_key) and !coordinates.nil? and include_altitude.nil?
          include_altitude = true
        end
        if e.key?(alt_key) and !coordinates.nil? and coordinates.size == 2 and true == include_altitude
          coordinates.push altitude(e)
        end
        coordinates
      end

      def defaults
        Icelastic::Default.geo_params
      end

      # Returns a hash of common items in two hashes
      def common_items(obj1, obj2)
        if obj1.nil? or obj2.nil?
          return {} # Typically happens when a filter selects 0 documents
        end
        obj1.select do |k,v|
          obj2.has_key?(k) && v == obj2[k]
        end
      end

      # Check if the object contains the geo fields
      def geo?(obj)
        obj[lat_key] and obj[lng_key]
      end

      # True if the geometry is set by the user
      def geometry?
        params.any?{|k, v| k =~ /^geometry$/}
      end

      def generate_points(items = entries)
        items.each_with_index.map do |e, i|
          #if geo?(e)
            {
              "type" => "Feature",
              "geometry" => geometry(e),
              "properties" => properties(e)
            }
          #end
        end
      end

      # Generate LineString or MultiPoint
      def generate_multi_feature(items = entries, type="LineString")

        if items.size < 1
          return []
        end

        if type =~ /linestring/i
          type = "LineString"
        elsif type =~ /MultiPoint/i
          type = "MultiPoint"
        else
          raise "Unsupported feature type: #{type}"
        end

        f = {
          "type" => "Feature",
          "geometry" => {
            "type" => type,
            "coordinates" => items.map{ |e| coordinates(e) }
          },
          "properties" => multi_properties(items)
        }

        # Add column arrays to properties (default is * ie. columnize everything except coordinates)
        column_keys = (params["array"]||"*").split(",")

        # Support &array=* to generate column arrays on all fields except filtered fields
        if column_keys.include? "*"
          non_string_keys = items.map {|e|
            ( e.keys - [lng_key,lat_key,alt_key]).reject do |k|
              if params["filter-#{k}"] and params["filter-#{k}"] !~ /(\.{2}|\|{1}|\,{1})/
                true # reject simple filtered variables (no a..b ranges)
              else
                false # don't reject
              end
            end
          }
          column_keys = non_string_keys.flatten.uniq.sort
        end

        column_keys.uniq.each do |k|
          f["properties"][k] = items.map {|e| e[k] }
        end

        [f]
      end

      def multi_properties items
        global_properties(items)
      end

      def global_properties(items)
        common_items(items.first, items.last)
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

      def lng_key
        if params.key? "coordinates" and params["coordinates"].split(",").size > 0
          lng = params["coordinates"].split(",")[0]
        else
          defaults["longitude"]
        end
      end

      def lat_key
        if params.key? "coordinates" and params["coordinates"].split(",").size > 1
          params["coordinates"].split(",")[1]
        else
          defaults["latitude"]
        end
      end

      def alt_key
        if params.key? "coordinates" and params["coordinates"].split(",").size > 2
          params["coordinates"].split(",")[2]
        else
          defaults["altitude"]
        end
      end

      def feature? test
        test.key? "type" and test["type"] == "Feature" and test.key? "geometry" and (test["geometry"].key?("coordinates") || test["geometry"].key?("geometries"))
      end

      # Extract longitude from the object
      def longitude(obj)
        stats ? obj[lng_key]["avg"] : obj[lng_key]
      end

      # Extract latitude from the object
      def latitude(obj)
        stats ? obj[lat_key]["avg"] : obj[lat_key]
      end

      def altitude(obj)
        stats ? obj[alt_key]["avg"] : obj[alt_key]
      end

      # Return which mode to use
      def mode
        geometry? ? params["geometry"] : defaults["geometry"]
      end

      # Trigger the correct generator depending on the mode
      def features
        if entries.size > 0 and feature?(entries[0])
          entries # ie. Don't touch entries that are already GeoJSON features
        else case mode
          when /LineString/i then stats ? generate_multi_feature(stats, "LineString") : generate_multi_feature(entries, "LineString")
          when /MultiPoint/i then stats ? generate_multi_feature(stats, "MultiPoint") : generate_multi_feature(entries, "MultiPoint")
          #when /ContextLine/i then stats ? generate_contextline(stats) : generate_contextline
          else stats ? generate_points(stats) : generate_points
          end
        end
      end

      def properties e
        if params["properties"] == "null"
          nil
        else
          [lng_key,lat_key,alt_key].each {|c|
            e.delete c
          }
          properties = e.reject {|k,v| k =~ /^filter/ }
          if {} == properties
            nil
          else
            properties
          end
        end
      end

      def geometry e
        if params["geometry"] == "null"
          nil
        else
          {
            "type" => "Point",
            "coordinates" => coordinates(e)
          }
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
