# # Omnipay Adapter, for testing / debugging
# # NOCOMMIT

# require 'base64'
# require 'digest/sha2'
# require 'omnipay'

# require 'oneclicpay/client'

# module Oneclicpay
#   module Omnipay

#     # An omnipay adapter, for the oneclicpay integration
#     #
#     # Configuration :
#     # - tpe_id:string (mandatory) : serial number of your virutal payment terminal
#     # - secret_key:string (mandatory) : security key for your account
#     # - sandbox:boolean (default: false) : use the sandbox or the production environment
#     # - ipn:boolean (default: false) : should the IPN return be used
#     # 
#     # Redirection options
#     # - product_name:string (optional) : what will be displayed on the product page
#     # - transaction_id:string (optional) : a unique transaction id to use
#     # - locale:string (optional) : the language to display the payment page in
#     # - ipn_url:string (mandatory id ipn option active) : the url to call for the IPN validation (server->server)
#     class Adapter

#       attr_reader :client

#       HTTP_METHOD = 'POST'

#       REDIRECT_URLS = {
#         :sandbox => 'https://secure.homologation.comnpay.com',
#         :production => 'https://secure.comnpay.com'
#       }

#       def initialize(config = {})
#         @tpe_id     = config[:tpe_id]
#         @secret_key = config[:secret_key]
#         @is_sandbox = config[:sandbox]
#         @use_ipn    = config[:ipn] || false
#         @client     = Oneclicpay::Client.new(@tpe_id, @secret_key, @is_sandbox)

#         raise ArgumentError.new("Missing tpe_id or secret_key parameter") unless [@tpe_id, @secret_key].all?
#       end


#       def request_phase(amount, callback_url, params={})
#         product_name = params[:product_name] || ''
#         transaction_id = params[:transaction_id] || random_transaction_id
#         locale = params[:locale] || 'fr'
#         ipn_url = params[:ipn_url]

#         raise ArgumentError.new("Missing ipn_url parameter") if @use_ipn && !ipn_url

#         [
#           HTTP_METHOD,
#           redirect_url,
#           redirect_params_for(amount, product_name, transaction_id, locale, callback_url, ipn_url)
#         ]
#       end


#       def callback_hash(params)
#         force_validation = true if !@is_ipn # Validate the payment with the API if no server-server callback

#         case params[:result]
#         when "NOK"

#           # Cancelation
#           if params[:reason] == "Abandon de la transaction."
#             return { :success => false, :error => ::Omnipay::CANCELATION }

#           # Error with the payment
#           else
#             return { :success => false, :error => ::Omnipay::PAYMENT_REFUSED, :error_message => params[:reason] }
#           end

#         when "OK"

#           # Payment OK
#           if !!params[:transactionId] && params[:transactionId] != ""
#             return { :success => true, :transaction_id => params[:transactionId] }

#           # No transaction id given..
#           else
#             return { :success => false, :error => ::Omnipay::INVALID_RESPONSE, :error_message => "Successful reponse from oneclicpay, but no transactionId given" }
#           end
        
#         else

#           # Should not be here, error in the response
#           return { :success => false, :error => ::Omnipay::INVALID_RESPONSE, :error_message => "No :result key in the params #{params.inspect}" }

#         end
#       end


#       def ipn_hash(params)

#         # Check the signature
#         response_params = params.symbolize_keys.reject{|key,_| ![:idTpe, :idTransaction, :montant, :result].include?(key)}
#         signature = params[:sec]

#         if signature(response_params).downcase != signature.downcase
#           return { :success => false, :error => ::Omnipay::INVALID_RESPONSE, :error_message => "Invalid signature for #{response_params}. Expected #{signature(response_params)} but got #{signature}." }
#         end


#         # Response "OK" : validate with the API
#         if params[:result] == 'OK'
#           transaction_id = response_params[:idTransaction]
#           transaction = @client.transaction(transaction_id)

#           if !transaction
#             return { :success => false, :error => ::Omnipay::INVALID_RESPONSE, :error_message => "No transaction found for #{transaction_id}" }
#           end

#           if transaction.ok != 1
#             return { :success => false, :error => ::Omnipay::PAYMENT_REFUSED, :transaction_id => transaction_id, :error_message => transaction.message }
#           else
#             return { :success => true, :transaction_id => transaction_id }
#           end

#         elsif params[:result] == 'NOK'
#           return { :success => false, :transaction_id => params[:idTransaction], :error => ::Omnipay::PAYMENT_REFUSED, :error_message => "No reason given. Transaction is #{params[:idTransaction]}"}
#         else
#           return { :success => false, :error => ::Omnipay::INVALID_RESPONSE, :error_message => "No :result key given in the params #{params.inspect}"}
#         end

#       end



#       private

#       def redirect_params_for(amount, product_name, transaction_id, locale, callback_url, ipn_url = nil)
#         params = ActiveSupport::OrderedHash.new

#         params[:montant]        = (amount.to_f/100).to_s
#         params[:idTPE]          = @tpe_id
#         params[:idTransaction]  = transaction_id
#         params[:devise]         = 'EUR'
#         params[:lang]           = locale
#         params[:nom_produit]    = product_name
#         params[:urlRetourOK]    = callback_url
#         params[:urlRetourNOK]   = callback_url

#         params[:urlIPN] = ipn_url if ipn_url
#         params[:sec] = signature(params)

#         params
#       end

#       def random_transaction_id
#         "#{Time.now.to_i}-#{@tpe_id}-#{random_token}"
#       end

#       def random_token
#         (0...3).map { ('a'..'z').to_a[rand(26)] }.join
#       end

#       def signature(params)
#         to_sign = (params.values + [@secret_key]).join('|')
#         Digest::SHA512.hexdigest(Base64.encode64(to_sign).gsub(/\n/, ''))
#       end

#       def redirect_url
#         @is_sandbox ? REDIRECT_URLS[:sandbox] : REDIRECT_URLS[:production]
#       end

#     end
#   end
# end