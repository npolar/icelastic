module Icelastic
  module QuerySegment

    # Support for "bucket-histogram-aggregation"
    # http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/search-aggregations-bucket-histogram-aggregation.html
    class RangeAggregation

      REGEX = /^rangefacet-(.+)/i

      def build_aggregations(params)
        aggregations = {}
        extract_params(params).each do |k,v|
          value = v.to_i
          next if invalid_interval(value)
          k.scan(REGEX) do
            field = $1

              aggregations.merge!({
                "#{field}" => {
                  "terms" => {
                    "field" => field,
                    "script" => "range",
                    "params" => {
                      "interval" => value
                    },
                    "lang" => "groovy",
                    "order" => { "_term" => "asc" }
                  }
                }
              })

          end
        end
        aggregations
      end

      private

      def invalid_interval(value)
        value <= 0
      end

      def extract_params(params)
        params.select{|k,v| k =~ REGEX}
      end

    end
  end
end
