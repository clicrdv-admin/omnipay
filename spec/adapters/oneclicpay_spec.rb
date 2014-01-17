require 'spec_helper'

require 'omnipay/adapters/oneclicpay'


describe Omnipay::Adapters::Oneclicpay do

  let(:callback_url){"http://callback.url"}
  let(:tpe_id){"tpe_id"}
  let(:secret_key){"secret_key"}
  let(:amount){1295}

  let(:adapter){Omnipay::Adapters::Oneclicpay.new(callback_url, :tpe_id => tpe_id, :secret_key => secret_key, :sandbox => true)}

  describe "#initialize" do

    it "should need the identifiers" do

      error_message = 'Missing tpe_id or secret_key parameter'

      expect { Omnipay::Adapters::Oneclicpay.new(callback_url, {}) }.to raise_error ArgumentError, error_message
      expect { Omnipay::Adapters::Oneclicpay.new(callback_url, :tpe_id => tpe_id) }.to raise_error ArgumentError, error_message
      expect { Omnipay::Adapters::Oneclicpay.new(callback_url, :secret_key => secret_key) }.to raise_error ArgumentError, error_message
      expect { Omnipay::Adapters::Oneclicpay.new(callback_url, :tpe_id => tpe_id, :secret_key => secret_key) }.not_to raise_error

    end

    it "should have a sandbox mode" do

      production_adapter = Omnipay::Adapters::Oneclicpay.new(callback_url, :tpe_id => tpe_id, :secret_key => secret_key)
      sandbox_adapter = Omnipay::Adapters::Oneclicpay.new(callback_url, :tpe_id => tpe_id, :secret_key => secret_key, :sandbox => true)

      # Check the endpoints
      production_adapter.send(:redirect_url).should == "https://secure.oneclicpay.com"
      sandbox_adapter.send(:redirect_url).should == "https://secure.homologation.oneclicpay.com"

      production_adapter.send(:validation_url).should == "https://secure.oneclicpay.com:60000"
      sandbox_adapter.send(:validation_url).should == "https://secure.homologation.oneclicpay.com:60000"

    end

  end


  describe "#request_phase" do

    before(:each) do
      Kernel.srand(0) # Reset the RNG
      Time.stub(:now).and_return(Time.at(1388491766)) # Freeze the time
    end


    it "should build a valid request" do
      adapter.request_phase(amount).should == [
        'POST',
        'https://secure.homologation.oneclicpay.com',
        {
          :montant => "12.95",
          :idTPE => "tpe_id",
          :idTransaction => "1388491766-tpe_id-mpv",
          :devise => "EUR",
          :lang => "fr",
          :nom_produit => "",
          :urlRetourOK => "http://callback.url",
          :urlRetourNOK => "http://callback.url",
          :sec => "df899958eb68aa5bdc709a708f73614c116f54f7ad1bf818e31a416d896374da43a903e850a70decbc4d548fab1bbaff2576d8c76e3f7c70f02eca95eff1115e"          
        },
        '1388491766-tpe_id-mpv'
      ]
    end

    it "should allow custom parameters" do
      reference = "reference"
      title = "title"
      locale = "en"

      adapter.request_phase(amount, 
                            :transaction_id => reference, 
                            :title => title, 
                            :locale => locale).should == [
        'POST',
        'https://secure.homologation.oneclicpay.com',
        {
          :montant => "12.95",
          :idTPE => "tpe_id",
          :idTransaction => "reference",
          :devise => "EUR",
          :lang => "en",
          :nom_produit => "title",
          :urlRetourOK => "http://callback.url",
          :urlRetourNOK => "http://callback.url",
          :sec => "8269d3c7c901628594499283a855c5c37b8ebc05b741e4818dc439ceb7ee30493bdabe993b7425ea327828f71c4e3d9d8e8574683d7a7a872392f93d9df56731"          
        },
        'reference'
      ]
    end

    it "should generate a random transaction id if none specified" do
      transaction_id_1 = adapter.request_phase(amount)[2][:idTransaction]
      transaction_id_2 = adapter.request_phase(amount)[2][:idTransaction]

      transaction_id_1.should_not == transaction_id_2
    end

  end


  describe "#callback_hash" do

    it "should handle cancelations" do

      cancelation_response_params = {
        :result => 'NOK',
        :reason => 'Abandon de la transaction.',
        :transactionId => ''
      }

      adapter.callback_hash(cancelation_response_params).should == {:success => false, :error => Omnipay::CANCELATION}

    end

    it "should handle refused payments" do

      refused_payment_response_params = {
        :result => 'NOK',
        :reason => 'Monnaie invalide',
        :transactionId => '1388504385-VAD-495-130-fgj'
      }

      adapter.callback_hash(refused_payment_response_params).should == {:success => false, :error => Omnipay::PAYMENT_REFUSED, :error_message => 'Monnaie invalide'}

    end

    it "should handle validation errors" do

      good_response_params = {
        :result => 'OK',
        :reason => '',
        :transactionId => '1388504385-VAD-495-130-fgj'
      }

      VCR.use_cassette('wrong_validation', :record => :new_episodes) do
        adapter.callback_hash(good_response_params).should == {:success => false, :error => Omnipay::INVALID_RESPONSE, :error_message => 'Could not fetch the amount of the transaction 1388504385-VAD-495-130-fgj'}
      end

    end


    it "should return the mandatory infos when everything is alright" do

      good_response_params = {
        :result => 'OK',
        :reason => '',
        :transactionId => '1388506232-VAD-495-130-uuh'
      }

      VCR.use_cassette('good_validation', :record => :new_episodes) do
        adapter.callback_hash(good_response_params).should == {:success => true, :amount => 990, :transaction_id => '1388506232-VAD-495-130-uuh'}
      end

    end

  end

end
