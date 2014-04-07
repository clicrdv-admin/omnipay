# Edge
* Gateway#payment_redirection expects an option named :base_uri instead of :host. Sending :host is supported, but will print a deprecation message
* You can now define a default value for this option in `Omnipay.configuration.base_uri`

# 0.1.0

* The request phase is done in the controller instead of via a url
* The host must be given as an argument to the request phase
* The adapter's signatures changed :
  * `#initialize : (callback_url, params) => (params)`
  * `#request_phase : (amount, params) => (amount, callback_url, params)`

* The middleware configuration changed. There is now only one middleware `Omnipay::Middleware`
* The gateways configuration changed. They are now defined via `Omnipay::use_gateway` The arguments didnt't change
* The Omnipay `secret_token` configuration was removed
* The Omnipay `base_path` configuration was added. It defaults to '/pay' and allows to customize the base path for the callback urls.


# 0.0.4

Lowered rack dependency : 1.5 to 1.4.5+


# 0.0.3

Ruby 1.8.7 compatibility


# 0.0.2

Source code documentation improved

## Bug Fixes
* POST redirections now are compatible with turbolinks


# 0.0.1

First release