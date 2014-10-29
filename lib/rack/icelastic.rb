module Rack

  # Middlware allowing easy integration of Icelastic
  # into the your Ruby and Rails applications
  #
  # [Authors]
  #   - Ruben Dens

  class Icelastic

    attr_accessor :env, :params

    def initialize(app=nil, options={})
      if app.nil?
        app = lambda{|env| [200, {"Content-Type" => "application/json"}, [{"error" => "404 Not Found"}.to_json]]}
      end
      if not options.key? :writers
        options[:writers] = ::Icelastic::Default.writers
      end
      
      @app, @config = app, options
    end
    
    def call(env)
      
      @env = env
      @params = CGI.parse(env['QUERY_STRING'])
      
      if not search?
        return @app.call(env)
      end
      
      body = client.search(request)
      # @todo How do you get the real HTTP status from elasticsearch-ruby?
      [200, {"Content-Type" => "#{type}; charset=utf-8"}, [body]] 
    end

    protected

    def request
      Rack::Request.new(env)
    end
    
    def type
      format =~ /^(json|raw)$/ ? "application/json" : writer.type 
    end
    
    def format
      (params.key?("format") and params["format"][0] != "") ? params["format"][0] : "json"
    end
    
    def writer
      writers = @config[:writers].select {|w| w.format == format }
      if writers.none? or writers.size > 1
        raise "#{writers.size} writers defined for format: #{format}"
      end
      writers[0]
    end

    def client
      ::Icelastic::Client.new(@config)
    end

    # Determine if this is a search request
    def search?
      env['REQUEST_METHOD'] == "GET" && (query? || filter?)
    end

    def query?
      params.keys.select{|param| param[/q(-.+)?/]}.any?
    end

    def filter?
      params.keys.select{|param| param[/filter-.+|not-.+/]}.any?
    end

  end
end
