module Omnipay

  module ActionController
    module Helpers

      def redirect_to_payment(uid, opts = {})
        app_host = "#{request.scheme}://#{request.host_with_port}"
        gateway = Omnipay.gateways.find(uid)
        if gateway
          rack_response = gateway.payment_redirection(opts.merge(:host => app_host))

          self.response_body = rack_response.body
          self.status = rack_response.status
          self.response.headers = rack_response.headers

          return true
        else
          raise ArgumentError.new("Omnipay gateway '#{uid}' not found")
        end
      end

    end
  end

  # Custom helpers for rails applications
  # Define the method : <b>+ActionController#redirect_to_payment(uid, opts={})+</b>
  # - <b>+uid+</b> : the gateway's uid
  # - <b>+opts+</b> : the options expected by Gateway#payment_redirection. The host is automatically determined, but the <b>+amount+</b> in cents, and other mandatory options depending on the adapter, have to be specified.
  # Called in a controller, this method redirects the visitor to the payment provider.
  class Railtie < Rails::Railtie

    initializer "omnipay.configure_rails_initialization" do

     ActiveSupport.on_load :action_controller do
        include Omnipay::ActionController::Helpers
      end      

    end

  end
end