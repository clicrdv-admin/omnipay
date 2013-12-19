# Omnipay adapter for oneclicpay
# documentation : docs.oneclicpay.com
#
# Configuration :
# - tpe_id:string (mandatory) : serial number of your virutal payment terminal
# - secret_key:string (mandatory) : security key for your account
# - sandbox:boolean (default: false) : use the sandbox or the production environment
# 
# Optional parameters for the payment url :
# - product : the product name which will be displayed in the payment page (default : '')
# - transaction_id : the id to use in the transaction. will be randomly generated otherwise

require 'base64'
require 'digest'
require 'httparty'

module Omnipay
  module Adapters

    class Oneclicpay

      HTTP_METHOD = 'POST'
      REDIRECT_URLS = {
        :sandbox => 'https://secure.homologation.oneclicpay.com',
        :production => 'https://secure.oneclicpay.com'
      }

      def initialize(callback_url, config)
        @callback_url = callback_url

        @tpe_id = config[:tpe_id]
        @secret_key = config[:secret_key]
        @is_sandbox = config[:sandbox]

        raise ArgumentError.new("Missing tpe_id or secret_key parameter") unless [@tpe_id, @secret_key].all?
      end


      def request_phase(amount, params={})
        product_name = params[:product] || ''
        transaction_id = params[:transaction_id] || random_transaction_id

        [
          HTTP_METHOD,
          (@is_sandbox ? REDIRECT_URLS[:sandbox] : REDIRECT_URLS[:production]),
          redirect_params_for(amount, product_name, transaction_id)
        ]
      end


      def callback_hash(params)

        if params["result"] == "OK"
          # We have to fetch the payed amount via the API
          reference = params["transactionId"]
          amount = get_transaction_amount(reference)

          {
            :success => true,
            :amount => amount,
            :reference => reference
          }
        elsif params["result"] == "NOK"
          {
            :success => false,
            :error => params["reason"]
          }      
        else
          {
            :success => false,
            :error => "Erreur inconnue"
          }
        end
      end


      private

      def redirect_params_for(amount, product_name, transaction_id)
        {
          :montant => (amount.to_f/100).to_s,
          :idTPE => @tpe_id,
          :idTransaction => transaction_id,
          :devise => 'EUR',
          :lang => 'fr',
          :nom_produit => product_name,
          :urlRetourOK => @callback_url,
          :urlRetourNOK => @callback_url
        }.tap{|params|
          params[:sec] = signature(params)
        }
      end


      def random_transaction_id
        "#{Time.now.to_i}-#{@tpe_id}-#{random_token}"
      end

      def random_token
        (0...3).map { ('a'..'z').to_a[rand(26)] }.join
      end


      def signature(params)
        to_sign = (params.values + [@secret_key]).join('|')
        Digest::SHA512.hexdigest(Base64.encode64(to_sign).gsub(/\n/, ''))
      end


      def get_transaction_amount(transaction_id)
        response = HTTParty.post("https://secure.homologation.oneclicpay.com:60000/rest/payment/find?serialNumber=#{@tpe_id}&key=#{@secret_key}&transactionRef=#{transaction_id}")
        response.parsed_response["transaction"][0]["amount"]
      end


    end

  end
end