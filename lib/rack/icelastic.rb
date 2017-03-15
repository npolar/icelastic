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
      else

        begin
          self.env = env
          self.params = CGI.parse(env['QUERY_STRING'])

          headers = csv? ? ({"Content-Type" => "text/plain; charset=utf-8"}) : ({"Content-Type" => "application/json; charset=utf-8"})
          body = client.search(request)
          # Execute a search and return the response if a search request
          # @todo How do you get the real HTTP status from elasticsearch-ruby?
          return [200, headers, [body]]

        rescue ArgumentError => e
          return [400, headers, [e.to_s]]
        rescue => e
          return [500, headers, [e.to_s]]
        end
      end
    end

    protected

    def request
      Rack::Request.new(env)
    end

    def type
      if format =~ /^(json|raw)$/ or writer.nil?
        "application/json"
      else
        writer.type
      end
    end

    def format
      (params.key?("format") and params["format"][0] != "") ? params["format"][0] : "json"
    end

    def writer
      writers = @config[:writers].select {|w| w.format == format }
      if writers.none? or writers.size > 1
       log.warn "#{writers.size} writers defined for format: #{format}"
       nil
      else
        writers[0]
      end
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

    def csv?
      params.has_key?('format') && params['format'] == ["csv"]
    end

  end
end
