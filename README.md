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

Let's say you want to integrate payments via mangopay for your application.

You will first need to plug an Omnipay MangoPay Gateway in your application

```ruby
# config/initializers/omnipay.rb
Rails.application.configure do |config|

  # An omnipay gateway is configured with a hash with the following keys :
  # * :uid : an unique identifier which will be used
  #   to generate 2 urls. One for sending the user to the payment
  #   gateway, and one for the user's return from the gateway.
  #
  # * :adapter : the integration of this payment gateway
  #
  # * :config : a config hash passed to the adapter

  config.middleware.use Omnipay::Gateway,
    :uid      => 'sandbox',
    :adapter  => Omnipay::Adapters::Mangopay,
    :config   => {
      :public_key  => "azerty1234",
      :private_key => "azerty1234",
      :wallet_id   => 12345
    }
  )

end
```

This configuration will make your app respond to two urls :

 * `GET /pay/sandbox?amount=xxxx` will forward your user to mangopay for paying the xxxx amount (in cents)
 * `GET /pay/sandbox/callback` will be called when the payment process is complete. You will need to create a route to handle this request in your application


```ruby
# config/routes.rb
get '/pay/:gateway_id/callback', :to => "payments#callback"

# app/controllers/payments_controller.rb
def callback

  # In this action you have access to the hash request.env['omnipay.response']
  # This reponse hash is independant of the chosen gateway and will look like this : 
  {
    :amount => 1295 # The amount in cents payed by the user.
    :success => true # Was the payment successful or not.
    :error => :invalid_pin # An error code if the payment was not successful.
    :reference => "O-12XFD-987" # The payment's reference in the gateway platform.
    :raw => <Hash> # The raw response params from the gateway
  }

end

```


## Give context to the callback

You may want to have more informations in the callback. For example, if you have an e-commerce application and the user has multiple pending orders, you may want to know what order was just payed. You can get this by passing a `context` hash to the payment URL, which will then be accessible in the `omniauth.response` hash.

```ruby

# app/views/orders/payment.html.erb
<%= link_to '/pay/sandbox', 
            :amount => @order.amount, 
            :context => {:order_id => @order.id} %>


# app/controllers/payments_controller.rb
def callback

  omnipay_response = request.env['omnipay.response']

  order = Order.find(omnipay_response[:context][:order_id])
  order.set_paid! if omnipay_response[:success] && omnipay_response[:amount] == order.amount

end
```


## Handle dynamic gateway configuration

The initializer is a static file only loaded at the applications's start. You may however run a SAAS where multiple users each can define its gateway configuration. A way to handle this is to use a block in the gateway configuration :

```ruby
# config/initializer/omnipay.rb

# Using this configuration, each call to /pay/:shop_id will look 
# for a shop having this id, and will forward to its payment page. 
# The callback will still be on `/pay/:shop_id/callback`

config.middleware.use Omnipay::Gateway do |uid|

    shop = Shop.find(uid)

    if shop && shop.has_mangopay_config?
      # This is the same syntax as above, without the uid
      {
        :adapter => Omnipay::Adapters::Mangopay,
        :config  => {
          :public_key  => shop.mangopay_public_key,
          :private_key => shop.mangopay_private_key,
          :wallet_id   => shop.mangopay_wallet_id        
        }
      }

      # Do not call "return", this will crash the middleware
    end

    # If no config found, the request is forwarded to the app, which will likely 404
  end
)
```


## Create a new Adapter

An omnipay gateway adapter is a class who must implement the following interface :

```ruby
class Omnipay::Adapters::Aphone

  # This is the same config as defined in the initializer
  # It is up to you to decide which fields are mandatory, and to validate their presence
  def initialize(config)
    @config = config
  end


  # Request phase : defines the redirection to the payment gateway
  # Inputs 
  # * amount (integer) : the amount in cents to pay
  # Outputs: array with 3 elements :
  # * the HTTP method to use ('GET' ot 'POST')
  # * the url to call
  # * the parameters (will be in the url if GET, or as x-www-form-urlencoded in the body if POST)
  def request_phase(amount)
    [
      'POST'
      'https://secure.homologation.oneclicpay.com',
      {
        :montant => amount,
        :idTPE   => @config[:public_key],
        :devise  => 'EUR',
        [...]
      }
    ]
  end



  # Callback hash : extracts the response hash which will be accessible in the callback action
  # Inputs
  # * params (Hash) : the GET/POST parameters returned by the payment gateway
  # Outputs : a Hash which must contain the following keys :
  # * success (boolean) : was the payment successful or not
  # * amount (integer) : the amount actually paid, in cents, if successful
  # * error (string) : the error code if the payment was not successful
  # * reference (string) : the reference of the payment given by the payment gateway, if successful
  def callback_hash(gateway_callback_params)

    if MyHelper.valid_reponse(gateway_callback_params)
      {
        :success => true,
        :amount => gateway_callback_params['amount'],
        :reference => gateway_callback_params['transactionRef']
      }
    else
      {
        :success => false,
        :error => (case gateway_callback_params['responseCode']
          when 207
          :payment_refused
          when 221
          :wrong_cvv
        )
      }
    end

  end

end
```


## Error Codes

TODO ...


## Deployment

Install the `gem-release` gem 

[documentation](http://github.com/svenfuchs/gem-release)

`gem bump`

`gem tag`

`gem release`


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
