module Omnipay
  module Adapters

    # This is a sample Omnipay adapter implementation for a fictive payment provider. You can use it as a boilerplate to develop your own.
    #
    # This adapter will take two arguments in its configuration :
    # * *api_key* [String - mandatory] : given by the payment provider, used for authenticating to their API
    # * *sandbox* [Boolean - optional] : whether the payment should be done in a sandbox or with the real payment page
    # It may then be set up like this in a rack application
    #   Omnipay.use_gateway(
    #     :uid => 'my_gateway',
    #     :adapter => Omnipay::Adapters::SampleAdapter,
    #     :config => {
    #       :api_key => 'my-api-key',
    #       :sandbox => (ENV['RACK_ENV'] != 'production')
    #     }
    #   )
    #
    # Let's say our payment provider needs to be given the birthdate of the buyer for every payment. It also accepts a locale to display the payment page in
    # It means that the redirection to the payment provider will be called like this :
    #   my_gateway = Omnipay.gateways.find('my_gateway')
    #   my_gateway.payment_redirection({
    #     :amount => 1295, # Amount in cents, mandatory for every adapter
    #     :host => 'http://www.my-website.com', # Also mandatory for every adapter, used to compute the redirect_url
    #     :birthdate => current_user.birthdate, # Custom field for this adapter class
    #     :locale => 'fr' # Optional field for this adapter class
    #   })
    class SampleAdapter

      # The adapters initialization
      # @param config [Hash] the adapter's configuration which will be populated in the application's omnipay config file. For the example above in a dev environment, the value would be {:api_key => 'my-api-key', :sandbox => true}. It is up to you to decide which fields are mandatory, and to both check them in this initializer and specify them in your documentation. In this case :
      #   * +api_key+ : the API key given for your fictive gateway's account. Mandatory
      #   * +sandbox+ : whether to use a sandboxed payment page, or a real one. Optional and defaults to true
      # @return [SampleAdapter]
      def initialize(config = {})
        @api_key = config[:api_key]
        raise ArgumentError.new("Missing api_key") unless @api_key

        @mode = (config[:sandbox] == false) ? 'production' : 'sandbox'
      end


      # Responsible for determining the redirection to the payment page for a given amount
      # 
      # @param amount [Integer] the amount **in cents** that the user has to pay
      # @param callback_url[String] where the user has be redirected after its payment
      # @param params [Hash] the additional GET parameters sent to the omnipay payment URL. This is where you check wether the arguments expected by your the payment provider are present. In this case, we check : 
      #  * +birthdate+ The user's birth date. Mandatory because expected by the provider
      #  * +locale+ The language of the payment page. No required
      # @return [Array] an array containing the 4 following values :
      #  * +[String]+ 'GET' or 'POST' : the HTTP method to use for redirecting to the payment page
      #  * +[String]+ the absolute URL of the payment page. Example : "https\://my-provider.tld/sc12fdg57df"
      #  * +[Hash]+   the GET or POST parameters to send to the payment page
      def request_phase(amount, callback_url, params={})
        # Check our params
        birthdate = params[:birthdate] && params[:birthdate].to_date
        raise ArgumentError.new('parameter birthdate must be given') if birthdate.blank?

        locale = params[:locale] || 'en'

        # Build the transaction (this is where the provider-specific code happens)
        amount_in_dollar = (amount.to_f / 100).round(2)
        payment_params = build_transaction_for_provider(amount, birthdate, locale, callback_url)

        # Return the redirection details (method, url, params)
        return ['GET', 'http://my-provider-payment-endpoint.com', payment_params]
      end
     

      # Analyze the redirection from the payment provider, to determine if the payment is a success, and its details
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
          { :success => true, :amount => (transaction.amount*100).round, :transaction_id => transaction_id }
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