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
      def build(&block)
        
        if params["variant"] == "array"
          return entries
        elsif params["variant"] == "hal"
          return hal
        end
        
        response = {"feed" =>
          { "opensearch" => opensearch,
          "search" => search }
        }
        if params["variant"] =~ /^(list|legacy|)$/
          response["feed"]["list"] = list_links
        else
          response["feed"]["links"] = links
        end

        response["feed"]["stats"] = stats
        response["feed"]["entries"] = entries
        response["feed"]["facets"] = facets        
        
        # This works, but then format=json&variant=geojson might differ from format=geojson
        #if params["variant"] == "geojson"
        #  return Icelastic::ResponseWriter::GeoJSON.new(Rack::Request.new(env), response).build
        #end
        
        #if not key.nil? and response.key? key.to_s
        #  response = response[key.to_s]
        #end
        
        if block_given?
          yield(self)
        else
          response
        end
      end
      
      def opensearch
        {
          "totalResults" => total_results,
          "itemsPerPage" => limit,
          "startIndex" => start
        }
      end

      def links
        relations.map {|rel|
          { "rel" => rel, "href" => href(rel) }
        }
      end
      
      def hal
        hal  = { "_links" => hal_links,
          "_embedded" => entries
        }
        
        hal["_embedded"].each do |e|
          e["_links"] = e["links"]||[].map {|l| { l["rel"] => { "href" => l["href"] } } }
          e.delete "links"
        end
        hal
        
      end
      
      def hal_links
        _links = {}
        relations.each {|rel|
          _links[rel] = { "href" => href(rel) }
        }
        _links
      end
      
      def list_links
        _links = {}
        relations.each {|rel|
          _links[rel] = href(rel)
        }
        _links
      end
    
      def href(rel)
        case rel
          when "self" then self_uri
          when "next" then next_uri
          when "first" then first_uri
          when "last" then last_uri
          when "previous" then previous_uri
          else raise "Unknown link relation: #{rel}"
        end
      end
      
      def relations
        ["self", "first", "previous", "next", "last"]
      end

      def search
        search = {
            "qtime" => qtime,
            "q" => query_term
        }
        if (params.has_key?("score"))
          search["max_score"] = max_score
        end
        search
      end

      def stats
        if not aggregation?
          return nil
        end
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

      # @return [Array<Hash>] Array of entry objects corresponding to the source document
      def entries
        body_hash['hits']['hits'].map{|e|
          hit = e['_source']
          if e['highlight']
            hl = {"highlight" => e['highlight']['_all'].join("... ")}
            hit.merge!(hl)
          end
          if params.has_key?("score")
            hit["_score"] = e["_score"]
          end
          hit
        }
      end

      # Construct the uri base from the request environment
      # @return [String]
      def base
        "#{env['rack.url_scheme']}://#{env['HTTP_HOST']}#{env['REQUEST_PATH']}"
      end

      # @return [true|false] Facet query?
      def facets?
        params.keys.any? do |key|
          key.match(/^facets|facet-(.+)|date-(.+)|rangefacet-(.+)$/i) &&
          (params["facets"] != "false")
        end
      end

      # Facet hash
      # @todo https://github.com/npolar/icelastic/issues/11
      def facets
        if false == facets?
          return []
        end
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
      alias :start_index :start
      
      # Return the item limit.
      def limit
        params['limit'].to_i if params.has_key?('limit')
      end
      alias :items_per_page :limit
      

      # Returns the index of the last item on the result page
      def lastextract_aggregations
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
        total_results <= ((start + limit) || limit) ? false : uri_with_default_parameters(start+limit)
      end
      
      def first_uri
        uri_with_default_parameters(0)
      end
      
      def last_uri
        if limit.to_i == 0
          return first_uri
        end
        last = limit*(total_results/limit).ceil
        uri_with_default_parameters(last)
      end

      # Build the uri for the previous page
      def previous_uri
        return false if start == 0
        start - limit >= 0 ? uri_with_default_parameters(start - limit) : first_uri
      end

      # Construct a page uri with the specified start index
      def page_uri(start)
        p = params.merge({"start" => start})
        "#{base}?#{query_from_params(p, true)}"
      end
      
      def uri_with_default_parameters(offset=0)
        p = params.merge({"start" => offset})
        "#{base}?#{query_from_params(p, false)}"
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
      
      
      protected
      
      def extract_aggregations
        self.aggregations = params.select{|k,v| v=~ /^(.+)\[(.+)\]$/i}
      end

      def aggregation?
        extract_aggregations.any?
      end
      alias :stats? :aggregation?

      # Returns a query string build from a parameter hash
      # 
      def query_from_params(p = params, reject_default=true)
        if true === reject_default
          p = p.reject{|k, v| Icelastic::Default.params[k] == v if Icelastic::Default.params[k]}
        end
        
        
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