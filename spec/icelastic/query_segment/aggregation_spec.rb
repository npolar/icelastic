require "spec_helper"

describe Icelastic::QuerySegment::Aggregation do

  def aggregation(params)
    Icelastic::QuerySegment::Aggregation.new(params)
  end

  context "builder" do

    it "build aggregations" do
      aggregation({"date-day" => "measured", "size-aggregation" => "5"}).build
    end

    it "handle &facets=false" do
      aggregation({"facets" =>"false"}).build.should == nil
    end

  end

  context "bucketing" do

    context "term" do

      it "handle &facets=<field>" do
        aggregation({"facets" => "topics"}).send(:term_aggregations).should == {"topics" => {"terms" => {"field" => "topics", "size" => 15}}}
      end

      it "handle &facets=<field1>,<field2>" do
        aggregation({"facets" => "topics,sets"}).send(:term_aggregations).should == {
          "topics" => {"terms" => {"field" => "topics", "size" => 15}},
          "sets" => {"terms" => {"field" => "sets", "size" => 15}}
        }
      end

    end

    context "labeled" do

      it "handle &facet-my+label=<field>" do
        aggregation({"facet-a label" => "topic"}).send(:labeled_aggregations).should == {"a label" => {"terms" => {"field" => "topic", "size" => 15}}}
      end

    end

    context "size" do

        it "handle &size-facet=<size>" do
          aggregation({"facets" => "topics,sets", "size-facet" => 50}).send(:term_aggregations).should == {
            "topics" => {"terms" => {"field" => "topics", "size" => 50}},
            "sets" => {"terms" => {"field" => "sets", "size" => 50}}
          }
        end

    end

    context "date-histogram" do

      {"hour" => "yyyy-MM-dd'T'HH:mm:ss'Z'", "day" => "yyyy-MM-dd", "month" => "yyyy-MM", "year" => "yyyy"}.each do |interval, format|

        it "handle &date-#{interval}=<field>" do
          aggregation({"date-#{interval}" => "published"}).send(:date_aggregations).should == {
            "#{interval}-published" => {
              "date_histogram" => {"field" => "published", "interval" => interval, "format" => format}
            }
          }
        end

        it "handle &date-#{interval}=<field1>,<field2>" do
          aggregation({"date-#{interval}" => "created,updated"}).send(:date_aggregations).should == {
            "#{interval}-created" => {
              "date_histogram" => {"field" => "created", "interval" => interval, "format" => format}
            },
            "#{interval}-updated" => {
              "date_histogram" => {"field" => "updated", "interval" => interval, "format" => format}
            }
          }
        end

      end

    end

  end

  context "statistics" do

    it "handle dateStat-<interval>=<bucket-field>[<stat-field>:<stat-field>]" do
      aggregation("date-day" => "positioned[latitude:longitude]").send(:date_aggregations).should == {
        "day-positioned" => {
          "date_histogram" => {"field" => "positioned", "interval" => "day", "format" => "yyyy-MM-dd"},
          "aggs" => {
            "latitude" => {"extended_stats" => {"field" => "latitude"}},
            "longitude" => {"extended_stats" => {"field" => "longitude"}}
          }
        }
      }
    end

    it "handle dateStat-<interval>=<bucket-field>[<stat-field>:<stat-field>],<bucket-field2>[<stat-field>]" do
      aggregation("date-day" => "positioned[latitude:longitude],measured[depth]").send(:date_aggregations).should == {
        "day-positioned" => {
          "date_histogram" => {"field" => "positioned", "interval" => "day", "format" => "yyyy-MM-dd"},
          "aggs" => {
            "latitude" => {"extended_stats" => {"field" => "latitude"}},
            "longitude" => {"extended_stats" => {"field" => "longitude"}}
          },
        },
        "day-measured" => {
          "date_histogram" => {"field" => "measured", "interval" => "day", "format" => "yyyy-MM-dd"},
          "aggs" => {
            "depth" => {"extended_stats" => {"field" => "depth"}}
          }
        }
      }
    end

    it "handle dateStat-<interval>=<bucket-field>[<stat-field>:<stat-field>]&dateStat-<interval2>=<bucket-field>[<stat-field>:<stat-field>]" do
      aggregation("date-day" => "positioned[latitude:longitude]","date-month" => "positioned[latitude:longitude]").send(:date_aggregations).should == {
        "day-positioned" => {
          "date_histogram" => {"field" => "positioned", "interval" => "day", "format" => "yyyy-MM-dd"},
          "aggs" => {
            "latitude" => {"extended_stats" => {"field" => "latitude"}},
            "longitude" => {"extended_stats" => {"field" => "longitude"}}
          }
        },
        "month-positioned" => {
          "date_histogram" => {"field" => "positioned", "interval" => "month", "format" => "yyyy-MM"},
          "aggs" => {
            "latitude" => {"extended_stats" => {"field" => "latitude"}},
            "longitude" => {"extended_stats" => {"field" => "longitude"}}
          }
        }
      }
    end

  end

end
