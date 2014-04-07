require 'bundler/setup'
require 'sinatra/base'
require 'json'

require 'omnipay'
require 'omnipay/adapters/oneclicpay'
require 'omnipay/adapters/mangopay'

require 'dotenv'
Dotenv.load

class OmnipaySampleApp < Sinatra::Base

  # Enable :sessions is buggy ...
  use Rack::Session::Cookie, :key => 'rack.session',
                             :path => '/',
                             :secret => 'my_session_secret'
  
  Omnipay.configure do |config|
    # config.base_path = '/my/base/callback/path'
  end

  Omnipay.use_gateway(
    :uid => "mangopay",
    :adapter => Omnipay::Adapters::Mangopay,
    :config => {
      :client_id => ENV['MANGOPAY_PUBLIC_KEY'],
      :client_passphrase => ENV['MANGOPAY_PRIVATE_KEY'],
      :wallet_id => ENV['MANGOPAY_WALLET_ID'],
      :sandbox => true
    }
  )

  Omnipay.use_gateway( 
    :uid => "afone",
    :adapter => Omnipay::Adapters::Oneclicpay,
    :config => {
      :tpe_id => ENV['AFONE_PUBLIC_KEY'],
      :secret_key => ENV['AFONE_PRIVATE_KEY'],
      :sandbox => true
    }
  )


  use Omnipay::Middleware

  ITEMS = {
    'item1' => {
      :title => 'Item 1 (Oneclicpay)',
      :price => 995,
      :gateway => 'afone'
    },

    'item2' => {
      :title => 'Item 1 (Mangopay)',
      :price => 1295,
      :gateway => 'mangopay'
    }
  }

  get '/' do
    @context = {:foo => "bar", :baz => {:boo => "booboo"}}
    erb :home
  end

  get '/pay/:item_id' do
    item = ITEMS[params[:item_id]]

    redirection = Omnipay.gateways.find(item[:gateway]).payment_redirection(:base_uri => 'http://localhost:9393', :amount => item[:price])
    return redirection.to_a

    # In Rails, we could have used redirect_to_payment(:amount => item[:price]) and return
  end


  # Custom price
  post '/custom-price' do
    amount = (params[:price].to_f * 100).to_i
    Omnipay.gateways.find('afone').payment_redirection(:base_uri => 'http://localhost:9393', :amount => amount).to_a
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
    @amount = 1250
    @reference = "REF-123"

    erb :success
  end

  get '/failure' do
    @error = "You canceled the transaction"

    erb :failure
  end

end
