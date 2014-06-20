require 'bundler/setup'
require 'sinatra/base'
require 'json'

require 'omnipay'
require 'omnipay/adapters/comnpay'
require 'omnipay/adapters/mangopay'
require 'omnipay/adapters/bitpay'

require 'bitpay'

require 'dotenv'

require 'pry'

Dotenv.load

class OmnipaySampleApp < Sinatra::Base

  # Enable :sessions is buggy ...
  use Rack::Session::Cookie, :key => 'rack.session',
                             :path => '/',
                             :secret => 'my_session_secret'
  
  Omnipay.configure do |config|
    # config.base_path = '/my/base/callback/path'
    # config.base_uri = http://localhost:9393
  end


  default_payment_config = {
    :currency => 'EUR',
    :locale   => 'fr',
    :amount   => 250,
    :fees     => 0
  }

  # Omnipay.use_gateway(
  #   :uid => "comnpay",
  #   :adapter => Omnipay::Adapters::Comnpay,
  #   :config => {
  #     :tpe_id => ENV['COMNPAY_TPE_ID'],
  #     :secret_key => ENV['COMNPAY_SECRET_KEY'],
  #     :payment => default_payment_config
  #   }
  # )

  # Omnipay.use_gateway(
  #   :uid => "mangopay",
  #   :adapter => Omnipay::Adapters::Mangopay,
  #   :config => {
  #     :client_id => ENV['MANGOPAY_PUBLIC_KEY'],
  #     :client_passphrase => ENV['MANGOPAY_PRIVATE_KEY'],
  #     :wallet_id => ENV['MANGOPAY_WALLET_ID'],
  #     :payment => default_payment_config
  #   }
  # )

  Omnipay.use_gateway(
    :uid => "bitpay",
    :adapter => Omnipay::Adapters::BitPay,
    :config => {
      :client_id => ENV['BITPAY_API_KEY'],
      :payment => default_payment_config
    }
  )

  GATEWAYS = %w(bitpay)

  use Omnipay::Middleware


  get '/' do
    @gateways = GATEWAYS.map do |gateway_id|
      gateway = Omnipay.gateways.find(gateway_id)

      {
        :title  => gateway_id,
        :config => gateway.adapter.config.to_h,
        :params => gateway.adapter.default_payment_params.to_h
      }
    end

    erb :home
  end

  get '/pay/:gateway' do
    # Symbolize keys
    params.keys.each do |key|
      params[key.to_sym] = params.delete(key)
    end

    # Reformat integers
    params[:amount] = params[:amount].to_i
    params[:fees]   = params[:fees].to_i

    redirection = Omnipay.gateways.find(params[:gateway]).payment_redirection(params.merge(
      :base_uri => request.base_url,
      :redirectURL => "#{request.base_url}/success" # REMOVE ME : bitpay test
    ))
    
    return redirection.to_a
  end


  # Payment IPN handling
  post '/pay/:gateway/ipn' do
    
  end


  # Payment callback handling
  get '/pay/:gateway/callback' do
    response = env['omnipay.response']

    if response[:success]
      @amount = response[:amount]
      @reference = response[:transaction_id]

      erb :success
    else
      case response[:error]
      when Omnipay::CANCELATION

        @error = "La transaction a été annulée : <pre>#{response[:error_message]}</pre>"

      when Omnipay::INVALID_RESPONSE

        @error = "Erreur lors du traitement de la réponse : \n#{response[:error_message]}"
        @details = response[:raw].to_yaml

      when Omnipay::PAYMENT_REFUSED

        @error = "Le paiement a été refusé : \n#{response[:error_message]}"
        @details = response[:raw]["reason"]

      end

      erb :failure
    end
  end


  get '/success' do
    erb :success
  end

  get '/failure' do
    erb :failure
  end

end
