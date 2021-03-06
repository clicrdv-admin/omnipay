require 'spec_helper'


describe Omnipay::Middleware do

  # A sample app, only 404s
  let(:app){ lambda{|env| [404, {}, 'App : Not Found']} }

  # The same app with the sample gateway plugged under '/pay/my_gateway'
  let(:gateway_uid){'my_gateway'}
  let(:app_with_middleware){Omnipay::Middleware.new(app)}
  let(:browser){Rack::Test::Session.new(Rack::MockSession.new(app_with_middleware))}

  before(:all) do

  end    

  describe "request interception" do

    before(:each) do
      @gateway = double('a gateway')
      @gateway.stub(:ipn_enabled?).and_return(true)

      @another_gateway = double('another gateway')
      @another_gateway.stub(:ipn_enabled?).and_return(false)
      @another_gateway.stub(:uid).and_return('another_gateway')

      Omnipay.gateways.stub(:find).with(gateway_uid).and_return(@gateway)
      Omnipay.gateways.stub(:find).with('another_gateway').and_return(@another_gateway)
      Omnipay.gateways.stub(:find).with('another_uid').and_return(nil)
    end

    it "should intercept requests for the ipn phase, and add the processed response in the request environment" do
      expect(@gateway).to receive(:ipn_hash).and_return({:success => true})
      browser.get '/pay/my_gateway/ipn'
      browser.last_request.env['omnipay.response'].should == {:success => true}
    end

    it "should intercept requests for the callback phase and add the processed response in the request environment" do
      expect(@gateway).to receive(:callback_hash).and_return({:success => true})
      browser.get '/pay/my_gateway/callback?foo=bar'
      browser.last_request.env['omnipay.response'].should == {:success => true}
    end

    it "should forward other requests to the app and ignore them" do
      %w(/ /foo/bar /pay /pay/another_uid /pay/another_uid/callback /pay/my_gateway /pay/my_gateway/another_action).each do |path|
        browser.get path

        browser.last_request.env['omnipay.response'].should == nil
        browser.last_response.status.should == 404
        browser.last_response.body.should   == 'App : Not Found'
      end
    end

    it "should call both the IPN and callback urls when IPN is disabled" do
      expect(@another_gateway).to receive(:ipn_hash).and_return({:success => true})
      expect(@another_gateway).to receive(:callback_hash).and_return({:success => true})
      browser.get '/pay/another_gateway/callback?foo=bar'
      browser.last_request.env['omnipay.response'].should == {:success => true}    
    end

    it "should handle custom base paths" do
      Omnipay.configuration.base_path = "/payments"

      expect(@gateway).to receive(:callback_hash).and_return({:success => true})
      browser.get '/payments/my_gateway/callback?foo=bar'
      browser.last_request.env['omnipay.response'].should == {:success => true}    
    end

  end

end