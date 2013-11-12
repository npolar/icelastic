module Rack

  # Middlware allowing easy integration of Icelastic
  # into the your Ruby and Rails applications
  #
  # [Authors]
  #   - Ruben Dens

  class Icelastic

    attr_accessor :env

    def initialize(app=nil, options={})

      app = lambda{|env| [200, {"Content-Type" => "application/json"}, [{"error" => "404 Not Found"}.to_json]]} if app.nil?

      @app, @config = app, options
    end

    def call(env)
      self.env = env

      # Execute a search and return the response if a search request
      return [200, {"Content-Type" => "application/json; charset=utf-8"}, [client.search(request)]] if search?

      @app.call(env)
    end

    private

    def request
      Rack::Request.new(env)
    end

    def client
      ::Icelastic::Client.new(@config)
    end

    # Determine if this is a search request
    def search?
      env['REQUEST_METHOD'] == "GET" and not env['QUERY_STRING'].empty?
    end

  end
end