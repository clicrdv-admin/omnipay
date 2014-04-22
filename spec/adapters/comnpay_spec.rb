require 'spec_helper'

require 'omnipay/adapters/comnpay'


describe Omnipay::Adapters::Comnpay do

  let(:ipn_url){'http://ipn.url'}
  let(:callback_url){'http://callback.url'}

  let(:tpe_id){'tpe_id'}
  let(:secret_key){'secret_key'}

  let(:adapter_params){ {
    :tpe_id => tpe_id,
    :secret_key => secret_key,
    :payment => {
      :currency => 'EUR'
    }
  } }

  let(:reference){'local_id'}
  let(:amount){1295}
  let(:title){'the payment title'}

  let(:params){ {:amount => amount, :reference => reference, :title => title} }

  let(:adapter){ Omnipay::Adapters::Comnpay.new(adapter_params) }


  def mock_request(url, params)
    Rack::Request.new(Rack::MockRequest.env_for(url, :params => params))
  end



  describe 'request phase' do

    before(:each) do
      # transaction_id is randomly generated, stub the random part
      Kernel.srand(0) # Reset the RNG
      Time.stub(:now).and_return(Time.at(1388491766))
    end

    it "should build a valid request" do

      adapter.request_phase(params, ipn_url, callback_url).should == [
        'POST',
        'https://secure.homologation.comnpay.com',
        {
          :montant => "12.95",
          :idTPE => "tpe_id",
          :idTransaction => "1388491766684_local_id",
          :devise => "EUR",
          :lang => "en",
          :nom_produit => "the payment title",
          :urlIPN => "http://ipn.url",
          :urlRetourOK => "http://callback.url",
          :urlRetourNOK => "http://callback.url",
          :sec => "d91faae3b95dd34596b2ef7c8d64a4d0aba0fda7a51c23b6ed4aaa06e4031feaeabf1e5121c9694f7cb52c9e18f20bd623a3ff9499f07308d9c3117065a04992"
        }
      ]

    end

  end



  describe 'ipn phase' do

    it 'should handle a successful transaction' do

      VCR.use_cassette('comnpay_ipn_phase') do

        successful_transaction_params = {
          :idTpe          => tpe_id,
          :idTransaction  => "123456789_local_id",
          :montant        => "20.00",
          :result         => "OK",
          :sec            => "963425f9266febf71b838d61ae5d8b31c07b8feae9740d32286eaa3c6a4629d55d4863b5da5f6b283de61fd38d79d73aea5faa83c7fbb0c26fdf8135bd96ff37"
        }

        adapter.ipn_hash(mock_request('http://uri.com/pay/ipn', successful_transaction_params)).should == {
          :amount         => 2000,
          :reference      => "local_id",
          :status         => :success,
          :success        => true,
          :transaction_id => "123456789_local_id"
        }

      end

    end


    it 'should handle a failed transaction' do

      VCR.use_cassette('comnpay_ipn_phase') do

        failed_transaction_params = {
          :idTpe         => tpe_id,
          :idTransaction => "123456789_failed_payment",
          :result        => "NOK",
          :sec           => "a84c181aa0c7ec9d1e3f63f9eeff63b40df6d392ba616d24658dadb121d626c4973f6128f6c0d1abde601c1c0dc2087baf90a55ff12d850899edf906cf0412a3"
        }

        adapter.ipn_hash(mock_request('http://uri.com/pay/ipn', failed_transaction_params)).should == {
          :error_message  => "Monnaie invalide",
          :reference      => "failed_payment",
          :status         => :payment_refused,
          :success        => false
        }

      end

    end


    it 'should handle an invalid response' do

      VCR.use_cassette('comnpay_ipn_phase') do

        invalid_response_params = {
          :idTpe          => tpe_id,
          :idTransaction  => "123456789_local_id",
          :montant        => "200.00",
          :result         => "OK",
          :sec            => "963425f9266febf71b838d61ae5d8b31c07b8feae9740d32286eaa3c6a4629d55d4863b5da5f6b283de61fd38d79d73aea5faa83c7fbb0c26fdf8135bd96ff37"
        }

        adapter.ipn_hash(mock_request('http://uri.com/pay/ipn', invalid_response_params)).should == {
          :error_message  => "Invalid signature for {:idTpe=>\"tpe_id\", :idTransaction=>\"123456789_local_id\", :montant=>\"200.00\", :result=>\"OK\", :sec=>\"963425f9266febf71b838d61ae5d8b31c07b8feae9740d32286eaa3c6a4629d55d4863b5da5f6b283de61fd38d79d73aea5faa83c7fbb0c26fdf8135bd96ff37\"} : expected 22c456299c5a761f356d5ba7990366ee19c38401fa0b2b1cbc171e449a2427d93767a204420c096f0ee26b659f973776dae4f7a47f9f26812e75f482cf90f058 but got 963425f9266febf71b838d61ae5d8b31c07b8feae9740d32286eaa3c6a4629d55d4863b5da5f6b283de61fd38d79d73aea5faa83c7fbb0c26fdf8135bd96ff37",
          :status         => :invalid_response,
          :success        => false
        }

      end

    end

  end


  describe 'callback phase' do

    it 'should handle a successful callback' do
      response_params = {
        :result => 'OK',
        :reason => '',
        :transactionId => '1388506232-VAD-495-130-uuh'
      }

      adapter.callback_hash(mock_request('http://uri.com/pay/callback', response_params)).should == {
        :success => true, 
        :status  => :success
      }
    end


    it 'should handle a canceled callback' do
      response_params = {
        :result => 'NOK',
        :reason => 'Abandon de la transaction.',
        :transactionId => ''
      }

      adapter.callback_hash(mock_request('http://uri.com/pay/callback', response_params)).should == {
        :success => false, 
        :status  => :cancelation
      }
    end


    it 'should handle a failed callback' do
      response_params = {
        :result => 'NOK',
        :reason => 'Monnaie invalide',
        :transactionId => ''
      }

      adapter.callback_hash(mock_request('http://uri.com/pay/callback', response_params)).should == {
        :success       => false,
        :status        => :payment_refused,
        :error_message => "Monnaie invalide"
      }
    end


    it 'should handle an invalid callback' do
      response_params = {
      }

      adapter.callback_hash(mock_request('http://uri.com/pay/callback', response_params)).should == {
        :success       => false, 
        :status        => :invalid_response, 
        :error_message => "No :result param given"
      }
    end

  end

end