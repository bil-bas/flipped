require 'helper'

require 'settings_manager'
include Flipped

describe SettingsManager do
  before :each do
    @attributes = {
            :frog => ['fish', 12],
            :cheese => ['@knees', 'fred'],
            :peas => ['@hash[:peas]', true],
    }

    class Configured
      include SettingsManager

      attr_accessor :fish

      def initialize
        @hash = Hash.new
      end
    end

    @configured = Configured.new
  end

  describe "read_config()" do
    before :each do
      @configured.read_config(@attributes, '')
    end

    it "should set fish" do
      @configured.fish.should == 12
    end

    it "should set @knees attribute" do
      @configured.instance_variable_get('@knees').should == 'fred'
    end

    it "should set a value in the @hash attribute" do
      @configured.instance_variable_get('@hash')[:peas].should be_true
    end
  end
end