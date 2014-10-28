module Icelastic
  module Default

    DEFAULT_PARAMS = {
      "start" => 0,
      "limit" => 100,
      "size-facet" => 10,
      "variant" => "legacy"
    }

    GEO_PARAMS = {
      "latitude" => "latitude",
      "longitude" => "longitude",
      "geometry" => "point"
    }

    def self.params
      @p ||= DEFAULT_PARAMS
    end

    def self.params=(params)
      @p = DEFAULT_PARAMS.merge(params)
    end

    def self.geo_params
      @gp ||= GEO_PARAMS
    end

    def self.geo_params=(params)
      @gp = GEO_PARAMS.merge(params)
    end
    
    def self.writers
      [ {"format" => "json", "writer" => ResponseWriter::Feed, "from" => "elasticsearch", "type" => "application/json"},
        {"format" => "csv", "writer" => ResponseWriter::Csv, "from" => "feed", "type" => "text/plain"},
        {"format" => "geojson", "writer" => ResponseWriter::GeoJSON, "from" => "feed", "type" => "application/json"}
      ]
    end

  end
end
