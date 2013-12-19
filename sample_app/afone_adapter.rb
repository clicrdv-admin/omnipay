require 'base64'
require 'digest'
require 'httparty'

class AfoneAdapter

  REDIRECT_HTTP_METHOD = 'POST'
  REDIRECT_URL = 'https://secure.homologation.oneclicpay.com'

  def initialize(config)
    @config = config
    @amount = nil
  end


  def request_phase(amount, params={})
    @amount = amount
    [REDIRECT_HTTP_METHOD, REDIRECT_URL, redirect_params(params['product'])]
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
  
      puts params.inspect

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

  def redirect_params(product_name = nil)
    {
      :montant => (@amount.to_f/100).to_s,
      :idTPE => @config[:tpe_id],
      :idTransaction => idTransaction,
      :devise => "EUR",
      :lang => 'fr',
      :nom_produit => (product_name || "Produit"),
      # :source => "",
      :urlRetourOK => @config[:callback_url],
      :urlRetourNOK => @config[:callback_url]
    }.tap {|p|
      p[:sec] = signature(p)
    }
  end


  def idTransaction
    "#{Time.now.to_i}-#{@config[:tpe_id]}-#{random_token}"
  end


  def random_token
    (0...3).map { ('a'..'z').to_a[rand(26)] }.join
  end


  def signature(params)
    to_sign = (params.values + [@config[:secret_key]]).join('|')
    Digest::SHA512.hexdigest(Base64.encode64(to_sign).gsub(/\n/, ''))
  end


  def get_transaction_amount(transaction_id)
    response = HTTParty.post("https://secure.homologation.oneclicpay.com:60000/rest/payment/find?serialNumber=#{@config[:tpe_id]}&key=#{@config[:secret_key]}&transactionRef=#{transaction_id}")
    response.parsed_response["transaction"][0]["amount"]
  end

end