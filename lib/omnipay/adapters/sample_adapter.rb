module Omnipay
  module Adapters

    # This is a sample Omnipay adapter implementation for a fictive payment gateway. You can use it as a boilerplate to develop your own.
    #
    # This adapter will take two arguments in its configuration :
    # * *api_key* [String - mandatory] : given by the payment gateway, used for authenticating to their API
    # * *sandbox* [Boolean - optional] : whether the payment should be done in a sandbox or with the real payment page
    # It may then be initialized like this in a rack application
    #   use Omnipay::Gateway, 
    #         :uid => 'my-gateway',
    #         :adapter => Omnipay::Adapters::SampleAdapter
    #         :config => {
    #           :api_key => 'my-api-key',
    #           :sandbox => (ENV['RACK_ENV'] != 'production')
    #         }

    class SampleAdapter

      # The adapters initialization
      # @param callback_url [String] the absolute callback URL the user should be redirected to after the payment. Will be generated by Omnipay. Example value : "http\://\www\.my-host.tld/pay/my-gateway/callback"
      # @param config [Hash] the adapter's configuration as defined in the application's omnipay config file. For the example above in a dev environment, the value would be {:api_key => 'my-api-key', :sandbox => true}. It is up to you to decide which fields are mandatory, and to both check them in this initializer and specify them in your documentation. In this case :
      #   * *:api_key* [String] (mandatory) : the API key given for your fictive gateway's account
      #   * *:sandbox* [Boolean] (optional) : whether to use a sandboxed payment page, or a real one. Defaults to true
      # @return [SampleAdapter]
      def initialize(config = {})
        @api_key = config[:api_key]
        raise ArgumentError.new("Missing api_key") unless @api_key

        @mode = (config[:sandbox] == false) ? 'production' : 'sandbox'
      end


      # Responsible for determining the redirection to the payment page for a given amount
      # 
      # @param amount [Integer] the amount **in cents** that the user has to pay
      # @param params [Hash] the GET parameters sent to the omnipay payment URL. Can be used to specify transaction-specific variables (the locale to use, the payment page's title, ...). Please use the following keys if you need to, for consistency among adapters :
      #  * *locale* The ISO 639-1 locale code for the payment page
      #  * *title* The title to display on the payment page
      #  * *transaction_id* The transaction id to use, if you want the user to be able to force it
      # @return [Array] an array containing the 4 following values :
      #  * +[String]+ 'GET' or 'POST' : the HTTP method to use for redirecting to the payment page
      #  * +[String]+ the absolute URL of the payment page. Example : "https\://my-provider.tld/sc12fdg57df"
      #  * +[Hash]+   the GET or POST parameters to send to the payment page
      #  * +[String]+ the unique transaction_id given by the payment provider for the upcoming payment. Has to be accessible in the callback phase. 

      def request_phase(amount, calback_url, params={})
        amount_in_dollar = amount * 1.0 / 100
        locale = params[:locale] || 'en'

        transaction = build_new_transaction(amount_in_dollars, callback_url, locale)

        uri = URI(transaction.payment_url)

        method = 'GET'
        url = "#{uri.scheme}://#{uri.host}#{uri.path}"
        get_params = Rack::Utils.parse_query(uri.query)
        transaction_id = transaction.id

        return [
          method,
          url,
          get_params,
          transaction_id
        ]

      end
     

      # @param params [Hash] the GET/POST parameters sent by the payment gateway to the callback url
      # @return [Hash] the resulting response hash which will be accessible in the application. Must contain the following values :
      #  * *:success* (+Boolean+) | Did the payment occur or not?
      #  * *:amount* (+Integer+) <i>if successful</i> | The amount <b>in cents</b> actually payed
      #  * *:transaction_id* (+String+) <i>if successful</i> | The id of the transaction. Must match the one returned in the request phase.
      #  * *:error* (+Symbol+) <i>if failed</i> | The reason why the payment was not successful. The available values are :
      #    * _Omnipay::CANCELED_ : The payment didn't occur because of the user.
      #    * _Omnipay::PAYMENT_REFUSED_ : The payment didn't occue because of an error on the gateway's side.
      #    * _Omnipay::INVALID_RESPONSE_ : The response from the gateway cannot be parsed. The payment may or may not have occured.
      #  * *:error_message* (+String+) <i>if failed</i> | A more detailed error message / stack trace, for logging purposes

      def callback_hash(params)

        transaction_id = params[:transaction_id]
        transaction = fetch_transaction(transaction_id)

        if !transaction
          return { :success => false, :error => Omnipay::INVALID_RESPONSE, :error_message => "No transaction found with id #{transaction_id}"}
        end

        if transaction.success
          { :success => true, :amount => (transaction.amount*100).to_i, :transaction_id => transaction_id }
        else
          if transaction.canceled
            { :success => false, :error => Omnipay::CANCELATION }
          else
            { :success => false, :error => Omnipay::PAYMENT_REFUSED, :error_message => "Transaction #{transaction_id} was not successful : #{transaction.error}" }
          end
        end
      end


      private

      def build_new_transaction(amount, locale)
        # TODO        
      end

      def fetch_transaction(transaction_id)
        # TODO
      end

    end

  end
end