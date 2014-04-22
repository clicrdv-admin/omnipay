require 'base64'
require 'digest/sha2'
require 'securerandom'

module Omnipay
  module Adapters

    # Omnipay adapter for comnpay
    # http://docs.comnpay.com/
    class Comnpay < Omnipay::Adapter

      require 'omnipay/adapters/comnpay/client'
      

      # =============
      # Configuration
      # =============

      enable_ipn

      config :tpe_id,     'the TPE id given for authentication'
      config :secret_key, 'the secret key given for authentication'



      # ===================
      # Payment redirection
      # ===================

      def payment_page_redirection_ipn(params, ipn_url, callback_url)

        redirection_params = {
          :montant         => (params.amount.to_f/100).to_s,
          :idTPE           => config.tpe_id,
          :idTransaction   => transaction_id(params.reference),
          :devise          => params.currency,
          :lang            => params.locale,
          :nom_produit     => params.title,
          :urlIPN          => ipn_url,
          :urlRetourOK     => callback_url,
          :urlRetourNOK    => callback_url
        }.tap do |p|
          p[:sec] = signature(p)
        end

        redirect_url = config.sandbox ? 'https://secure.homologation.comnpay.com' : 'https://secure.comnpay.com'

        return ['POST', redirect_url, redirection_params]

      end


      # ==============
      # IPN validation
      # ==============

      def validate_payment_notification(request)

        # Request params are :idTpe, :idTransaction, :montant, :result, :sec
        params = Omnipay::Helpers.symbolize_keys(request.params)

        # Check the signature
        signature = params[:sec]
        expected_signature = signature Omnipay::Helpers.slice_hash(params, :idTpe, :idTransaction, :montant, :result)
        return payment_error "Invalid signature for #{params} : expected #{expected_signature} but got #{signature}" if signature != expected_signature

        # Fetch the transaction        
        transaction_id = params[:idTransaction]
        return payment_error "No transaction id given" if !transaction_id

        transaction = client.transaction(transaction_id)
        return payment_error "No transaction found for #{transaction_id}" if !transaction

        # Get the local reference
        local_reference = reference(transaction_id)

        # Return the status (ok or nok)
        if transaction.ok == 1
          return payment_successful local_reference, transaction_id, transaction.amount
        else
          # No cancelation notice via IPN
          return payment_failed local_reference, transaction.message
        end

      end


      # =================
      # Return to the app
      # =================

      def validate_callback_status(request)

        params = Omnipay::Helpers.symbolize_keys(request.params)

        case params[:result]
        when 'OK'
          status_successful
        when 'NOK'
          if params[:reason] == 'Abandon de la transaction.'
            status_canceled
          else
            status_failed(params[:reason])
          end
        else
          status_error("No :result param given")
        end

      end


      # =============
      # Client getter
      # =============

      def client
        @client ||= Client.new(config.tpe_id, config.secret_key, !!config.sandbox)
      end


      private

      # =====================
      # Signature computation
      # =====================
      def signature(params)
        to_sign = (params.values + [config.secret_key]).join('|')
        Digest::SHA512.hexdigest(Base64.encode64(to_sign).gsub(/\n/, ''))
      end


      # ============================
      # Reference <=> transaction id
      # ============================
      def transaction_id(reference)
        "#{Time.now.to_i}#{Random.rand(1000)}_#{reference}"
      end

      def reference(transaction_id)
        transaction_id.match(/\d+_(.*)/)[1]
      end

    end

  end
end