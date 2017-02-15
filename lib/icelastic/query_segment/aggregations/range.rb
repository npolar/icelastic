module Icelastic
  module QuerySegment

    # Support for "bucket-histogram-aggregation"
    # http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/search-aggregations-bucket-histogram-aggregation.html
    class RangeAggregation

      REGEX = /^rangefacet-(?<field>.+)/i

      def build_aggregations(params, size)
        aggregations = {}
        valid_rangefacet_queries(params).each do |k,v|
          value = v.to_i
          k.match(REGEX) do |m|
            field = m[:field]

              aggregations.merge!({
                "#{field}" => {
                  "terms" => {
                    "field" => field,
                    "script" => "range",
                    "params" => {
                      "interval" => value
                    },
                    "lang" => "groovy",
                    "order" => { "_term" => "asc" },
                    "size" => size
                  }
                }
              })

          end
        end
        aggregations
      end

      private

      def valid_rangefacet_queries(params)
        params.select{|k,v| k =~ REGEX && v.to_i > 0}
      end

    end
  end
end
