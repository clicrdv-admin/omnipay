require 'spec_helper'

describe Omnipay do

  describe "#configuration" do
    it "should return the configuration" do
      Omnipay.configuration.should == Omnipay::Configuration.instance
    end
  end

  describe "#configure" do
    it "should be evaluated by the configuration" do
      expect(Omnipay::Configuration.instance).to receive(:foo=).with('bar')

      Omnipay.configure do |config|
        config.foo = "bar"
      end
    end
  end

  describe "#gateways" do
    it "should return a memoized Gateways instance" do

      gateways = Omnipay.gateways
      gateways.should be_a Omnipay::Gateways
      gateways.should == Omnipay.gateways

    end
  end

  describe "#use_gateway" do
    it "should forward to Gateways::push" do

      gateways = Omnipay.gateways
      expect(gateways).to receive(:push).with(:uid=>"uid", :adapter=>"adapter")

      Omnipay.use_gateway :uid => 'uid', :adapter => 'adapter'
    end
  end

end