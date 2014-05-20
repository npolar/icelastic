module Icelastic
  module QuerySegment

    # Write paging control.
    #
    # start
    # limit
    # sort
    # fields

    class Paging

      START_REGEX = /start/i
      LIMIT_REGEX = /limit/i
      SORT_REGEX = /sort/i
      FIELDS_REGEX = /fields/i

      attr_accessor :params

      def initialize(params)
        self.params = Icelastic::Default.params.merge(params)
      end

      def build
        page = {}
        page["from"] = start_term
        page["size"] = limit_term
        page["sort"] = sort_term if param?(SORT_REGEX)
        page["_source"] = source_filter(FIELDS_REGEX) if param?(FIELDS_REGEX)
        page
      end

      private

      def extract_params(regex)
        params.select{|k,v| k =~ regex}
      end

      def start_term
        params["start"].to_i if extract_params(START_REGEX).any?
      end

      def limit_term
        params["limit"].to_i if extract_params(LIMIT_REGEX).any?
      end

      def sort_term
        params["sort"].split(",").map do |v|
          order, term = v =~ /-(.+)/ ? ["desc", $1] : ["asc", v]
          {term => {"order" => order, "ignore_unmapped" => true, "mode" => "avg"}}
        end
      end

      def param?(regex)
        extract_params(regex).any?
      end

      # Return an array with the paramter values
      def source_filter(regex)
        extract_params(regex).map{|k,v| v.split(",") }.flatten
      end

    end
  end
end
