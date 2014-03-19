require "spec_helper"

describe Icelastic::QueryBuilder::Aggregation do

  def aggregation(params)
    Icelastic::QueryBuilder::Aggregation.new(params)
  end

  context "builder" do

    it "build aggregations" do
      aggregation({"date-day" => "measured", "size-aggregation" => "5"}).build
    end

    ["aggregations", "facets"].each do |param|

        it "handle &#{param}=false" do
          aggregation({param =>"false"}).build.should == nil
        end

    end

  end

  context "bucketing" do

    context "term" do

      ["aggregations", "facets"].each do |param|

        it "handle &#{param}=<field>" do
          aggregation({param => "topics"}).send(:term_aggregations).should == {"topics" => {:terms => {:field => "topics", :size => 20}}}
        end

        it "handle &#{param}=<field1>,<field2>" do
          aggregation({param => "topics,sets"}).send(:term_aggregations).should == {
            "topics" => {:terms => {:field => "topics", :size => 20}},
            "sets" => {:terms => {:field => "sets", :size => 20}}
          }
        end

      end

    end

    context "labeled" do

      ["aggregation", "facet"].each do |param|

        it "handle &#{param}-my+label=<field>" do
          aggregation({"#{param}-a label" => "topic"}).send(:labeled_aggregations).should == {"a label" => {:terms => {:field => "topic", :size => 20}}}
        end

      end

    end

    context "size" do
      ["aggregation", "facet"].each do |param|

        it "handle &size-#{param}=<size>" do
          aggregation({"aggregations" => "topics,sets", "size-#{param}" => 50}).send(:term_aggregations).should == {
            "topics" => {:terms => {:field => "topics", :size => 50}},
            "sets" => {:terms => {:field => "sets", :size => 50}}
          }
        end

      end
    end

    context "histogram" do

      it "handle &aggregations[50]=depth" do
        aggregation({"aggregation[50]" => "depth"}).send(:histogram_aggregations).should == {"depth" => {:histogram => {:field => "depth", :interval => 50}}}
      end

    end

    context "date-histogram" do

      {"hour" => "yyyy-MM-dd'T'hh:mm:ss'Z'", "day" => "yyyy-MM-dd", "month" => "yyyy-MM", "year" => "yyyy"}.each do |interval, format|

        it "handle &date-#{interval}=<field>" do
          aggregation({"date-#{interval}" => "published"}).send(:date_aggregations).should == {
            "#{interval}-published" => {
              :date_histogram => {:field => "published", :interval => interval, :format => format}
            }
          }
        end

        it "handle &date-#{interval}=<field1>,<field2>" do
          aggregation({"date-#{interval}" => "created,updated"}).send(:date_aggregations).should == {
            "#{interval}-created" => {
              :date_histogram => {:field => "created", :interval => interval, :format => format}
            },
            "#{interval}-updated" => {
              :date_histogram => {:field => "updated",:interval => interval,:format => format}
            }
          }
        end

      end

    end

  end

  context "statistics" do

    it "handle dateStat-<interval>=<bucket-field>[<stat-field>|<stat-field>]" do
      aggregation("dateStat-day" => "positioned[latitude|longitude]").send(:date_stat_aggregations).should == {
        "day-positioned" => {
          :date_histogram => {:field => "positioned", :interval => "day", :format => "yyyy-MM-dd"},
          :aggs => {
            "latitude-stats" => {:extended_stats => {:field => "latitude"}},
            "longitude-stats" => {:extended_stats => {:field => "longitude"}}
          }
        }
      }
    end

    it "handle dateStat-<interval>=<bucket-field>[<stat-field>|<stat-field>],<bucket-field2>[<stat-field>]" do
      aggregation("dateStat-day" => "positioned[latitude|longitude],measured[depth]").send(:date_stat_aggregations).should == {
        "day-positioned" => {
          :date_histogram => {:field => "positioned", :interval => "day", :format => "yyyy-MM-dd"},
          :aggs => {
            "latitude-stats" => {:extended_stats => {:field => "latitude"}},
            "longitude-stats" => {:extended_stats => {:field => "longitude"}}
          },
        },
        "day-measured" => {
          :date_histogram => {:field => "measured", :interval => "day", :format => "yyyy-MM-dd"},
          :aggs => {
            "depth-stats" => {:extended_stats => {:field => "depth"}}
          }
        }
      }
    end

    it "handle dateStat-<interval>=<bucket-field>[<stat-field>|<stat-field>]&dateStat-<interval2>=<bucket-field>[<stat-field>|<stat-field>]" do
      aggregation("dateStat-day" => "positioned[latitude|longitude]","dateStat-month" => "positioned[latitude|longitude]").send(:date_stat_aggregations).should == {
        "day-positioned" => {
          :date_histogram => {:field => "positioned", :interval => "day", :format => "yyyy-MM-dd"},
          :aggs => {
            "latitude-stats" => {:extended_stats => {:field => "latitude"}},
            "longitude-stats" => {:extended_stats => {:field => "longitude"}}
          }
        },
        "month-positioned" => {
          :date_histogram => {:field => "positioned", :interval => "month", :format => "yyyy-MM"},
          :aggs => {
            "latitude-stats" => {:extended_stats => {:field => "latitude"}},
            "longitude-stats" => {:extended_stats => {:field => "longitude"}}
          }
        }
      }
    end

  end

end
