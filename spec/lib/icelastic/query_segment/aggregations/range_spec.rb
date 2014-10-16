require "spec_helper"

describe Icelastic::QuerySegment::RangeAggregation do
  let(:rangeAggregation) { Icelastic::QuerySegment::RangeAggregation.new }

  def range(params)
    rangeAggregation.build_aggregations(Icelastic::Default.params.merge(params))
  end

  def expected(field, interval)
    {
      field => {
        "terms" => {
          "field" => field,
          "script" => "range",
          "params" => {
            "interval" => interval
          },
          "order" => { "_term" => "asc" },
          "lang" => "groovy"
        }
      }
    }
  end

  context "format &rangefacet-<field>=value" do
    it "does parse &rangefacet-temperature=1" do
      result = range({"rangefacet-temperature" => 1})

      expect(result).to eq(expected("temperature", 1))

    end

  end

  it "does handle duplicate query params and choose the latter" do
    result = range({"rangefacet-temperature" => 1,
      "rangefacet-temperature" => 2})

    expect(result).to eq(expected("temperature", 2))

  end

  it "does handle range queries for multiple fields" do
    result = range({"rangefacet-temperature" => 1,
      "rangefacet-salinity" => 2})

    expect(result).to eq(expected("temperature", 1).merge(expected("salinity", 2)))

  end
end
