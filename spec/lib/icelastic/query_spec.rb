require "spec_helper"
require "icelastic/query.rb"

describe Icelastic::Query do

  subject do
    query = Icelastic::Query.new
  end

  context "#params" do

    it "q=* when no params provided" do
      subject.params.should == {"q" => "*"}
    end

    it "expose a parameter hash" do
      subject.params = {"q" => "my query"}
      subject.params.should == {"q" => "my query"}
    end

  end

  context "#params=" do

    it "convert parameter string to hash" do
      subject.params = "q=my query&filter-field=value"
      subject.params.should == {"q" => "my query", "filter-field" => "value"}
    end

    it "raise error when non Hash || String argument" do
      expect { subject.params = ["Array"] }.to raise_error
    end

  end

  context "Query building" do

    context "#query_block" do

      it "generate regular query syntax" do
        subject.params = "q="
        subject.stub(:global_query){:global_query_called}
        subject.query_block.should == {:query => :global_query_called}
      end

      it "generate filtered query syntax" do
        subject.params = "q=&not-text=test"
        subject.stub(:filtered_query){:filtered_query_called}
        subject.query_block.should == {:query => :filtered_query_called}
      end

    end

  end

  context "Query Segments" do

    context "#query_string" do

      it "call #global_query when q" do
        subject.stub(:global_query){:global_query}
        subject.params = "q="
        subject.query_string.should == :global_query
      end

      it "call #field_query when q-<field>,*" do
        subject.stub(:field_query){:field_query}
        subject.params = "q-title="
        subject.query_string.should == :field_query
      end

      it "do a wildcard query when no q= is in the query" do
        subject.params = "?facets=false"
        subject.query_string.should == {
        :query_string => {
          :default_field => :_all,
          :query => "*"
        }
      }
      end

    end

    context "#global_query" do

      it "handle q=" do
        subject.params = "q="
        subject.global_query.should == {
          :query_string => {
            :default_field => :_all,
            :query => "*"
          }
        }
      end

      it "handle as semi fuzzy q=inter" do
        subject.params = "q=inter"
        subject.global_query.should == {
          :query_string => {
            :default_field => :_all,
            :query => "inter inter*"
          }
        }
      end

      it "handle q=\"explicit qeury\"" do
        subject.params = "q=\"explicit query\""
        subject.global_query.should == {
          :query_string => {
            :default_field => :_all,
            :query => "explicit query"
          }
        }
      end

      it "ignore ! characters in q=" do
        subject.params = "q=BOO!"
        subject.global_query.should == {
          :query_string => {
            :default_field => :_all,
            :query => "BOO BOO*"
          }
        }
      end

      it "strip extra whitespaces in q=" do
        subject.params = "q= my  sloppy query!   "
        subject.global_query.should == {
          :query_string => {
            :default_field => :_all,
            :query => "my sloppy query my sloppy query*"
          }
        }
      end

      it "handle q=<value>" do
        subject.params = "q=search"
        subject.global_query.should == {
          :query_string => {
            :default_field => :_all,
            :query => "search search*"
          }
        }
      end

    end

    context "#field_query" do

      it "handle q-<field>=<value>" do
        subject.params = "q-title=search"
        subject.field_query.should == {
          :query_string => {
            :default_field => "title",
            :query => "search search*"
          }
        }
      end

      it "?q=<value> when recieving ?q-=<value>" do
        subject.params = "q-=search"
        subject.query_string.should == {
          :query_string => {
            :default_field => :_all,
            :query => "search search*"
          }
        }
      end

      it "handle q-<field1>,<field2>=<value>" do
        subject.params = "q-title,summary=search"
        subject.field_query.should == {
          :query_string => {
            :fields => ["title", "summary"],
            :query => "search search*"
          }
        }
      end

      it "handle q-<field.*>" do
        subject.params = "q-block.*=search"
        subject.field_query.should == {
          :query_string => {
            :fields => ["block.*"],
            :query => "search search*"
          }
        }
      end

    end

    context "#filtered_query" do

      it "generate filtered query structure" do
        subject.params = "q=&filter-title=test"
        subject.stub(:query_string){:query_segment}
        subject.stub(:filter){:filter_segment}
        subject.filtered_query.should == {
          :filtered => {
            :query => :query_segment,
            :filter => :filter_segment
          }
        }
      end

    end

  end

  context "Features" do

    it "try to highlight on the _all field by default" do
      subject.highlight.should == {
        :highlight => {
          :fields => {
            :_all => {
              :pre_tags => ["<em><strong>"],
              :post_tags => ["</strong></em>"],
              :fragment_size => 50,
              :number_of_fragments => 3
            }
          }
        }
      }
    end

  end

end
