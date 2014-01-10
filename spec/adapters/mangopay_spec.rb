require 'spec_helper'

require 'omnipay/adapters/mangopay'

require 'webmock/rspec'
include WebMock


describe Omnipay::Adapters::Mangopay do

  let(:callback_url){'http://callback.url'}

  let(:client_id){'client_id'}
  let(:client_passphrase){'client_passphrase'}
  let(:wallet_id){'wallet_id'}

  let(:amount){1295}

  let(:adapter_params) do
    {
      :client_id => client_id, 
      :client_passphrase => client_passphrase, 
      :wallet_id => wallet_id, 
      :sandbox => true
    }
  end

  let(:adapter){ Omnipay::Adapters::Mangopay.new(callback_url, adapter_params) }


  describe "#initialize" do

    it "should need the identifiers and the wallet" do

      error_message = 'Missing client_id, client_passphrase, or wallet_id parameter'


      [:client_id, :client_passphrase, :wallet_id].each do |mandatory_key|
        invalid_params = adapter_params.clone.tap{|params| params.delete mandatory_key}
        expect { Omnipay::Adapters::Mangopay.new(callback_url, invalid_params) }.to raise_error ArgumentError, error_message
      end

      expect { Omnipay::Adapters::Mangopay.new(callback_url, adapter_params) }.not_to raise_error

    end

  end


  describe "#request_phase" do

    before(:each) do
      Kernel.srand(0) # Reset the RNG
      Time.stub(:now).and_return(Time.at(1388491766)) # Freeze the time
    end

    it "should build a valid request" do

      VCR.use_cassette('mangopay_request_phase') do      
        adapter.request_phase(amount).should == [
          'GET',
          'https://homologation-secure-p.payline.com/webpayment/',
          {'reqCode' => 'prepareStep2', 'stepCode' => 'step2', 'token' => 'MANGOPAY_TOKEN'},
          'MANGOPAY_PAYMENT_ID'
        ]
      end

    end


    it "should have a sandbox mode" do

      production_adapter = Omnipay::Adapters::Mangopay.new(callback_url, adapter_params.merge(:sandbox => false))

      expect { production_adapter.request_phase(amount) }.to raise_error

      # The production mangopay API is called
      WebMock.should have_requested(:post, "https://client_id:client_passphrase@api.mangopay.com/v2/client_id/users/natural").with(
        :body => {
          :Email => "user-1388491766-mpv@host.tld", 
          :FirstName => "User 1388491766-mpv", 
          :LastName => "User 1388491766-mpv", 
          :Birthday => 1388491766, 
          :Nationality => "FR", 
          :CountryOfResidence => "FR"
        }.to_json
      )


    end

  end


  describe "#callback_hash" do

    it "should handle a successful response" do
      VCR.use_cassette('mangopay_callback_phase') do      
        adapter.callback_hash(:transactionId => 'successful-transaction-id').should == {
          :success => true, 
          :amount => 1295, 
          :transaction_id => 'successful-transaction-id'
        }
      end
    end


    it "should handle a cancelation" do
      VCR.use_cassette('mangopay_callback_phase') do      
        adapter.callback_hash(:transactionId => 'canceled-transaction-id').should == {
          :success => false,
          :error => Omnipay::CANCELATION
        }
      end
    end


    it "should handle a payment error" do
      VCR.use_cassette('mangopay_callback_phase') do      
        adapter.callback_hash(:transactionId => 'refused-transaction-id').should == {
          :success => false,
          :error => Omnipay::PAYMENT_REFUSED,
          :error_message => "Refused payment for transaction refused-transaction-id.\nCode : 105103\nMessage : Invalid PIN code"
        }
      end
    end


    it "should handle a wrong response" do
      VCR.use_cassette('mangopay_callback_phase') do
        adapter.callback_hash(:transactionId => 'wrong-transaction-id').should == {
          :success => false,
          :error => Omnipay::INVALID_RESPONSE,
          :error_message => 'Could not fetch details of transaction wrong-transaction-id'
        }
      end
    end

  end

end
