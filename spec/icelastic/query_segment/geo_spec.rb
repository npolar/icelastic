require 'spec_helper'

describe Icelastic::QuerySegment::Geo do

  def geo(params)
    Icelastic::QuerySegment::Geo.new(params)
  end

  context "Geo" do
    
    it "should detect bbox params" do
      geo({"bbox" => "-180,-90,180,90"}).params.should == { "bbox" => "-180,-90,180,90" }
    end
    

    context "bbox" do
      it "should return geo_shape envelope" do
          geo({"bbox" => "-180,-90,180,90"}).build.should == { "geo_shape"=>{ "geometry" => { "shape" => { "type" => "envelope", "coordinates" => [[-180.0, -90.0], [180.0, 90.0]]}}}}
      end  
      
    end

  end

end