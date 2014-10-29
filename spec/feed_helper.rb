require "spec_helper"

def mock_request(query=QUERY_STRING)
  Rack::Request.new(
    Rack::MockRequest.env_for(
      "/endpoint", "HTTP_HOST" => "example.org", "REQUEST_PATH" => "/endpoint",
      "QUERY_STRING" => "#{query}"
    )
  )
end

def elastic_response_hash
  {
    "took"=>34,
    "timed_out"=>false,
    "_shards"=>{"total"=>8, "successful"=>8, "failed"=>0},
    "hits"=> {
      "total"=>40,
      "max_score"=>0.7834767,
      "hits"=> [
        {"_score" => 1, "_source"=> {"title"=>"test1"}, "highlight" => {"_all" => ["<em><strong>est</strong></em>"]}},
        {"_score" => 1, "_source"=> {"title"=>"test2"}}
      ]
    },
    "aggregations" => {
      "tags" => {"buckets" => [{"key" => "foo","doc_count" => 88}, {"key" => "foo bar","doc_count" => 88}]},
      "hour-created" => {"buckets" => [{"key_as_string" => "2008-07-09","key" => 1215561600000,"doc_count" => 24}]},
      "day-created" => {"buckets" => [{"key_as_string" => "2008-07-09","key" => 1215561600000,"doc_count" => 24}]},
      "month-created" => {"buckets" => [{"key_as_string" => "2008-07","key" => 1215561600000,"doc_count" => 24}]},
      "year-created" => {"buckets" => [{"key_as_string" => "2008","key" => 1215561600000,"doc_count" => 24}]},
      "day-measured" => {"buckets" => [{"key_as_string" => "2014-02-22T06:00:00Z","key" => 1393092000000}]},
      "temperature" => {"buckets" => [{"key" => -30,"doc_count" => 241}]}
    }
  }
end