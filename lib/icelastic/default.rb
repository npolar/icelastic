module Icelastic
  module Default

    DEFAULT_PARAMS = {
      "start" => 0,
      "limit" => 20,
      "size-facet" => 15,
    }

    def self.params
      @p ||= DEFAULT_PARAMS
    end

    def self.params=(params)
      @p = DEFAULT_PARAMS.merge(params)
    end

  end
end
