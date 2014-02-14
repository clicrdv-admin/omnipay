# Omnipay

[![Build Status](https://travis-ci.org/clicrdv/omnipay.png?branch=master)](https://travis-ci.org/clicrdv/omnipay) [![Coverage Status](https://coveralls.io/repos/clicrdv/omnipay/badge.png)](https://coveralls.io/r/clicrdv/omnipay) [![Code Climate](https://codeclimate.com/github/clicrdv/omnipay.png)](https://codeclimate.com/github/clicrdv/omnipay)

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

You will also need to setup its payment gateways

```ruby
# config/initializers/omnipay.rb

require 'omnipay/adapters/mangopay'

Omnipay.use_gateway( 
  # The uid is an unique identifier which will be used to generate the callback url : 
  # - GET /pay/:uid/callback -> will be visited by the user after its payment is processed
  :uid      => 'my-payment-gateway',
  
  # The payment gateway you wish to map under this urls. 
  :adapter  => Omnipay::Adapters::Mangopay,

  # The gateway configuration (depends on the chosen adapter).
  :config   => {
    :client_id         => "your-client-id",
    :client_passphrase => "your-secret-passphrase",
    :wallet_id         => "the-id-of-the-wallet-to-credit"
  }
)
```

You then need to add the middleware which will process the callback responses :

```ruby
# config/application.rb

Rails.application.configure do |config|

  # [...]

  config.middleware.use Omnipay::Middleware

end
```

### Redirect the user to the payment page

A redirection can be called in a controller to the payment page. The mandatory argument is the amount in cents to pay.

```ruby
# app/controllers/orders_controller.rb
def pay
  total_with_taxes = current_order.total_with_taxes
  session[:current_order] = @order.id
  redirect_to_payment 'my-payment-gateway', :amount => (total_with_taxes*100) and return
end
```

If you are not using rails, you can get the raw Rack::Response to return for the redirection to occur :
```ruby
Omnipay.gateways.find('my-payment-gateway').payment_redirection(:host => 'http://your.host.tld', :amount => amount)
```


### Handle the returns from the payment gateway

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
    current_order.set_paid!
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

If the payment was **not successful**, the following values are present :

 - `:error (symbol)` : the reason why the payment was not successful. Can have one of the following values :
     - `Omnipay::CANCELED` : the payment was canceled by the user.
     - `Omnipay::PAYMENT_REFUSED` : the payment was refused on the gateway side.
     - `Omnipay::INVALID_RESPONSE` : there was an error parsing the response from the gateway.
     - `Omnipay::WRONG_SIGNATURE` : the response seemed good and successful, but didn't match the former redirection (e.g : the amounts are not matching).
 - `:error_message (string)` : a more detailed trace of the context of the error


In any case, should you need to investigate further, there is the following value :

 - `:raw (hash)` : the entirety of the parameters send by the gateway in its response



## More features

### Optional parameters when calling the payment url

You may specify these parameters when calling the payment redirection. They may or may not be supported, and other may be available. Check your adapter documentation.

- `:transaction_id` : the payment reference to be used in the gateway
- `:title` : a title to display on the payment page, referencing what is paid
- `:locale` : the language to use in the payment process (ISO 639-1)


### Dynamic gateway configuration

The initializer is a static file only loaded at the applications' start. You may however run a SAAS where multiple users can each integrate their gateway. A way to handle this is to use a block in the gateway configuration :

```ruby
# config/initializer/omnipay.rb

# Using this configuration, each call to /pay/:shop_id will look 
# for a shop having this id, and will forward to its payment page. 
# The callbacks will be on `/pay/:shop_id/callback`

Omnipay.use_gateway do |uid|

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


## Add a new adapter
[Article on the wiki](https://github.com/clicrdv/omnipay/wiki/Implement-a-new-adapter)


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

