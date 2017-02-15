module Icelastic
  module QuerySegment
    class Geo

      attr_accessor :params
      
      def initialize(params)
        self.params = params
        @geo_shape_field = Default.geo_params["geo_shape_field"].to_s
        @bbox = Default.geo_params["bbox"].to_s
      end
      
      def build
        bbox(params[@bbox])
      end
      
      def bbox(bbox="-180,-90,180,90")
        bbox = bbox.to_s.split(",").map {|b| b.to_f}
        w,s,e,n = bbox
        { "geo_shape" => {
            @geo_shape_field => {
              "shape" => {
                "type" => "envelope",
                "coordinates" => [[w,s],[e,n]]
              }
            }
          }
        }
      end
      
    end
  end
end