require 'spec_helper'

describe Omnipay::Adapter do

  class SampleAdapter < Omnipay::Adapter

    # Enable ipn
    enable_ipn

    # Adapter config
    config :api_key,      'the client id'
    config :api_secret,   'the client passphrase'
    config :wallet_id,    'the wallet to credit'

    # Default payment redirection parameters
    default_payment_params(
      :currency => 'EUR',
      :title => 'Ma page de paiement'
    )

    # Custom payment redirection parameters
    custom_payment_param :payer_id, 'the payer\'s mangopay id'
    custom_payment_param :fees,     'the (percent) fees to take on the payment', :default => 0

  end


  before(:all) do
    @adapter = SampleAdapter.new(
      :api_key    => 'api_key',
      :api_secret => 'api_secret',
      :wallet_id  => 'wallet_id'
    )
  end


  describe "configuration" do

    it "should not allow a custom payment parameter to override an existing configuration field" do

      expect {

        class InvalidAdapter < Omnipay::Adapter
          custom_payment_param :reference, 'another reference'
        end

      }.to raise_error ArgumentError, "Cannot add custom payment param reference, as it already exists and is : The local reference of the payment"

    end


    it "should raise an error when trying to call abstract methods" do

      undefined_error = [NoMethodError, "To redefine in adapter implementation"]

      expect { @adapter.payment_page_redirection({}, 'url') }.to            raise_error *undefined_error
      expect { @adapter.payment_page_ipn_redirection({}, 'url', 'url') }.to raise_error *undefined_error
      expect { @adapter.validate_payment_notification({}) }.to              raise_error  *undefined_error
      expect { @adapter.validate_callback_status({}) }.to                   raise_error  *undefined_error

    end

  end



  describe "initialization" do

    it "should raise an error is mandatory config fields are missing" do
      expect { 
        SampleAdapter.new(
          :api_key    => 'api_key',
          :api_secret => 'api_secret'
        )
      }.to raise_error ArgumentError, "Mandatory config field wallet_id is not defined. It is supposed to be the wallet to credit"
    end


    it "should add the config in an accessible hash" do
      adapter =  SampleAdapter.new(
        :api_key    => 'api_key',
        :api_secret => 'api_secret',
        :wallet_id  => 'wallet_id'
      )

      adapter.config.sandbox.should     == true
      adapter.config.api_key.should     == 'api_key'
      adapter.config.api_secret.should  == 'api_secret'
      adapter.config.wallet_id.should   == 'wallet_id'
    end


    it "should be able to override the default config" do
      adapter =  SampleAdapter.new(
        :api_key    => 'api_key',
        :api_secret => 'api_secret',
        :wallet_id  => 'wallet_id',
        :sandbox    => false
      )

      adapter.config.sandbox.should == false
    end


    it "should be able to override the payment default params" do
      adapter = SampleAdapter.new(
        :api_key => 'api_key',
        :api_secret => 'api_secret',
        :wallet_id => 'wallet_id',
        
        :payment => {
          :locale => 'fr',
          :fees => 5
        }
      )

      adapter.default_payment_params.locale.should    == 'fr'
      adapter.default_payment_params.currency.should  == 'EUR'
      adapter.default_payment_params.title.should     == 'Ma page de paiement'
      adapter.default_payment_params.fees.should      == 5
    end

  end



  describe "request_phase" do

    let(:ipn_url){ 'http://host.tld/payment/gateway_id/ipn' }
    let(:callback_url){ 'http://host.tld/payment/gateway_id/back' }
    let(:reference){ 'local_id' }
    let(:amount){ 1295 }

    let(:payment_params){ {
      :amount => amount,
      :reference => reference
    } }


    it "should verify the mandatory payment params are still filled" do
      params_without_amount = payment_params.dup
      params_without_amount.delete :amount

      expect {
        @adapter.request_phase(params_without_amount, ipn_url, callback_url)
      }.to raise_error ArgumentError, "Mandatory payment parameter amount is not defined. It is supposed to be The amount (in cents) to pay"
    end


    it "should forward to the subclass implementation with formatted params" do
      # Using IPN

      @adapter.should_receive(:payment_page_redirection_ipn) do |params, ipn, callback|

        # The params should be populated with every config level
        params.class.should       == OpenStruct
        params.amount.should      == amount
        params.reference.should   == reference
        params.currency.should    == 'EUR'
        params.locale.should      == 'en'
        params.payer_id.should    == nil
        params.fees.should        == 0
        params.title.should       == 'Ma page de paiement'
        params.description.should == nil

        # The ipn url and callback urls should have been forwarded
        ipn.should == ipn_url
        callback.should == callback_url

      end

      @adapter.request_phase(payment_params, ipn_url, callback_url)


      # Not using IPN
      @adapter.class.instance_variable_set(:@ipn_enabled, false)
      @adapter.class.ipn?.should == false

      @adapter.should_receive(:payment_page_redirection) do |params, callback|

        # The params should be populated with every config level
        params.class.should       == OpenStruct
        params.amount.should      == amount
        params.reference.should   == reference
        params.currency.should    == 'EUR'
        params.locale.should      == 'en'
        params.payer_id.should    == nil
        params.fees.should        == 0
        params.title.should       == 'Ma page de paiement'
        params.description.should == nil

        # The callback url should be set
        callback.should == callback_url

      end

      @adapter.request_phase(payment_params, ipn_url, callback_url)

      @adapter.class.instance_variable_set(:@ipn_enabled, true)

    end


    it "should forward the response" do
      
      @adapter.stub(:payment_page_redirection_ipn).and_return([
        'GET',
        'http://host.tld/path',
        {:foo => 'bar'}
      ])

      method, url, params = @adapter.request_phase(payment_params, ipn_url, callback_url)

      method.should == 'GET'
      url.should == 'http://host.tld/path'
      params.should == {:foo => 'bar'}
    end

  end


  describe "ipn phase" do

    it "should forward the request and response" do

      @request = Rack::Request.new({})

      @adapter.stub(:validate_payment_notification){|req| req.class.should == Rack::Request}.and_return({
        :success => true,
        :reference => 'reference',
        :transaction_id => 'transaction_id',
        :amount => 1295
      })

      res = @adapter.ipn_hash(@request)

      res.should == {
        :success => true,
        :reference => 'reference',
        :transaction_id => 'transaction_id',
        :amount => 1295
      }

    end

  end


  describe "callback phase" do

    it "should forward the request and response" do

      @request = Rack::Request.new({})

      @adapter.stub(:validate_callback_status){|req| req.class.should == Rack::Request}.and_return({
        :status => Omnipay::SUCCESS
      })

      res = @adapter.callback_hash(@request)

      res.should == {
        :status => Omnipay::SUCCESS
      }

    end

  end


  it "should define convenience methods for statuses and responses" do

    @adapter.send(:status_error, 'an error').should ==            {:success => false, :status => Omnipay::INVALID_RESPONSE, :error_message => 'an error'}
    @adapter.send(:status_failed, 'an error').should ==           {:success => false, :status => Omnipay::PAYMENT_REFUSED, :error_message => 'an error'}
    @adapter.send(:status_canceled).should ==                     {:success => false, :status => Omnipay::CANCELATION}
    @adapter.send(:status_successful, 'the reference').should ==  {:success => true, :status => Omnipay::SUCCESS, :reference => 'the reference'}

    @adapter.send(:payment_error, 'an error').should ==                                                {:success => false, :status => Omnipay::INVALID_RESPONSE, :error_message => 'an error'}
    @adapter.send(:payment_failed, 'the reference', 'an error').should ==                              {:success => false, :reference => 'the reference', :status => Omnipay::PAYMENT_REFUSED, :error_message => 'an error'}
    @adapter.send(:payment_canceled, 'the reference').should ==                                        {:success => false, :reference => 'the reference', :status => Omnipay::CANCELATION}
    @adapter.send(:payment_successful, 'the reference', 'the transaction id', 'the amount').should ==  {:success => true,  :status => Omnipay::SUCCESS, :reference => 'the reference', :amount => 'the amount', :transaction_id => 'the transaction id'}

  end

end