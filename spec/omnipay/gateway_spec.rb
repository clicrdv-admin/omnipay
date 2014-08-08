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

    it "should access the adapters ipn status" do
      Adapter.stub(:ipn?).and_return(true)
      gateway.ipn_enabled?.should == true
    end

  end


  describe '#payment_redirection' do

    before(:each) do
      @adapter = double('the adapter instance')
      Adapter.stub(:new).with(config).and_return(@adapter)
    end

    it "should handle GET redirections" do
      @adapter.stub(:request_phase).with({:amount => 1295}, 'http://host.tld/pay/my_uid/ipn', 'http://host.tld/pay/my_uid/callback').and_return(['GET', 'http://www.host.tld/payment', {:token => '123456'}])

      response = gateway.payment_redirection(:base_uri => 'http://host.tld', :amount => 1295)
      response.class.should == Rack::Response
      response.status.should == 302
      response.headers['Location'].should == "http://www.host.tld/payment?token=123456"
    end


    it "should handle POST redirections" do
      @adapter.stub(:request_phase).with({:amount => 1295}, 'http://host.tld/pay/my_uid/ipn', 'http://host.tld/pay/my_uid/callback').and_return(['POST', 'http://www.host.tld/payment', {:token => '123456'}])

      response = gateway.payment_redirection(:base_uri => 'http://host.tld', :amount => 1295)
      response.class.should == Rack::Response
      response.status.should == 200
      response.headers['Content-Type'].should == "text/html;charset=utf-8"
      response.body.should == [ Omnipay::AutosubmitForm.new('http://www.host.tld/payment', {:token => '123456'}).html ]
    end


    it "should print a deprecation warning if :host is used instead of :base_uri" do
      @adapter.stub(:request_phase).with({:amount => 1295}, 'http://host.tld/pay/my_uid/ipn', 'http://host.tld/pay/my_uid/callback').and_return(['GET', 'http://www.host.tld/payment', {:token => '123456'}])
      
      Kernel.should_receive(:warn).with('[DEPRECATION] `host` is deprecated.  Please use `base_uri` instead.')
      response = gateway.payment_redirection(:host => 'http://host.tld', :amount => 1295)      
      response.headers['Location'].should == "http://www.host.tld/payment?token=123456"
    end


    it "should handle a default base_uri" do
      @adapter.stub(:request_phase).with({:amount => 1295}, 'http://host.tld/pay/my_uid/ipn', 'http://host.tld/pay/my_uid/callback').and_return(['GET', 'http://www.host.tld/payment', {:token => '123456'}])
      @adapter.stub(:request_phase).with({:amount => 1295}, 'http://www.anotherhost.tld/pay/my_uid/ipn', 'http://www.anotherhost.tld/pay/my_uid/callback').and_return(['GET', 'http://www.anotherhost.tld/payment', {:token => '123456'}])
      
      Omnipay.configuration.base_uri = "http://www.anotherhost.tld"

      response = gateway.payment_redirection(:amount => 1295)
      response.headers['Location'].should == "http://www.anotherhost.tld/payment?token=123456"

      response = gateway.payment_redirection(:host => 'http://host.tld', :amount => 1295)      
      response.headers['Location'].should == "http://www.host.tld/payment?token=123456"
    end

    it "should raise an error if the method is not GET neither POST" do
      @adapter.stub(:request_phase).and_return(['PUT', 'http://www.host.tld/payment', {:token => '123456'}])

      @gateway = gateway
      expect { @gateway.payment_redirection }.to raise_error ArgumentError, "the returned method is neither GET nor POST"
    end

  end


  describe "#ipn_hash" do
    before(:each) do
      @adapter = double('the adapter instance')
      Adapter.stub(:new).with(config).and_return(@adapter)
      @request = double('a request')
      @request.stub(:params).and_return({'foo' => 'bar'})
    end
 
    it "should return the formatted response along with the raw params" do
      @adapter.stub(:ipn_hash).with(@request).and_return({:success => true, :status => :success, :amount => 1295, :transaction_id => '123456', :reference => 'local_id'})

      gateway.ipn_hash(@request).should == {:success => true, :status => :success, :amount => 1295, :transaction_id => '123456', :reference => 'local_id', :raw => {'foo' => 'bar'}}
    end
  end

  # Forward to adapter, and add params
  describe "#callback_hash" do

    before(:each) do
      @adapter = double('the adapter instance')
      Adapter.stub(:new).with(config).and_return(@adapter)
      @request = double('a request')
      @request.stub(:params).and_return({'foo' => 'bar'})
    end

    it "should return the formatted response along with the raw params" do
      @adapter.stub(:callback_hash).with(@request).and_return({:success => true, :status => :success})

      gateway.callback_hash(@request).should == {:success => true, :status => :success, :raw => {'foo' => 'bar'}}
    end

  end


end