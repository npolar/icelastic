module Icelastic
  module ResponseWriter
    class GeoJSON

      attr_accessor :feed, :stats, :entries, :params

      def initialize(request, response)
        self.params = request.params
        self.entries = response["feed"]["entries"]
        self.stats = response["feed"]["stats"]
        self.feed = response["feed"].delete_if{|k| ["entries", "facets", "stats"].include?(k) }
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
              "coordinates" => items.map{|e| [geo(e)["longitude"], geo(e)["latitude"]] if geo?(e)}.uniq #DANGER UNIQ DESTROYS THE ORIGINAL DATA (ONLY USED TO DIFF BETWEEN DUPS)
            },
            "properties" => {
              "start_latitude" => items.first["latitude"],
              "start_longitude" => items.first["longitude"],
              "stop_latitude" => items.last["latitude"],
              "stop_longitde" => items.last["longitude"]
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
                #:coordinates => [[geo(e)["longitude"], geo(e)["latitude"]], [geo(items[i+1])["longitude"], geo(items[i+1])["latitude"]]]
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
                "coordinates" => [geo(e)["longitude"], geo(e)["latitude"]]
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
              "coordinates" => items.map{|e| [geo(e)["longitude"], geo(e)["latitude"]] if geo?(e)}
            },
            "properties" => common_items(items.first, items.last)
          }
        ]
      end

      def geo?(obj)
        obj["latitude"] && obj["longitude"]
      end

      def geo(obj)
        {
          "latitude" => stats ? obj["latitude"]["avg"] : obj["latitude"],
          "longitude" => stats ? obj["longitude"]["avg"] : obj["longitude"]
        }
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

      def common_items(obj1, obj2)
        obj1.select do |k,v|
          obj2.has_key?(k) && v == obj2[k]
        end
      end

    end
  end
end
