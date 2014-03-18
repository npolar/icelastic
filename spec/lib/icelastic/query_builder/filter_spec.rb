require 'spec_helper'

describe Icelastic::QueryBuilder::Filter do

  def filter(params)
    Icelastic::QueryBuilder::Filter.new(params)
  end

  context "Filters" do

    it "detect filter params" do
      filter({"q" => "my search", "filter-foo" => "bar"}).params.should == {"filter-foo" => "bar"}
    end

    context "And" do

      it "handle filter-<field>=<value>" do
        f = filter({"filter-foo"=>"bar"})
        f.build.should == {:and => [{:term => {"foo" => "bar"}}]}
      end

      it "handle filter-<field>=<value>,<value>" do
        f = filter({"filter-foo"=>"bar,baz"})
        f.build.should == {:and => [
          {:term => {"foo" => "bar"}},
          {:term => {"foo" => "baz"}}
        ]}
      end

      it "handle filter-<field1>=<value>&filter-<field2>=<value>" do
        f = filter({"filter-foo"=>"bar", "filter-fu"=>"bar"})
        f.build.should == {:and => [
          {:term => {"foo" => "bar"}},
          {:term => {"fu" => "bar"}}
        ]}
      end

    end

    context "Or" do

      it "handle filter-<field>=<value1>|<value2>|<value3>" do
        f = filter({"filter-foo"=>"bar|baz|bad"})
        f.build.should == {:and => [{:or => [
          {:term => {"foo" => "bar"}},
          {:term => {"foo" => "baz"}},
          {:term => {"foo" => "bad"}}
        ]}]}
      end

      it "handle filter-<field>=<value1>|<value2>,<value3>" do
        f = filter({"filter-foo"=>"bar|baz|bad,bas"})
        f.build.should == {:and => [
          {:or => [
            {:term => {"foo" => "bar"}},
            {:term => {"foo" => "baz"}},
            {:term => {"foo" => "bad"}}
          ]},
          {:term => {"foo" => "bas"}}
        ]}
      end

    end

    context "range" do

      it "handle filter-<field>=<value1>..<value2>" do
        f = filter({"filter-foo" => "0..20"})
        f.build.should == {
          :and => [
            {:range => {"foo" => {:gte => "0", :lte => "20"}}}
          ]
        }
      end

      it "handle filter-<field>=<value1>.." do
        f = filter({"filter-foo" => "20.."})
        f.build.should == {
          :and => [
            {:range => {"foo" => {:gte => "20"}}}
          ]
        }
      end

      it "handle filter-<field>=..<value2>" do
        f = filter({"filter-foo" => "..20"})
        f.build.should == {
          :and => [
            {:range => {"foo" => {:lte => "20"}}}
          ]
        }
      end

      it "handle filter-<field>=20..10" do
        f = filter({"filter-foo" => "20..10"})
        f.build.should == {
          :and => [
            {:range => {"foo" => {:gte => "10", :lte => "20"}}}
          ]
        }
      end

      it "handle filter-<date_time_field>=<dt1>..<dt2>" do
        f = filter({"filter-foo" => "2013-12-01T15:00:00Z..2013-08-01T12:00:00Z"})
        f.build.should == {
          :and => [
            {:range => {"foo" => {:gte => "2013-08-01T12:00:00Z", :lte => "2013-12-01T15:00:00Z"}}}
          ]
        }
      end

    end

    context "not" do

      it "handle not-<field>=<value>" do
        f = filter({"not-foo" => "bar"})
        f.build.should == {
          :and => [
            {:not => {:term => {"foo" => "bar"}}}
          ]
        }
      end

      it "handle not-<field>=20..10" do
        f = filter({"not-foo" => "20..10"})
        f.build.should == {
          :and => [
            {
              :not => {:range => {"foo" => {:gte => "10", :lte => "20"}}}
            }
          ]
        }
      end

      it "handle not-<field>=20..10|40..60" do
        f = filter({"not-foo" => "20..10|40..60"})
        f.build.should == {
          :and => [
            {
              :not => {
                :or => [
                  {:range => {"foo" => {:gte => "10", :lte => "20"}}},
                  {:range => {"foo" => {:gte => "40", :lte => "60"}}}
                ]
              }
            }
          ]
        }
      end

      it "handle not-<field>=<val1>,<val2>|<val3>,<val4>..<val5>" do
        f = filter({"not-foo" => "5,8|10,60..90"})
        f.build.should == {
          :and => [
            {:not => {:term => {"foo" => "5"}}},
            {:not =>
              {
                :or => [
                  {:term => {"foo" => "8"}},
                  {:term => {"foo" => "10"}}
                ]
              }
            },
            {:not => {:range => {"foo" => {:gte => "60", :lte => "90"}}}}
          ]
        }
      end

    end

  end

end
