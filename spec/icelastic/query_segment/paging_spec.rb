require 'spec_helper'

describe Icelastic::QuerySegment::Paging do

  def paging(params)
    Icelastic::Default.params = Icelastic::Default::DEFAULT_PARAMS # Reset the defaults from the client
    Icelastic::QuerySegment::Paging.new(params)
  end

  context "Start" do

    it "default 0" do
      p = paging({}).build
      p.should include("from" => 0)
    end

    it "handle &start=<limit>" do
      p = paging({"start" => "25"}).build
      p.should include("from" => 25)
    end

  end

  context "limit" do

    it "default 20" do
      p = paging({}).build
      p.should include("size" => 20)
    end

    it "handle &limit=<limit>" do
      p = paging({"limit" => "50"}).build
      p.should include("size" => 50)
    end

  end

  context "Sort" do

    it "asc when &sort=<field>" do
      p = paging({"sort" => "foo"}).build
      p.should include("sort" => [{"foo" => {"order" => "asc", "ignore_unmapped" => true, "mode" => "avg"}}])
    end

    it "desc when &sort=-<field>" do
      p = paging({"sort" => "-foo"}).build
      p.should include("sort" => [{"foo" => {"order" => "desc", "ignore_unmapped" => true, "mode" => "avg"}}])
    end

    it "handle &sort=<field1>,<field2>" do
      p = paging({"sort" => "foo,-bar"}).build
      p.should include("sort" => [
        {"foo" => {"order" => "asc", "ignore_unmapped" => true, "mode" => "avg"}},
        {"bar" => {"order" => "desc", "ignore_unmapped" => true, "mode" => "avg"}}
      ])
    end

  end

  context "Reduce" do

    it "handle &fields=<field>" do
      p = paging({"fields" => "title"}).build
      p.should include("_source" => ["title"])
    end

    it "handle &fields=<field1>,<field2>" do
      p = paging({"fields" => "title,summary"}).build
      p.should include("_source" => ["title", "summary"])
    end

  end

end
