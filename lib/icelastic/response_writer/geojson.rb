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
    # @see http://www.opensearch.org/Specifications/OpenSearch/1.1/Draft_5 Opensearch-1.1 Draft 5

    class GeoJSON

      attr_accessor :feed, :stats, :entries, :params

      def initialize(request, feed)
        self.params = request.params
        self.entries = feed["feed"]["entries"]
        self.stats = feed["feed"]["stats"]
        self.feed = feed["feed"].delete_if{|k| ["entries", "facets", "stats"].include?(k) }
      end

      def build
        {
          "feed" => feed,
          "type" => "FeatureCollection",
          "features" => select_mode
        }.to_json
      end

      private

      def geometry?
        params.select{|k, v| k =~ /^geometry$/}.any?
      end

      # Select the geometry mode
      def select_mode
        if geometry?
          case params["geometry"]
          when /LineString/i then stats ? generate_linestring(stats) : generate_linestring
          when /MultiPoint/i then stats ? generate_multi_point(stats) : generate_multi_point
          #when /ContextLine/i then stats ? generate_contextline(stats) : generate_contextline
          else stats ? generate_points(stats) : generate_points
          end
        else
          stats ? generate_points(stats) : generate_points
        end
      end

      def generate_linestring(items = entries)
        [
          {
            "type" => "Feature",
            "geometry" => {
              "type" => "LineString",
              "coordinates" => items.map{|e| [longitude(e), latitude(e)] if geo?(e)} #.uniq #DANGER UNIQ DESTROYS THE ORIGINAL DATA (ONLY USED TO DIFF BETWEEN DUPS)
            },
            "properties" => {
              "start_latitude" => latitude(items.first),
              "start_longitude" => longitude(items.first),
              "stop_latitude" => latitude(items.last),
              "stop_longitde" => longitude(items.last)
            }
          }
        ]
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

      def generate_multi_point(items = entries)
        [
          {
            "type" => "Feature",
            "geometry" => {
              "type" => "MultiPoint",
              "coordinates" => items.map{|e| [longitude(e), latitude(e)] if geo?(e)}
            },
            "properties" => common_items(items.first, items.last)
          }
        ]
      end

      def geo?(obj)
        obj["latitude"] && obj["longitude"]
      end

      # Extract latitude from the object
      def latitude(obj)
        stats ? obj["latitude"]["avg"] : obj["latitude"]
      end

      # Extract longitude from the object
      def longitude(obj)
        stats ? obj["longitude"]["avg"] : obj["longitude"]
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

      # Returns a hash of common items in two hashes
      def common_items(obj1, obj2)
        obj1.select do |k,v|
          obj2.has_key?(k) && v == obj2[k]
        end
      end

    end
  end
end
