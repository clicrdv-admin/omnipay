require 'bundler/setup'
require 'sinatra/base'
require 'json'

require 'omnipay'
require 'omnipay/adapters/oneclicpay'

require 'dotenv'
Dotenv.load

class OmnipaySampleApp < Sinatra::Base

  # Enable :sessions is buggy ...
  use Rack::Session::Cookie, :key => 'rack.session',
                             :path => '/',
                             :secret => 'my_session_secret'
  
  Omnipay.configure do |config|
    config.secret_token = "7f394e59be2bac6222eff91232d15dbc"
  end

  use Omnipay::Gateway, 
    :uid => "afone",
    :adapter => Omnipay::Adapters::Oneclicpay,
    :config => {
      :tpe_id => ENV['AFONE_PUBLIC_KEY'],
      :secret_key => ENV['AFONE_PRIVATE_KEY'],
      :sandbox => true
    }


  get '/' do
    @items = [
      {
        :name  => "Item 1",
        :price => 990,
        :desc  => ""
      },
      {
        :name  => "Item 3",
        :price => 1490,
        :desc  => ""
      }
    ]

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

      when Omnipay::WRONG_SIGNATURE

        @error = "La réponse ne correspond pas au paiement qui était demandé"
        @details = response[:raw].merge(:session => session).to_yaml

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
