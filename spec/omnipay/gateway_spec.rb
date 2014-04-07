require 'spec_helper'

describe Omnipay::Gateway do

  class Adapter
    def initialize(callback_url)
    end
  end

  let(:uid){ 'my_uid' }
  let(:adapter_class){ Adapter }
  let(:config){ {:foo => 'bar'} }

  let(:gateway){ Omnipay::Gateway.new(:uid => uid, :adapter => adapter_class, :config => config) }


  describe "#initialize" do

    it "should check mandatory arguments" do
      expect{ Omnipay::Gateway.new :adapter => adapter_class }.to raise_error ArgumentError
      expect{ Omnipay::Gateway.new :uid => uid }.to raise_error ArgumentError
      expect{ Omnipay::Gateway.new :uid => uid, :adapter => adapter_class }.not_to raise_error
    end

    it "should generate an adapter instance" do
      adapter = double('the adapter instance')
      Adapter.stub(:new).with(config).and_return(adapter)

      gateway = Omnipay::Gateway.new(:uid => uid, :adapter => adapter_class, :config => config)
      gateway.adapter.should == adapter
      gateway.uid.should == uid
      gateway.adapter_class.should == adapter_class
      gateway.config.should == config
    end

  end


  describe '#payment_redirection' do

    before(:each) do
      @adapter = double('the adapter instance')
      Adapter.stub(:new).with(config).and_return(@adapter)
    end

    it "should handle GET redirections" do
      @adapter.stub(:request_phase).with(1295, 'http://host.tld/pay/my_uid/callback', {}).and_return(['GET', 'http://www.host.tld/payment', {:token => '123456'}])

      response = gateway.payment_redirection(:base_uri => 'http://host.tld', :amount => 1295)
      response.class.should == Rack::Response
      response.status.should == 302
      response.headers['Location'].should == "http://www.host.tld/payment?token=123456"
    end


    it "should handle POST redirections" do
      @adapter.stub(:request_phase).with(1295, 'http://host.tld/pay/my_uid/callback', {}).and_return(['POST', 'http://www.host.tld/payment', {:token => '123456'}])

      response = gateway.payment_redirection(:base_uri => 'http://host.tld', :amount => 1295)
      response.class.should == Rack::Response
      response.status.should == 200
      response.headers['Content-Type'].should == "text/html;charset=utf-8"
      response.body.should == [ Omnipay::AutosubmitForm.new('http://www.host.tld/payment', {:token => '123456'}).html ]
    end


    it "should print a deprecation warning if :host is used instead of :base_uri" do
      @adapter.stub(:request_phase).with(1295, 'http://host.tld/pay/my_uid/callback', {}).and_return(['GET', 'http://www.host.tld/payment', {:token => '123456'}])
      
      Kernel.should_receive(:warn).with('[DEPRECATION] `host` is deprecated.  Please use `base_uri` instead.')
      response = gateway.payment_redirection(:host => 'http://host.tld', :amount => 1295)      
    end

  end


  describe "#formatted_response_for" do

    before(:each) do
      @adapter = double('the adapter instance')
      Adapter.stub(:new).with(config).and_return(@adapter)
    end

    it "should return the formatted response along with the raw params" do
      @adapter.stub(:callback_hash).with({:ref_id => '123456'}).and_return({:success => true, :amount => 1295, :transaction_id => '123456'})

      gateway.formatted_response_for(:ref_id => '123456').should == {:success => true, :amount => 1295, :transaction_id => '123456', :raw => {:ref_id => '123456'}}
    end

  end


end