require 'spec_helper'


# A sample omnipay adapter
class GatewayAdapter

  def initialize(callback_url, config)
    @config = config
  end

  def request_phase(amount, params = {})
    ['GET', 'http://host.tld', {:amount => amount, :signature => "25abb63df816dc57"}, "transaction_id"]
  end

  def callback_hash(params)
    {
      :success   => true,
      :amount    => params[:amount].to_i,
      :transaction_id => params[:ref]
    }
  end

end


describe Omnipay::Gateway do

  # A sample app, only 404s
  let(:app){ lambda{|env| [404, {}, 'App : Not Found']} }

  # The same app with the sample gateway plugged under '/pay/my_gateway'
  let(:gateway_uid){'my_gateway'}
  let(:app_with_middleware){Omnipay::Gateway.new(app, :adapter => GatewayAdapter, :uid => gateway_uid)}
  let(:browser){Rack::Test::Session.new(Rack::MockSession.new(app_with_middleware))}

  before(:all) do
    Omnipay.configuration.secret_token = "azerty1234"
  end    

  describe 'middleware interceptor' do

    describe 'request phase' do

      it 'should leave alone requests not matching the gateway\'s request path' do

        %w(/ /foo/bar /pay /pay/other_gateway /pay/my_gateway/inexistant_action).each do |path|
          browser.get path

          browser.last_response.status.should == 404
          browser.last_response.body.should   == 'App : Not Found'
        end

      end


      it 'should not intercept POST requests' do
      
        browser.post '/pay/my_gateway'
        browser.last_response.status.should == 404
        browser.last_response.body.should   == 'App : Not Found'        
      
      end


      it 'should check for the presence of an amount in the request params' do

        expect{
          browser.get('/pay/my_gateway')
        }.to raise_error(ArgumentError, 'No amount specified')

      end


      it 'should intercept requests matching the gateway\'s request path' do

        # It should defer to the gateway for the request path
        GatewayAdapter                    \
          .any_instance                   \
          .should_receive(:request_phase) \
          .with(1295, {})                 \
          .and_return(['GET', 'http://host.tld', {:amount => 1295, :signature => "25abb63df816dc57"}])

        browser.get '/pay/my_gateway?amount=1295'

      end


      it 'should respond with a redirect for GET requests' do

        browser.get '/pay/my_gateway?amount=1295'

        browser.last_response.redirect?.should be_true
        browser.last_response.body.should == ""
        browser.last_response['Location'].should == 'http://host.tld?amount=1295&signature=25abb63df816dc57'

      end


      it 'should respond with an autosubmitted html form for POST requests' do

        GatewayAdapter                    \
          .any_instance                   \
          .should_receive(:request_phase) \
          .with(1295, {})                 \
          .and_return(['POST', 'http://host.tld', {:amount => 1295, :signature => "25abb63df816dc57"}])

        browser.get '/pay/my_gateway?amount=1295'

        browser.last_response.status.should == 200
        browser.last_response['Content-Type'].should == 'text/html;charset=utf-8'
        browser.last_response.body.should == File.read(File.join(File.dirname(__FILE__), '..', '..', 'spec/fixtures/sample_post_response.html'))

      end


      it "should send the GET params in the request phase" do

        GatewayAdapter                    \
          .any_instance                   \
          .should_receive(:request_phase) \
          .with(1295, {:foo => 'bar'})    \
          .and_return(['GET', 'http://host.tld', {:amount => 1295, :signature => "25abb63df816dc57"}])

        browser.get '/pay/my_gateway?amount=1295&foo=bar'

      end


      it "should generate the callback url and send it to the adapter at initialisation" do

        GatewayAdapter.should_receive(:new).with("http://example.org/pay/my_gateway/callback", {}).at_least(:once)

        browser.get '/pay/my_gateway?amount=1295&foo=bar'

      end

    end


    describe 'callback phase' do

      it 'should leave alone requests not matching the gateway\'s callback path' do

        %w(/ /callback /pay/callback /pay/other_gateway/callback /pay/my_gateway/callback/other).each do |path|
          browser.get path

          browser.last_response.status.should == 404
          browser.last_response.body.should   == 'App : Not Found'
        end

      end


      it 'should intercept requests matching the gateway\'s callback path' do

        # Simulate a working gateway implementation
        GatewayAdapter          \
          .any_instance         \
          .stub(:request_phase) \
          .with(1295, {})       \
          .and_return([
            'GET',
            'my_url',
            {},
            'REF-123'
          ])                    \
          .stub(:callback_hash) \
          .with({
            :amount => "1295",
            :ref => "REF-123",
            :sig => "MTI5NQ"
          })                    \
          .and_return({
            :success => true,
            :amount => 1295,
            :transaction_id => 'REF-123',
          })


        # First call the request phase, to have a valid signature
        browser.get '/pay/my_gateway?amount=1295'

        browser.last_request.session['omnipay.signature']['my_gateway'].should == 'FtXZhYwdWCWG48OIarwmCOqOYzw%3D%0A'

        browser.get '/pay/my_gateway/callback?amount=1295&ref=REF-123&sig=MTI5NQ', {}, {'rack.session' => {'omnipay.signature' => {'my_gateway' => 'FtXZhYwdWCWG48OIarwmCOqOYzw%3D%0A'}}}

        # The request should have the processed response in its environment
        browser.last_request.env['omnipay.response'].should == {
          :success => true,
          :amount => 1295,
          :transaction_id => 'REF-123',
          :context => {},
          :raw => {
            :amount => "1295",
            :ref => "REF-123",
            :sig => "MTI5NQ"
          }
        }

        # It should then have been redirected to the app
        browser.last_response.status.should == 404
        browser.last_response.body.should == 'App : Not Found'

      end

    end

  end


  describe 'context storing' do

    let(:context){ {'foo' => 'bar', 'baz' => 'boo'} }

    it 'should store a given "context" hash' do
      browser.get '/pay/my_gateway', :amount => 1295, :context => context
      browser.last_request.session['omnipay.context'].should == {'my_gateway' => context}
    end

    it 'should retrieve the hash and put it in the callback' do
      browser.get '/pay/my_gateway/callback', {}, {'rack.session' => {'omnipay.context' => {'my_gateway' => context}}}
      browser.last_request.env['omnipay.response'][:context].should == context
      browser.last_request.env['rack.session']['omnipay.context'].should == {}
    end

    it 'should namespace the hash for each gateway' do
      browser.get '/pay/my_gateway/callback', {}, {'rack.session' => {'omnipay.context' => {'another_gateway' => context}}}
      browser.last_request.env['omnipay.response'][:context].should == {}
    end

  end



  describe 'configuration' do

    class AdapterWithConfig

      def initialize(callback_url, config)
        @public_key = config[:public_key]
      end

      def request_phase(amount, params={})
        ['GET', 'http://host.tld', {:public_key => @public_key}]
      end

    end


    describe 'with static configuration' do

      let(:app_with_middleware){
        Omnipay::Gateway.new(
          app, 
          :adapter => AdapterWithConfig, 
          :uid => 'gateway_with_config', 
          :config => {:public_key => "public_key"}
        )
      }

      let(:browser){Rack::Test::Session.new(Rack::MockSession.new(app_with_middleware))}


      it 'should initialize the adapter with the given config' do

        browser.get '/pay/gateway_with_config', :amount => 1295

        browser.last_response['Location'].should == 'http://host.tld?public_key=public_key'
      end

    end


    describe 'with runtime configuration' do

      let(:app_with_dynamic_middleware){
        Omnipay::Gateway.new(app) do |uid|
          if uid != "wrong_uid"
            {
              :adapter => AdapterWithConfig, 
              :config => {:public_key => "public_key_#{uid}"}
            }
          end
        end
      }

      let(:browser){Rack::Test::Session.new(Rack::MockSession.new(app_with_dynamic_middleware))}


      it 'should ignore non matching endpoints' do
        browser.get '/pay/wrong_uid'

        browser.last_response.status.should == 404
        browser.last_response.body.should   == 'App : Not Found'
      end


      it 'should allow wildcard adapters with dynamic config' do
        browser.get '/pay/uid1?amount=1295'
        browser.last_response['Location'].should == 'http://host.tld?public_key=public_key_uid1'

        browser.get '/pay/uid2?amount=1295'
        browser.last_response['Location'].should == 'http://host.tld?public_key=public_key_uid2'
      end

    end

  end

end