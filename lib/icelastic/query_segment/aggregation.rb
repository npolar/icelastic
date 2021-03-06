require_relative "aggregations/range"

module Icelastic
  module QuerySegment

    # Support for aggregations introduced in elasicsearch 1.*
    # Since aggregations offer the same functionality as facets
    # and support more powerfull features this class will
    # replace regular facets.

    class Aggregation

      TERM_REGEX = /facets/i
      LABELED_REGEX = /^(?:facet-)(.+)$/i
      DATE_REGEX = /^date-(.+)$/i
      STAT_VAL_REGEX = /^(.+)\[(.+)\]$/
      SIZE_REGEX = /^size-(?:facet)$/i

      attr_accessor :params

      def initialize( params = {} )
        self.params = Icelastic::Default.params.merge(params)
        @range = Icelastic::QuerySegment::RangeAggregation.new
      end

      def build
        if enabled?
          aggs = {"aggregations" => {}}
          aggs["aggregations"].merge!(term_aggregations)  if extract_params(TERM_REGEX)
          aggs["aggregations"].merge!(labeled_aggregations) if extract_params(LABELED_REGEX)
          aggs["aggregations"].merge!(date_aggregations) if extract_params(DATE_REGEX)
          aggs["aggregations"].merge!(@range.build_aggregations(params, aggregation_size))
          aggs
        end
      end

      private

      def aggregation_size
        if params.key? "facet.limit"
          params["facet.limit"].to_i
        else
         extract_params(SIZE_REGEX).values.first.to_i  if extract_params(SIZE_REGEX).any?
        end
      end

      def enabled?
        extract_params(TERM_REGEX).any? && extract_params(TERM_REGEX).values.include?("false") ? false : true
      end

      def extract_argument(string, regex)
        $1 if string =~ regex
      end

      def extract_params(regex)
        params.select{|k,v| k =~ regex}
      end

      def term_aggregations
        aggregations = {}
        extract_params(TERM_REGEX).each do |k,v|
          v.split(",").each do |e|
            aggregations.merge!( {e => {"terms" => {"field" => e, "size" => aggregation_size}}} )
          end
        end

        aggregations
      end

      def labeled_aggregations
        aggregations = {}
        extract_params(LABELED_REGEX).each do |k,v|
          aggregations.merge!({
            extract_argument(k, LABELED_REGEX) => {
              "terms" => {"field" => v, "size" => aggregation_size}
            }
          })
        end

        aggregations
      end

      def date_aggregations
        aggregations = {}
        extract_params(DATE_REGEX).each do |k,v|
          interval = extract_argument(k, DATE_REGEX)
          format = get_format(interval)

          v.split(",").each do |e|
            bucket = e

            if e =~ STAT_VAL_REGEX
              aggs = {}
              bucket = $1
              $2.split(":").each do |field|
                aggs.merge!({ field => {"extended_stats" => {"field" => field}}})
              end
            end

            label = "#{interval}-#{bucket}"

            aggregation = {
              label => {
                "date_histogram" => {"field" => bucket, "interval" => interval, "format" => format}
              }
            }

            aggregation[label]["aggs"] = aggs if aggs && aggs.any?

            aggregations.merge!(aggregation)
          end
        end

        aggregations
      end

      def get_format(interval)
        format = case interval
        when "day" then "yyyy-MM-dd"
        when "month" then "yyyy-MM"
        when "year" then "yyyy"
        else "yyyy-MM-dd'T'HH:mm:ss'Z'"
        end
      end

    end

  end

end
