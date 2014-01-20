require 'spec_helper'

describe Omnipay::Gateways do

  class Adapter
    def initialize(callback_url)
    end
  end

  let(:gateways){Omnipay::Gateways.new}

  describe "#push" do

    it "should raise an error on missing parameters" do

      # Missing uid
      expect{ gateways.push :adapter => Adapter }.to raise_error(ArgumentError)

      # Missing adapter
      expect{ gateways.push :uid => 'foobar' }.to raise_error(ArgumentError)

      # All parameters : ok
      expect{ gateways.push :uid => 'foobar', :adapter => Adapter }.not_to raise_error

      # Block given : ok
      expect{ gateways.push do |uid| {} ; end  }.not_to raise_error

    end

  end


  describe "#find" do

    before(:each) do
      # Static gateway
      gateways.push :uid => 'foo', :adapter => Adapter, :config => {:foo => :bar}

      # Dynamic gateway
      gateways.push do |uid|
        if uid == 'bar'
          {
            :adapter => Adapter,
            :config => {:foo => :baz}
          }
        end
      end
    end


    it "should find static gateways" do
      g = gateways.find('foo')
      g.uid.should == 'foo'
      g.adapter_class.should == Adapter
      g.config.should == {:foo => :bar}
    end


    it "should try to initialize a dynamic gateway if no static found" do
      g = gateways.find('bar')
      g.uid.should == 'bar'
      g.adapter_class.should == Adapter
      g.config.should == {:foo => :baz}
    end


    it "should return nothing otherwise" do
      g = gateways.find('baz')
      g.should be_nil
    end

  end

end