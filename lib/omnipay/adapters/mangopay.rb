# Omnipay adapter for mangopay
# documentation : http://docs.mangopay.com/api-references/
#
# Configuration :
# - client_id:string (mandatory) : client id of your mangopay account
# - client_passphrase:string (mandatory) : the passphrase for your account
# - wallet_id:string (mandatory) : the wallet to be credited with the payments

require_relative 'mangopay/client'


module Omnipay
  module Adapters

    class Mangopay


      def initialize(callback_url, config = {})

        raise ArgumentError.new("Missing client_id, client_passphrase, or wallet_id parameter") unless [config[:client_id], config[:client_passphrase], config[:wallet_id]].all?

        @client = Client.new(config[:client_id], config[:client_passphrase])
        @callback_url = callback_url
        @wallet_id = config[:wallet_id]

      end


      def request_phase(amount, params = {})

        # Create a user
        user_creation_response = @client.post('/users/natural', user_params)
        user_id = user_creation_response["Id"]

        # Create the payment
        payment_creation_response = @client.post(
          '/payins/card/web', 
          :AuthorId => user_id, 
          :DebitedFunds => {
            :Currency => 'EUR',
            :Amount => amount
          },
          :Fees => {
            :Currency => 'EUR',
            :Amount => 0
          }, 
          :CreditedWalletId => @wallet_id,
          :ReturnURL => @callback_url,
          :Culture => 'FR',
          :CardType => 'CB_VISA_MASTERCARD',
          :SecureMode => 'FORCE'
        )

        redirect_url = payment_creation_response["RedirectURL"]
        uri = URI(redirect_url)

        url = "#{uri.scheme}://#{uri.host}#{uri.path}"
        params = Rack::Utils.parse_nested_query(uri.query)

        puts "Response : #{payment_creation_response.inspect}\n"
        ['GET', url, params].tap{|res| puts "Response : #{res.inspect}"}

      end


      def callback_hash(params)

        # 2.0.0-p247 :004 > c.get '/payins/1350428'
        #  => {"Id"=>"1350428", "Tag"=>nil, "CreationDate"=>1388764897, "AuthorId"=>"1350427", "CreditedUserId"=>"1348459", "DebitedFunds"=>{"Currency"=>"EUR", "Amount"=>1295}, "CreditedFunds"=>{"Currency"=>"EUR", "Amount"=>1295}, "Fees"=>{"Currency"=>"EUR", "Amount"=>0}, "Status"=>"SUCCEEDED", "ResultCode"=>"000000", "ResultMessage"=>"Success", "ExecutionDate"=>1388764911, "Type"=>"PAYIN", "Nature"=>"REGULAR", "CreditedWalletId"=>"1349169", "DebitedWalletId"=>nil, "PaymentType"=>"CARD", "ExecutionType"=>"WEB", "RedirectURL"=>"https://homologation-secure-p.payline.com/webpayment/?reqCode=prepareStep2&stepCode=step2&token=1Rez0tZKBG73P6WF2wPC1388764897642", "ReturnURL"=>"http://localhost:9393/pay/mangopay/callback?transactionId=1350428", "TemplateURL"=>nil, "CardType"=>"CB_VISA_MASTERCARD", "Culture"=>"FR", "SecureMode"=>"DEFAULT", "code"=>200}

      end


      private


      def user_params
        random_key = "#{Time.now.to_i}-#{(0...3).map { ('a'..'z').to_a[rand(26)] }.join}"

        {
          :Email => "user-#{random_key}@host.tld",
          :FirstName => "User #{random_key}",
          :LastName => "User #{random_key}",
          :Birthday => Time.now.to_i,
          :Nationality => "FR",
          :CountryOfResidence => "FR"
        }
      end

    end

  end
end