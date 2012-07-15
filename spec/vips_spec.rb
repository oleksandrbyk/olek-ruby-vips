require "spec_helper"

describe VIPS do
  it "has a library version" do
    a = VIPS::LIB_VERSION_ARRAY
    a.size.should == 3
    a[0].should >= 7
    a[1].should >= 20
    a[2].should >= 0
    VIPS::LIB_VERSION.should =~ /^\d+\.\d+\.\d+/
  end

  describe ".sequential_mode_supported?" do
    it "should return false for older libvips versions" do
      original_version = VIPS::LIB_VERSION_ARRAY
      VIPS::LIB_VERSION_ARRAY = [7, 26, 7]
      Vips.sequential_mode_supported?.should == false
      VIPS::LIB_VERSION_ARRAY = original_version
    end

    it "should return true for >= 7.29 libvips versions" do
      original_version = VIPS::LIB_VERSION_ARRAY
      VIPS::LIB_VERSION_ARRAY = [7, 29, 0]
      Vips.sequential_mode_supported?.should == true
      VIPS::LIB_VERSION_ARRAY = original_version
    end
  end
end

