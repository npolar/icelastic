module Icelastic
  module Default

    DEFAULT_PARAMS = {
      "start" => 0,
      "limit" => 20,
      "size-facet" => 15,
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

  end
end
