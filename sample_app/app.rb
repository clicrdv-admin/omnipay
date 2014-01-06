require 'bundler/setup'
require 'sinatra/base'
require 'json'

require 'omnipay'
require 'omnipay/adapters/oneclicpay'
require 'omnipay/adapters/mangopay'

require 'dotenv'
Dotenv.load

class OmnipaySampleApp < Sinatra::Base

  use Omnipay::Gateway, 
    :uid => "afone",
    :adapter => Omnipay::Adapters::Oneclicpay,
    :config => {
      :tpe_id => ENV['AFONE_PUBLIC_KEY'],
      :secret_key => ENV['AFONE_PRIVATE_KEY'],
      :sandbox => true
    }



  use Omnipay::Gateway, 
    :uid => "mangopay",
    :adapter => Omnipay::Adapters::Mangopay,
    :config => {
      :client_id => ENV['MANGOPAY_PUBLIC_KEY'],
      :client_passphrase => ENV['MANGOPAY_PRIVATE_KEY'],
      :wallet_id => ENV['MANGOPAY_WALLET_ID']
    }


  get '/' do
    erb :home
  end


  # Custom price
  post '/custom-price' do
    amount = (params[:price].to_f * 100).to_i
    redirect to("/pay/afone?amount=#{amount}")
  end

  # Payment callback handling
  get '/pay/:gateway/callback' do
    response = env['omnipay.response']

    if response[:success]
      @amount = response[:amount]
      @reference = response[:reference]

      erb :success
    else
      case response[:error]
      when Omnipay::CANCELATION

        @error = "La transaction a été annulée"

      when Omnipay::INVALID_RESPONSE

        @error = "Erreur lors du traitement de la réponse"
        @details = response[:raw].to_yaml

      when Omnipay::PAYMENT_REFUSED

        @error = "Le paiement a été refusé"
        @details = response[:raw]["reason"]

      end

      erb :failure
    end
  end


  get '/success' do
    @amount = 1250
    @reference = "REF-123"

    erb :success
  end

  get '/failure' do
    @error = "You canceled the transaction"

    erb :failure
  end

end
