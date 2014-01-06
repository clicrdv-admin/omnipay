require 'spec_helper'

require 'omnipay/adapters/mangopay'


describe Omnipay::Adapters::Mangopay do

  let(:callback_url){'http://callback.url'}

  let(:client_id){'client_id'}
  let(:client_passphrase){'client_passphrase'}
  let(:wallet_id){'wallet_id'}

  let(:amount){1295}

  let(:adapter_params){ { :client_id => client_id, :client_passphrase => client_passphrase, :wallet_id => wallet_id } }
  let(:adapter){ Omnipay::Adapters::Mangopay.new(callback_url, adapter_params) }


  describe "#initialize" do

    it "should need the identifiers and the wallet" do

      error_message = 'Missing client_id, client_passphrase, or wallet_id parameter'


      adapter_params.keys.each do |mandatory_key|
        invalid_params = adapter_params.clone.tap{|params| params.delete mandatory_key}
        expect { Omnipay::Adapters::Mangopay.new(callback_url, invalid_params) }.to raise_error ArgumentError, error_message
      end

      expect { Omnipay::Adapters::Mangopay.new(callback_url, adapter_params) }.not_to raise_error

    end

  end


  describe "#request_phase" do

    before(:each) do
      Kernel.srand(0) # Reset the RNG
      Time.stub!(:now).and_return(Time.at(1388491766)) # Freeze the time
    end

    it "should build a valid request" do

      VCR.use_cassette('mangopay_request_phase', :record => :new_episodes) do      
        adapter.request_phase(amount).should == [
          'GET',
          'https://homologation-secure-p.payline.com/webpayment/',
          {'reqCode' => 'prepareStep2', 'stepCode' => 'step2', 'token' => 'MANGOPAY_TOKEN'}
        ]
      end

    end


  end


  describe "#callback_hash" do

    pending

  end

end
