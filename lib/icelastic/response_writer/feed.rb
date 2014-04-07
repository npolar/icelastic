module Icelastic
  module ResponseWriter
    class Feed

      attr_accessor :params, :env, :body_hash, :aggregations

      def initialize(request, body_hash)
        self.env = request.env
        self.params = request_params(request)
        self.body_hash = body_hash
      end

      # construct the feed response
      def build
        response = {"feed" => {}.merge!(opensearch)}
        response["feed"].merge!(list)
        response["feed"].merge!(search)
        response["feed"].merge!(facets)
        response["feed"].merge!(stats)
        response["feed"].merge!(entries)
        response
      end

      def opensearch
        {
          "opensearch" => {
            "totalResults" => total_results,
            "itemsPerPage" => limit,
            "startIndex" => start
          }
        }
      end

      def list
        {
          "list" => {
            "self" => self_uri,
            "first" => start,
            "last" => last,
            "next" => next_uri,
            "previous" => previous_uri
          }
        }
      end

      def search
        {
          "search" => {
            "qtime" => qtime,
            "q" => query_term
          }
        }
      end

      def facets
        {"facets" => facets? ? generate_facets : nil}
      end

      def stats
        {"stats" => aggregation? ? format_aggregations : nil}
      end

      def entries
        {"entries" => aggregation? ? nil : format_hits}
      end

      private

      def extract_aggregations
        self.aggregations = params.select{|k,v| v=~ /^(.+)\[(.+)\]$/i}
      end

      def aggregation?
        extract_aggregations.any?
      end

      # Construct the uri base from the request environment
      def base
        "#{env['rack.url_scheme']}://#{env['HTTP_HOST']}#{env['REQUEST_PATH']}"
      end

      def facets?
        params.keys.any?{|key| key.match(/^facets|facet-(.+)|date-(.+)$/i)} && (params["facets"] != "false")
      end

      def format_aggregations
        a = []
        aggregations.each do |k,v|
          interval = $1 if k =~ /^date-(.+)$/
          field = $1 if v =~ /^(.+)\[(.+)\]$/
          body_hash['aggregations']["#{interval}-#{field}"]['buckets'].each do |e|

            if e["key_as_string"]
              e["#{field}"] = e.delete("key_as_string")
              e.delete("key")
            else
              e["key"]
            end

            e["filter"] = "#{interval}-#{field}"
            a << e
          end
        end
        a
      end

      # Construct an entry object from the raw elastic result
      def format_hits
        body_hash['hits']['hits'].map{|e|
          if e['highlight']
            hl = {"highlight" => e['highlight']['_all'].join("... ")}
            e['_source'].merge(hl)
          else
            e['_source']
          end
        }
      end

      def generate_facets
        body_hash["aggregations"].map{|facet , obj| {facet => parse_buckets(facet, obj["buckets"])}}
      end

      def parse_buckets(facet, buckets)
        buckets.map do |term|
          {
            "term" => facet_term(term),
            "count" => term["doc_count"],
            "uri" => build_facet_uri(facet, facet_term(term))
          }
        end
      end

      # Extract the facet term.
      def facet_term(term)
        term.has_key?("key_as_string") ? term["key_as_string"] : term["key"]
      end

      # Builds a facet uri using the query builder
      # @see #build_facet_query
      def build_facet_uri(field,term)
        "#{base}?#{build_facet_query(field, term)}"
      end

      # Builds a facet query.
      # @see #facet_query
      def build_facet_query(field, term)
        if field =~ /^(year|month|day|hour)-(.+)/i
          "#{facet_query($2, time_range($1, term))}" # Handle date facets
        else
          f = params.has_key?("facet-#{field}") ? params["facet-#{field}"] : field # Handle named facets
          "#{facet_query(f, term)}"
        end
      end

      # Returns a query string based on the facet contents and request environment
      def facet_query(field, term)
        k = "filter-#{field}"
        params.has_key?(k) ? process_params(k, term) : "#{env['QUERY_STRING'].gsub(/\s/, "+")}&filter-#{field}=#{term.to_s.gsub(/\s/, "+")}"
      end

      # Use the current parameter hash to construct a new query string.
      # This is done to prevent duplications in the query output
      def process_params(key, term)
        params = request_params(Rack::Request.new(env))

        # check if the filter already exists with this term
        if params[key].match(/#{term}/)
          vals = params[key].split(",").delete_if{|e| e == term}
          vals.any? ? params[key] = vals.join(",") : params.delete(key)
        else
          params[key] += ",#{term}"
        end

        query_from_params(params)
      end

      # Generate iso8601 ranges for the facet filter
      def time_range(interval, term)
        date = fix_date(interval, term)
        start = DateTime.parse(date).to_time.utc.iso8601
        stop = DateTime.parse(date)

        stop = case interval
        when "hour" then (stop.to_time + 3600).utc.iso8601
        when "day" then stop.next_day.to_time.utc.iso8601
        when "month" then stop.next_month.to_time.utc.iso8601
        when "year" then stop.next_year.to_time.utc.iso8601
        end

        "#{start}..#{stop}"
      end

      # Generate a parsable date string
      def fix_date(interval, date)
        case interval
        when "month" then "#{date}-01"
        when "year" then "#{date}-01-01"
        else date
        end
      end

      # Return the start index of the current page
      def start
        params['start'].to_i if params.has_key?('start')
      end

      # The start param is the same as the first item on the page
      alias :first :start

      # Return the item limit.
      def limit
        params['limit'].to_i if params.has_key?('limit')
      end

      # Returns the index of the last item on the result page
      def last
        limit > total_results ? total_results : (start + limit - 1)
      end

      # Return the total number of results yielded by the query
      def total_results
        body_hash["hits"]["total"]
      end

      # Extract the parameters from the request and merge them with the defaults
      def request_params(request)
        p = request.params["limit"] == "all" ? request.params.merge({"limit" => total_results}) : request.params
        Icelastic::Default.params.merge(p)
      end

      # Returns the uri for the current request
      def self_uri
        "#{base}?#{query_from_params}"
      end

      # Build the uri for the next page
      def next_uri
        total_results <= ((start + limit) || limit) ? false : page_uri(start + limit)
      end

      # Build the uri for the previous page
      def previous_uri
        return false if start == 0
        start - limit >= 0 ? page_uri(start - limit) : page_uri(0)
      end

      # Construct a page uri with the specified start index
      def page_uri(start)
        p = params.merge({"start" => start})
        "#{base}?#{query_from_params(p)}"
      end

      def qtime
        body_hash["took"]
      end

      def query_term
        params.each{|k,v| return v if k =~ /^q(-.+)?/}
      end

      # Returns a query string build from a parameter hash.
      def query_from_params(p = params)
        p = p.reject{|k, v| Icelastic::Default.params[k] == v if Icelastic::Default.params[k]}
        p.map{|k,v| "#{k}=#{v.to_s.gsub(/\s/, "+")}"}.join('&')
      end

    end
  end
end
