module Icelastic

  # This class is used to build elasticsearch queries from url parameters
  #
  # [Authors]
  #   - Ruben Dens
  #
  # @example Basic Usage
  #   query = Icelastic::Query.new( params )
  #   query.build

  class Query

    def initialize(params = nil)
      self.params = params if params
    end
    
    def bool?
      if multiword? and (params.key? "q" and params["q"] =~ /.*(AND|OR).*/)
        true
      else
        false
      end
    end
    
    def geo?
      bbox = Default.geo_params["bbox"]
      params.key? bbox and (3..5).include? params[bbox].count(",")
    end
    
    
    def phrase?
      if bool?
        false
      elsif multiword? and (params.key? "q" and params["q"] =~ /\".*\"/)
        true
      else
        false
      end
    end
    
    def multiword?
      if params.key? "q" and params["q"] =~ /.*\s.*/
        true
      else
        false
      end
    end

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
      query.merge!(paging)
      query.merge!(highlight) if highlight?
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
      all_query = {
        :query_string => {
          :default_field => :_all,
          :query => query_value
        }
      }
      
      if bool?
        all_query
      elsif phrase?
        phrase_query
      elsif multiword?
        # Turn multiword query into a phrase query (except when ?op=OR)
        operator = "AND"
        if params.key? "op" and params["op"] =~ /OR/i
          operator = "OR"
        else
          params["op"] = "AND"
        end
        params["q"] = "\"#{params["q"]}\""
        phrase_query
      else
        all_query
      end
      
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
    # @see http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl-query-filter.html Elasticsearch: Query filters
    # @see http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl-and-filter.html Elasticsearch: And filters
    def filter
      filter = {}
      if filter_params.any?
        filter = Icelastic::QuerySegment::Filter.new(params).build
      end
      if geo?
        filter.merge! Icelastic::QuerySegment::Geo.new(params).build
      end
      filter
    end

    # Builds a facets segment
    # @see http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/search-facets.html Elasticsearch: facets
    def facets
      Icelastic::QuerySegment::Aggregation.new(params).build
    end

    # Build paging info
    def paging
      Icelastic::QuerySegment::Paging.new(params).build
    end

    def highlight?
      params.select{|k,v| k == "highlight" && v == "true"}.any?
    end

    # Build highlighter segment
    def highlight
      highlighter_defaults
    end
    
    # @todo FIXME 
    # https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-match-query.html
    # def phrase_query
    #  { :match =>
    #    { :message => {
    #        :query => params["q"],
    #        :type => "phrase"
    #      }
    #    }
    #  }
    # end
    
    # "this is a phrase" (multiple words inside quotes)
    def phrase_query(operator="AND")
      before,between = params["q"].split('"').map {|s| clean(s) }
      between,after = between.split('"').map {|s| clean(s) }
      if between =~ /\s/
        words = between.split(/\s/)
        idx = 0
        between = words.map {|b|
          idx = idx+1
          b = "(#{b} OR #{b}*)"
          if idx < words.length-1
            b += " AND"    
          end
          b 
        }.join(" ")
      end
      {
        :query_string => {
          :default_field => :_all,
          :query => "#{before} #{between} #{after}".gsub(/^\s+/, "").gsub(/\s+$/, "")
        }
      }
    end
    
    private

    # Clean the query value
    def query_value
      q = params.select{|k,v| k =~ /^q(-(.+)?)?$/}
      q = !q.nil? && q.any? ? clean(q.values[0]) : ""
      q == "" ? "*" : handle_search_pattern(q)
    end
    
    def clean(s)
      s.strip.squeeze(" ").gsub(/(\&|\||\!|\(|\)|\{|\}|\[|\]|\^|\~|\:|\!|\')/, "")
    end

    # Detect query pattern and return an explicit (quoted search) or a simple fuzzy query
    def handle_search_pattern(q)
      if multiword?
        q = q.split(/\s/).map {|s| "#{s} #{s}*" }.join("")
        p q
        q
      else
        "#{q} OR #{q}*"
      end
      
      
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

    # Returns true if there are filter-x or geo parameters (currently only bbox=)
    def filters?
      filter_params.any? or geo?
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
