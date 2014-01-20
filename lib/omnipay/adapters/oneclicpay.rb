# Omnipay adapter for oneclicpay
# documentation : docs.oneclicpay.com
#
# Configuration :
# - tpe_id:string (mandatory) : serial number of your virutal payment terminal
# - secret_key:string (mandatory) : security key for your account
# - sandbox:boolean (default: false) : use the sandbox or the production environment

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

      VALIDATION_URLS = {
        :sandbox => 'https://secure.homologation.oneclicpay.com:60000',
        :production => 'https://secure.oneclicpay.com:60000'
      }

      def initialize(config = {})
        @tpe_id = config[:tpe_id]
        @secret_key = config[:secret_key]
        @is_sandbox = config[:sandbox]

        raise ArgumentError.new("Missing tpe_id or secret_key parameter") unless [@tpe_id, @secret_key].all?
      end


      def request_phase(amount, callback_url, params={})
        product_name = params[:title] || ''
        transaction_id = params[:transaction_id] || random_transaction_id
        locale = params[:locale] || 'fr'

        [
          HTTP_METHOD,
          redirect_url,
          redirect_params_for(amount, product_name, transaction_id, locale, callback_url),
          transaction_id
        ]
      end


      def callback_hash(params)

        if params[:result] == "NOK" && params[:reason] == "Abandon de la transaction."
          return { :success => false, :error => Omnipay::CANCELATION }
        end


        if params[:result] == "OK"

          # Validate the response via the API
          transaction_id = params[:transactionId]
          amount = get_transaction_amount(transaction_id)

          if amount
            { :success => true, :amount => amount, :transaction_id => transaction_id }
          else
            { :success => false, :error => Omnipay::INVALID_RESPONSE, :error_message => "Could not fetch the amount of the transaction #{transaction_id}" }
          end


        elsif params[:result] == "NOK"
          { :success => false, :error => Omnipay::PAYMENT_REFUSED, :error_message => params[:reason] }

        else
          { :success => false, :error => Omnipay::INVALID_RESPONSE, :error_message => "No :result key in the params #{params.inspect}" }
        end
      end


      private

      def redirect_params_for(amount, product_name, transaction_id, locale, callback_url)
        {
          :montant => (amount.to_f/100).to_s,
          :idTPE => @tpe_id,
          :idTransaction => transaction_id,
          :devise => 'EUR',
          :lang => locale,
          :nom_produit => product_name,
          :urlRetourOK => callback_url,
          :urlRetourNOK => callback_url
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
        response = HTTParty.post(
          "#{validation_url}/rest/payment/find?serialNumber=#{@tpe_id}&key=#{@secret_key}&transactionRef=#{transaction_id}",
          :headers => {'content-type' => "application/x-www-form-urlencoded"} # For ruby 1.8.7
        )
        
        (response.parsed_response["transaction"][0]["ok"] != 0) && response.parsed_response["transaction"][0]["amount"]
      end

      def redirect_url
        @is_sandbox ? REDIRECT_URLS[:sandbox] : REDIRECT_URLS[:production]
      end

      def validation_url
        @is_sandbox ? VALIDATION_URLS[:sandbox] : VALIDATION_URLS[:production]
      end

    end

  end
end