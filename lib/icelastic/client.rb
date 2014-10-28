module Icelastic

  # The client is a wrapper around the elasticsearch-ruby client library.
  # It acts as an interface between the middlware and the query,result objects.
  #
  # [Functionality]
  #   This library provides CRUD behavior for elasticsearch using the custom
  #   query and response objects defined in this library
  #
  # [Authors]
  #   - Ruben Dens
  #
  # @see https://github.com/elasticsearch/elasticsearch-ruby Elasticsearch-Ruby on github

  class Client

    attr_accessor :client, :url, :search_index, :type, :log, :env, :response

    def initialize(config={})
      self.url = config[:url] if config.has_key?(:url)
      self.search_index = config[:index] if config.has_key?(:index)
      self.type = config[:type] if config.has_key?(:type)
      self.log = config.has_key?(:log) ? config[:log] : false
      self.client = url.nil? ? Elasticsearch::Client.new(:log => log) : Elasticsearch::Client.new(:url => url, :log => log)
      self.writers = config[:writers] ||= Default.writers
      Default.params = hash_key_to_s(config[:params]) if config.has_key?(:params) && !config[:params].nil?
      Default.geo_params = hash_key_to_s(config[:geojson]) if config.has_key?(:geojson) && !config[:geojson].nil?
    end

    # Execute a search and return the appropriate response
    
    def search(request)
      self.env = request.env
      self.response = client.search({:body => query, :index => search_index, :type => type})
      
      result = case request_params['format']
        when "raw" then response
        when "json","",nil then  write("json", "elasticsearch")
        else write(request_params['format'], "feed")
      end
      if result.is_a? Hash or result.is_a? Array
        result.to_json
      else
        result
      end
      
    end
    
    def writer(format)
      w = @writers.select {|w| w["format"] == format.to_s}
      if w.none?
        raise "No writer for format: #{format}, available writers: #{@writers.to_json}"
      end
      w.first
    end
    
    def writers=(writers)
      @writers = writers
    end
    
    private

    # Grab the document count for the index
    def count
      r = client.count :index => search_index, :type => type
      r['count']
    end

    # Write JSON feed
    def feed
      write("json", "elasticsearch")
    end

    # Call the response writer
    def write(format, from)
      writer = writer(format)["writer"]
      from = (from == "feed") ? feed : response
      if writer.respond_to? :call
        writer.call(from)
      else
        writer.new(Rack::Request.new(generate_env), from).build
      end
    end

    # Write GeoJSON
    def geojson
      write("geojson", "feed")
    end

    # Generate a new environement. Needed to merge in the new limit param when limit=all is called
    def generate_env
      self.env = env.merge({"QUERY_STRING" => request_params.map{|k,v| "#{k}=#{v}"}.join('&')})
    end

    # Casts hash keys to String
    def hash_key_to_s(hash)
      hash.inject({}){|memo,(k,v)| memo[k.to_s] = v; memo}
    end

    # Set the limit to the document count
    def limit_all
      {"limit" => count}
    end

    def query
      Icelastic::Query.new(Icelastic::Default.params.merge(request_params)).build
    end

    def result

    end

    def request_params
      p = Rack::Request.new(env).params
      p["limit"] == "all" ? p.merge(limit_all) : p
    end

  end
end
