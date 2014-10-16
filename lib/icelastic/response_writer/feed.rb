module Icelastic
  module ResponseWriter

    # Constructs a custom json feed response that borrows some
    # elements from the Opensearch standard.
    #
    # [Authors]
    #   - Ruben Dens
    #
    # @example Basic usage
    #   feed = Icelastic::ResponseWriter::Feed.new(request, response)
    #   feed = feed.build # build a feed hash
    #   feed.to_json
    #
    # @see http://www.opensearch.org/Specifications/OpenSearch/1.1/Draft_5 Opensearch-1.1 Draft 5

    class Feed

      attr_accessor :params, :env, :body_hash, :aggregations

      RANGE_REGEX = Icelastic::QuerySegment::RangeAggregation::REGEX

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
            "q" => query_term,
            "max_score" => max_score
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
        params.keys.any? do |key|
          key.match(/^facets|facet-(.+)|date-(.+)|rangefacet-(.+)$/i) &&
          (params["facets"] != "false")
        end
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
          hit = e['_source']
          if e['highlight']
            hl = {"highlight" => e['highlight']['_all'].join("... ")}
            hit.merge!(hl)
          end
          hit["_score"] = e["_score"]
          hit
        }
      end

      def generate_facets
        body_hash["aggregations"].map{|facet , obj| {facet => parse_buckets(facet, obj["buckets"])}}
      end

      def parse_buckets(facet, buckets)
        buckets.map do |bucket|
          term = facet_term(bucket)
          {
            "term" => format_term(facet, term),
            "count" => bucket["doc_count"],
            "uri" => build_facet_uri(facet, term)
          }
        end
      end

      def format_term(field, term)
        if params.has_key?("rangefacet-#{field}")
          step_range(params["rangefacet-#{field}"].to_i, term)
        else
      	   term
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
        elsif params.has_key?("rangefacet-#{field}")
          "#{facet_query(field, step_range(params["rangefacet-#{field}"].to_i, term))}"
        else
          f = params.has_key?("facet-#{field}") ? params["facet-#{field}"] : field # Handle named facets
          "#{facet_query(f, term)}"
        end
      end

      # Returns a query string based on the facet contents and request environment
      def facet_query(field, term)
        k = "filter-#{field}"
        params.has_key?(k) ? process_params(k, term) : add_param(k, term)
      end

      # Add a new parameter to the hash
      def add_param(key, term)
        p = request_params
        p.delete("start") # remove any start offset and return to default
        p.merge!({key => term})

        query_from_params(p)
      end

      # Merge or remove the term if the key is already in the paramter hash
      def process_params(key, term)
        p = request_params
        p.delete("start") # remove the start key when switching on a facet

        # check if the filter already exists with this term
        if p[key].match(/#{term}/)
          vals = p[key].split(",").delete_if{|e| e == term}
          vals.any? ? p[key] = vals.join(",") : p.delete(key)
        else
          p[key] += ",#{term}"
        end

        query_from_params(p)
      end

      # Generate iso8601 ranges for the facet filter
      def time_range(interval, term)
        date = fix_date(interval, term)

        start = DateTime.parse(date).to_time.utc.iso8601
        stop = next_time(DateTime.parse(date), interval)

        "#{start}..#{stop}"
      end

      def step_range(step, start)
        "#{start}..#{start + step}"
      end

      # calculate the next time based of a start and interval
      def next_time(start_date, interval)
        t = case interval
        when "hour" then (start_date.to_time + 3600)
        when "day" then start_date.next_day.to_time
        when "month" then start_date.next_month.to_time
        when "year" then start_date.next_year.to_time
        end

        t.utc.iso8601
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
      def request_params(request = Rack::Request.new(env))
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

      def max_score
        body_hash["hits"]["max_score"]
      end

      # Returns a query string build from a parameter hash.
      def query_from_params(p = params)
        p = p.reject{|k, v| Icelastic::Default.params[k] == v if Icelastic::Default.params[k]}
        query_string = p.map do |k, v|
          if v.respond_to?(:reduce) # value is a hash
            v.reduce(k) {|memo, obj| memo+"["+obj[0]+"]="+obj[1].to_s.gsub(/\s/, "+")}
          else
            "#{k}=#{v.to_s.gsub(/\s/, "+")}"
          end
        end
        query_string.join("&")
      end

    end
  end
end
