# Omnipay

Omnipay is a library that standardize the integration of multiple off-site payment gateways. It is heavily inspired by the excellent [omniauth](http://github.com/intridea/omniauth/).

It relies on Rack middlewares and so can be plugged in any Rack application.



## Installation

Add this line to your application's Gemfile:

    gem 'omnipay'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install omnipay



## Get Started

Let's say you want to integrate payments via mangopay for your application. The code examples are for a Rails application, but can be easily adapted for any Rack application (Sinatra, Grape, ...)

### Configure a Mangopay gateway

You will first need to setup Omnipay with a secret token in order to securize the payments. You can generate one in an irb console by calling `SecureRandom.hex` ( `require 'active_support'` ) .

```ruby
# config/initializers/omnipay.rb
Omnipay.configure do |config|
  config.secret_token = "my-secret-token"
end
```

You then need to specify and configure your payment gateway  :

```ruby
# config/application.rb

require 'omnipay/adapters/mangopay'

Rails.application.configure do |config|

  # [...]

  config.middleware.use( Omnipay::Gateway,
  
    # The uid is an unique identifier which will be used to generate 2 urls : 
    # - GET /pay/:uid          -> will redirect the user to the payment gateway
    # - GET /pay/:uid/callback -> will be visited by the user after its payment is processed
    :uid      => 'my-payment-gateway',
    
    # The payment gateway you wish to map under these urls. 
    :adapter  => Omnipay::Adapters::Mangopay,

    # The gateway configuration (depends on the chosen adapter).
    :config   => {
      :client_id         => "your-client-id",
      :client_passphrase => "your-secret-passphrase",
      :wallet_id         => "the-id-of-the-wallet-to-credit"
    }
  )

end
```

### Redirect the user to the payment page

The former configuration generated the following URL in your app : `GET /pay/my-payment-gateway`

This url needs to be called with a `:amount` GET parameter, which is the amount in cents the user will be asked to pay.

You can put a link in your application to this url, and test that you are being redirected to a payment page for $10.95 :
```erb
<%= link_to '/pay/my-payment-gateway', :amount => (10.95 * 100) %>
```


### Handle the returns from Mangopay

If you try to fill in the payment form, you may notice that you are redirected to your application's 404 page.

This is because, with the abose configuration, mangopay will redirect the users to the following URL : `GET /pay/my-payment-gateway/callback`.

You need to setup a controller action with a route to handle it : 

```ruby
# config/routes.rb

# [...]
match '/pay/:gateway_id/callback', :to => 'payments#callback', :via => :get

```

You callback action may look like this :

```ruby
# app/controllers/payments_controller.rb

def callback
  omnipay_response = request.env['omnipay.response']
  
  if omnipay_response[:success]
    log_payment(omnipay_response[:amount], omnipay_response[:transaction_id])
    redirect_to root_path, :notice => "Successful Payment"
  else
    if omnipay_response[:error] == Omnipay::CANCELED
      redirect_to root_path, :notice => "You canceled your payment"
    else
      log_error(omnipay_response[:error], omnipay_response[:raw])
      redirect_to root_path, :error => "There was an error with your payment, our team have been notified."
    end
  end
end
```

In your callback action, you will have access to the results of the payment in the hash `request.env['omnipay.response']`. This hash contains the following keys :

 - `:success (boolean)` : was the payment successful or not.

If the payment is **successful**, the following values are also present in the hash :

 - `:amount (integer)` : the amount paid, in cents.
 - `:transaction_id (string)` : the identifier of the transaction on the gateway side. 

If the payment was **not successful**, the following value is present :

 - `:error (symbol)` : the reason why the payment was not successful. Can have one of the following values :
     - `Omnipay::CANCELED` : the payment was canceled by the user.
     - `Omnipay::PAYMENT_REFUSED` : the payment was refused on the gateway side.
     - `Omnipay::INVALID_RESPONSE` : there was an error parsing the response from the gateway.
     - `Omnipay::WRONG_SIGNATURE` : the response seemed good and successful, but didn't match the former redirection (e.g : the amounts are not matching).

In any case, should you need to investigate further, there is the following value :

 - `:raw (hash)` : the entirety of the parameters send by the gateway in its response



## More features

### Optional parameters when calling the payment url

You may specify these GET parameters when calling the payment url. They may or may not be supported, and other may be available. Check your adapter documentation.

- `transaction_id` : the payment reference to be used in the gateway
- `title` : a title to display on the payment page, referencing what is paid
- `locale` : the language to use in the payment process (ISO 639-1)


### Pass a hash to the callback action

You may want to have more informations in the callback. For example, if you have an e-commerce application and the user has multiple pending orders, you may want to know what order was just payed. You can get this by passing a `context` hash to the payment URL, which will then be accessible in the `omniauth.response` hash.

```ruby

# app/views/orders/payment.html.erb
 <%= link_to 'Pay Now', '/pay/sandbox?' + { :amount => @order.amount, :context =>  { :order_id: @order.id }}.to_query %>


# app/controllers/payments_controller.rb
def callback

  omnipay_response = request.env['omnipay.response']

  order = Order.find(omnipay_response[:context][:order_id])
  order.set_paid! if omnipay_response[:success] && omnipay_response[:amount] == order.amount

end
```


### Dynamic gateway configuration

The initializer is a static file only loaded at the applications' start. You may however run a SAAS where multiple users can each integrate their gateway. A way to handle this is to use a block in the gateway configuration :

```ruby
# config/initializer/omnipay.rb

# Using this configuration, each call to /pay/:shop_id will look 
# for a shop having this id, and will forward to its payment page. 
# The callbacks will be on `/pay/:shop_id/callback`

config.middleware.use Omnipay::Gateway do |uid|

    shop = Shop.find(uid)

    if shop && shop.has_mangopay_config?
      # This is the same syntax as above, without the uid
      {
        :adapter => Omnipay::Adapters::Mangopay,
        :config  => {
          :client_id  => shop.mangopay_client_id,
          :client_passphrase => shop.mangopay_client_passphrase,
          :wallet_id   => shop.mangopay_wallet_id        
        }
      }

      # Do not call "return", this will crash the middleware
    end

    # If no config found, the request is forwarded to the app, which will likely 404
  end
)
```


## Implement a new adapter

An omnipay gateway adapter is a class which must implement the following interface :

```ruby
class Omnipay::Adapters::MyAdapter

  # The config argument will be populated with the :config value defined in the initializer
  # It is up to you to decide which fields are mandatory, and to validate their presence
  def initialize(callback_url, config = {})

    @callback_url = callback_url

    unless config[:client_id] && config[:client_secret]
      raise ArgumentError.new("missing client_id or client_secret")
    end

    @auth_token = compute_auth_token(client_id, client_secret)
    
  end


  # Request phase : defines the redirection to the payment gateway
  #
  # Inputs 
  # * amount (integer) : the amount in cents to pay
  # * params (Hash) : optional parameters for this payment (transaction_id, title, locale, ...)
  #
  # Outputs: array with 4 elements :
  # * the HTTP method to use ('GET' or 'POST')
  # * the url to call
  # * the parameters (will be in the url if GET, or as x-www-form-urlencoded in the body if POST)
  # * a unique id referencing the transaction. Has to be accessible in the callback phase.

  def request_phase(amount, params = {})

    transaction_id = params[:transaction_id] || generate_unique_id()

    [
      'POST'
      'https://payment.url',
      {
        :amount => amount,
        :transactionId => transaction_id,
        :callbackUrl => @callback_url,
        :token => @auth_token
      },
      transaction_id
    ]
    
  end


  # Callback hash : extracts the response hash which will be accessible in the callback action
  #
  # Inputs
  # * gateway_callback_params (Hash) : the GET/POST parameters returned by the payment gateway
  #
  # Outputs : a Hash which must contain the following keys :
  # * success (boolean) : was the payment successful or not
  # * amount (integer) : the amount actually paid, in cents, if successful
  # * transaction_id(string) : the unique id generated in the request phase, if successful
  # * error (symbol) : the error code if the payment was not successful
  
  def callback_hash(gateway_callback_params)

    transaction_id = gateway_callback_params[:ref]
    transaction = get_transaction_from_api(transaction_id)
    
    if transaction == nil
      return {
        :success => false,
        :error => Omnipay::INVALID_RESPONSE
      }
    end
    
    if transaction.successful?
      {
        :success => true,
        :amount => transaction.amount.to_i,
        :transaction_id => transaction_id
      }
    elsif transaction.canceled?
      {
        :success => false,
        :error => Omnipay::CANCELED
      }
    elsif transaction.failed?
      {
        :success => false,
        :error => Omnipay::PAYMENT_REFUSED
      }
    else
      {
        :success => false,
        :error => Omnipay::INVALID_RESPONSE
      }      
    end

  end

end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

### Update the gem

Install the `gem-release` gem 

[documentation](http://github.com/svenfuchs/gem-release)

`gem bump`

`gem tag`

`gem release`
