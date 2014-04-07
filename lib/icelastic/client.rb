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
      Icelastic::Default.params = Icelastic::Default.params.merge(hash_key_to_s(config[:params])) if config.has_key?(:params) && !config[:params].nil?
    end

    # Execute a search operation
    def search(request)
      self.env = request.env
      self.response = client.search({:body => query, :index => search_index, :type => type})
      result
    end

    private

    # Grab the document count for the index
    def count
      r = client.count :index => search_index, :type => type
      r['count']
    end

    # Generate CSV
    def csv
      Icelastic::ResponseWriter::Csv.new(Rack::Request.new(env), feed).build
    end

    # Call the feed response writer
    def feed
      Icelastic::ResponseWriter::Feed.new(Rack::Request.new(generate_env), response).build
    end

    # Call the Geojson response writer
    def geojson
      Icelastic::ResponseWriter::GeoJSON.new(Rack::Request.new(env), feed).build
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
      q = Icelastic::Query.new
      q.params = Icelastic::Default.params.merge(request_params)
      q.build
    end

    def result
      case request_params['format']
      when "raw" then response.to_json
      when "csv" then csv
      when "geojson" then geojson
      else feed.to_json
      end
    end

    def request_params
      p = Rack::Request.new(env).params
      p["limit"] == "all" ? p.merge(limit_all) : p
    end

  end
end
