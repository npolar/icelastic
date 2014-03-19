module Icelastic

  module QueryBuilder

    # Builds filters to be used in filtered queries

    class Filter

      attr_accessor :params

      FILTERS = /^(?:filter-|not-)(.+)$/i
      NOT_FILTER = /not-(\w+)$/i
      OR_FILTER = /^([^|]+\|)+([^|]+)$/i
      RANGE_FILTER = /^(\d+)\.\.(\d+)|\.\.(\d+)|(\d+)\.\.$/i
      DATE_REGEX = /^\d{4}\-(\d{2})?\-?(\d{2})?T?(\d{2}):?(\d{2})?:?(\d{2})?Z?/i

      def initialize(params)
        self.params = reduce_params(params, FILTERS)
      end

      def build
        filter = {:and => []}
        params.each do |k,v|
          v.split(",").map do |val|
            filter[:and] << (not_filter?(k) ? {:not => generate_filter(k, val)} : generate_filter(k, val))
          end
        end
        filter
      end

      private

      # Extract the field name from the parameter key
      def filter_field(key)
        key =~ FILTERS ? $1 : key
      end

      # Generates the appropriate filter structure based on the value syntax
      def generate_filter(key, value)
        return or_filter(key, value) if or_filter?(value)
        return range_filter(key, value) if range_filter?(value)
        term_segment(key, value)
      end

      # use the param key to detect if it is a not filter
      def not_filter?(key)
        key =~ NOT_FILTER
      end

      # Builds a term block
      def term_segment(key, value)
        {:term => {filter_field(key) => value}}
      end

      # Detect OR filter
      def or_filter?(value)
        value =~ OR_FILTER
      end

      # Build OR filter object
      # @see http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl-or-filter.html Elasticsearch: or filter
      def or_filter(key, value)
        {:or => value.split("|").map{|val| generate_filter(key, val)}}
      end

      # Detect range filter
      def range_filter?(value)
        value =~ RANGE_FILTER
      end

      # Build a ranged filter
      # @see http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl-range-filter.html Elasticsearch: range filter
      def range_filter(key, value)
        arg1, arg2 = value.split("..")

        return {:range => {filter_field(key) => {:gte => arg1}}} if arg2.nil?
        return {:range => {filter_field(key) => {:lte => arg2}}} if arg1.empty?

        arg1, arg2 = arg2, arg1 if arg1 > arg2

        {
          :range => {
            filter_field(key) => {:gte => arg1, :lte => arg2}
          }
        }
      end

      # Select a subset of parameters based on a key regex
      def reduce_params(params, key_regex)
        params.select{|k,v| k =~ key_regex}
      end

    end

  end

end
