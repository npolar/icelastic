module Icelastic

  # This class is used to build elasticsearch queries from url parameters
  #
  # [Usage]
  # query = Icelastic::Query.new( params )
  # query.build
  #
  # [Authors]
  #   - Ruben Dens

  class Query

    # Get request parameters
    def params
      @params ||= {"q" => "*"}
    end

    # Set request parameters
    def params=(parameters = nil)
      @params = {}
      case parameters
      when Hash then @params = parameters
      when String then CGI.parse( parameters ).each{ |k, v| @params[k] = v.join(',') }
      else raise ArgumentError, "params not a Hash or String" # Raise error or set default?
      end
    end

    # Builder combining all the segments
    # into a full query body.
    def build
      query = {}
      query.merge!(start)
      query.merge!(limit)
      query.merge!(sort)
      query.merge!(fields) unless fields.nil?
      query.merge!(highlight)
      query.merge!(query_block)
      query.merge!(facets) unless facets.nil?

      query.to_json
    end

    # Builds the top lvl query block
    def query_block
      filters? ? {:query => filtered_query} : {:query => query_string}
    end

    # Build a filtered query
    # @see http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl-filtered-query.html Elasticsearch: Filtered queries
    def filtered_query
      {:filtered => {:query => query_string, :filter => filter}}
    end

    # Routing method that calls the appropriate query segment builder
    # @see #global_query
    # @see #field_query
    # @see http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl-query-string-query.html#query-dsl-query-string-query Elasticsearch: Query string query
    def query_string
      params.any?{|k,v| k =~ /^q-(.+)$/} ? field_query : global_query
    end

    # Build a query against all fields
    def global_query
      {
        :query_string => {
          :default_field => :_all,
          :query => query_value
        }
      }
    end

    # Build query against one || more fields
    # @see #default_field
    # @note these kind of queries only work on fields that are tokenized in the search engine
    def field_query
      fq = {:query_string => params.select{|k,v| k =~ /^q-(.+)/}}
      fq[:query_string].each do |k,v|
        fq[:query_string] = query_field( k.to_s.gsub(/^q-/, '') )
        fq[:query_string][:query] = query_value
      end
      fq
    end

    # Builds a filter segment
    # @see #parse_filter_values
    # @see http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl-query-filter.html Elasticsearch: Query filters
    # @see http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl-and-filter.html Elasticsearch: And filters
    def filter
      Icelastic::QueryBuilder::Filter.new(params).build
    end

    # Builds a facets segment
    # @see http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/search-facets.html Elasticsearch: facets
    def facets
      Icelastic::QueryBuilder::Aggregation.new(params).build
    end

    # Generate a sort segment
    # @see http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/search-request-sort.html Elasticsearch: Sort
    def sort
      sp = {}
      sort_params.each{|k,v| sp[:sort] = build_sort_segment(v)}
      sp
    end

    # Define start point for the result cursor
    def start
      start_param? ? {:from => start_param["start"].to_i} : {:from => 0}
    end

    # Define the item limit per result page
    def limit
      limit_param? ? {:size => limit_param["limit"].to_i} : {:size => 25}
    end

    # Define the fields that should be included in the response
    def fields
      {:fields => params["fields"].split(",").uniq} if params.has_key?("fields")
    end

    # Build highlighter segment
    def highlight
      highlighter_defaults
    end

    private

    # Clean the query value
    def query_value
      q = params.select{|k,v| k =~ /^q(-(.+)?)?$/}
      q = !q.nil? && q.any? ? q.values[0].strip.squeeze(" ").gsub(/(\&|\||\!|\(|\)|\{|\}|\[|\]|\^|\~|\:|\!)/, "") : ""
      q == "" ? "*" : handle_search_pattern(q)
    end

    # Detect query pattern and return an explicit (quoted search) or a simple fuzzy query
    def handle_search_pattern(q)
      q.match(/^\"(.+)\"$/) ? q.gsub(/\"/, "") : "#{q} #{q}*"
    end

    # Generates a default_field || fields syntax for the query string.
    # @see http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl-query-string-query.html#_default_field Elasticsearch: Default field
    def query_field(field_arg)
      multi_field?(field_arg) ? {:fields => field_arg.split(',')} : {:default_field => field_arg}
    end

    # Check if doing a multifield query?
    # @example
    #   ?q-title,summary=
    #   ?q-contact.*=
    # @see http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl-query-string-query.html#_multi_field_2 Elasticsearch: Multi field queries
    def multi_field?(field_arg)
      field_arg.split(',').size > 1 || field_arg.match(/^(.+)\.(\*)/)
    end

    # Returns all filter params
    def filter_params
      params.select{|k,v| k =~ /^filter-(.+)|^not-(.+)/}
    end

    # Returns true if there are filter parameters
    def filters?
      filter_params.any?
    end

    # Sort params
    def sort_params
      params.select{|k,v| k == "sort"}
    end

    # Determine the sort order from the value
    # @example
    #   sort=title # will sort  ascending
    #   sort=-title # will sort descending because of the "-" character in front of the field
    def sort_order(value)
      value =~ /-(.+)/ ? :desc : :asc
    end

    # Build a sort segment
    def build_sort_segment(value)
      value.split(',').map do |v|
        {v.gsub(/-(.+)/, '\1') => { :order => sort_order(v), :ignore_unmapped => true}}
      end
    end

    # Get the start parameter
    def start_param
      params.select{|k,v| k == "start"}
    end

    # Returns true if there is a start param
    def start_param?
      start_param.any?
    end

    # Get the limit parameter
    def limit_param
      params.select{|k,v| k == "limit"}
    end

    # Returns true if there is a limit param
    def limit_param?
      limit_param.any?
    end

    # Default highlighting configuration
    def highlighter_defaults
      {
        :highlight => {
          :fields => {
            :_all => {
              :pre_tags => ["<em><strong>"],
              :post_tags => ["</strong></em>"],
              :fragment_size => 50,
              :number_of_fragments => 3
            }
          }
        }
      }
    end

  end
end
