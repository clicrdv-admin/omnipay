require 'spec_helper'

require 'omnipay/adapters/mangopay'

require 'webmock/rspec'
include WebMock


describe Omnipay::Adapters::Mangopay do

  let(:ipn_url){'http://ipn.url'}
  let(:callback_url){'http://callback.url'}

  let(:client_id){'client_id'}
  let(:client_passphrase){'client_passphrase'}
  let(:wallet_id){'wallet_id'}
  let(:adapter_params){ {
    :client_id => client_id, 
    :client_passphrase => client_passphrase, 
    :wallet_id => wallet_id,
    :payment => {
      :currency => 'EUR'
    }
  } }

  let(:reference){'local_id'}
  let(:amount){1295}
  let(:payer_id){'payer_id'}
  let(:params){ {:amount => amount, :reference => reference, :payer_id => payer_id} }

  let(:adapter){ Omnipay::Adapters::Mangopay.new(adapter_params) }


  describe "#request_phase" do

    before(:each) do
      Kernel.srand(0) # Reset the RNG
      Time.stub(:now).and_return(Time.at(1388491766)) # Freeze the time
    end

    it "should build a valid request" do

      VCR.use_cassette('mangopay_request_phase') do      
        adapter.request_phase(params, ipn_url, callback_url).should == [
          'GET',
          'https://homologation-secure-p.payline.com/webpayment/',
          {'reqCode' => 'prepareStep2', 'stepCode' => 'step2', 'token' => 'MANGOPAY_TOKEN'}
        ]
      end

    end


    it "should have a sandbox mode" do

      production_adapter = Omnipay::Adapters::Mangopay.new(adapter_params.merge(:sandbox => false))

      expect { production_adapter.request_phase(params, ipn_url, callback_url) }.to raise_error

      # The production mangopay API is called
      WebMock.should have_requested(:post, "https://client_id:client_passphrase@api.mangopay.com/v2/client_id/payins/card/web").with(
        :body => {
          "AuthorId" => payer_id,
          "DebitedFunds" => {
            "Currency" => "EUR",
            "Amount" => amount
          },
          "Fees" => {
            "Currency" => "EUR",
            "Amount" => 0
          },
          "CreditedWalletId" => wallet_id,
          "ReturnURL" => callback_url,
          "Culture" => "EN",
          "CardType" => "CB_VISA_MASTERCARD",
          "SecureMode" => "FORCE"
        }.to_json
      )

    end


    it "should allow to customize the locale" do

      # Payment creation : use the english culture
      expect(adapter.client).to receive(:post).with("/payins/card/web", {
        :Culture => "EN",
        :AuthorId => payer_id,
        :DebitedFunds => {
          :Currency => "EUR",
          :Amount => amount
        },
        :Fees => {
          :Currency => "EUR",
          :Amount => 0
        },
        :CreditedWalletId => wallet_id,
        :ReturnURL => callback_url,
        :CardType => "CB_VISA_MASTERCARD",
        :SecureMode => "FORCE"
      }) do
        {"Id" => "PAYIN_ID", "RedirectURL" => "http://payin.url"}
      end

      adapter.request_phase(params.merge(:locale => "en"), ipn_url, callback_url)

    end

  end


  # Callback hash IS ipn hash, no need to test both

  describe "#ipn_hash" do

    def make_request(transaction_id)
      Rack::Request.new(Rack::MockRequest.env_for('http://uri.com/pay/callback', :params => {:transactionId => transaction_id}))
    end

    it "should handle a successful response" do
      VCR.use_cassette('mangopay_callback_phase') do
        adapter.ipn_hash(make_request('successful-transaction-id')).should == {
          :success => true,
          :status => Omnipay::SUCCESS,
          :amount => amount, 
          :transaction_id => 'successful-transaction-id',
          :reference => reference
        }
      end
    end


    it "should handle a cancelation" do
      VCR.use_cassette('mangopay_callback_phase') do      
        adapter.ipn_hash(make_request('canceled-transaction-id')).should == {
          :success => false,
          :status => Omnipay::CANCELATION
        }
      end
    end


    it "should handle a payment error" do
      VCR.use_cassette('mangopay_callback_phase') do      
        adapter.ipn_hash(make_request('refused-transaction-id')).should == {
          :success => false,
          :status => Omnipay::PAYMENT_REFUSED,
          :error_message => "Refused payment for transaction refused-transaction-id.\nCode : 105103\nMessage : Invalid PIN code"
        }
      end
    end


    it "should handle a wrong response" do
      VCR.use_cassette('mangopay_callback_phase') do
        adapter.ipn_hash(make_request('wrong-transaction-id')).should == {
          :success => false,
          :status => Omnipay::INVALID_RESPONSE,
          :error_message => 'Cannot fetch the payin with id wrong-transaction-id'
        }
      end
    end

  end

end
