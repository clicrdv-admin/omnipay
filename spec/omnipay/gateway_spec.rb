require 'spec_helper'


# A sample omnipay gateway
class MyGateway
  include Omnipay::Gateway
end


describe Omnipay::Gateway do

  # A sample app, only 404s
  let(:app){ lambda{|env| [404, {}, 'App : Not Found']} }

  # The same app with the sample gateway plugged under '/pay/my_gateway'
  let(:gateway_uid){'my_gateway'}
  let(:app_with_middleware){MyGateway.new(app, gateway_uid)}
  let(:browser){Rack::Test::Session.new(Rack::MockSession.new(app_with_middleware))}

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
        MyGateway
          .any_instance
          .should_receive(:request_phase)
          .with(1295)
          .and_return(['GET', 'http://host.tld', {}])

        browser.get '/pay/my_gateway?amount=1295'

      end


      it 'should respond with a redirect for GET requests' do

        # Simulate a working gateway implementation
        MyGateway
          .any_instance
          .stub(:request_phase)
          .and_return([
            'GET', 
            'https://payment.gateway.tld', 
            {
              :amount => 1295,
              :signature => "25abb63df816dc57fd0134056f20b69d9d81a5dd583c4b3416c7043becd33a2e70cc812614027f8180b77cdcd04020c42ac3eb5e38849ab0b96dd1f264731a6a"
            }
          ])

        browser.get '/pay/my_gateway?amount=1295'

        browser.last_response.redirect?.should be_true
        browser.last_response.body.should == ""
        browser.last_response['Location'].should == 'https://payment.gateway.tld?amount=1295&signature=25abb63df816dc57fd0134056f20b69d9d81a5dd583c4b3416c7043becd33a2e70cc812614027f8180b77cdcd04020c42ac3eb5e38849ab0b96dd1f264731a6a'

      end


      it 'should respond with an autosubmitted html form for POST requests' do

        # Simulate a working gateway implementation
        MyGateway
          .any_instance
          .stub(:request_phase)
          .and_return([
            'POST', 
            'https://payment.gateway.tld', 
            {
              :amount => 1295,
              :ref    => "REF-123",
              :sig    => "MTI5NQ=="
            }
          ])

        browser.get '/pay/my_gateway?amount=1295'

        browser.last_response.status.should == 200
        browser.last_response.body.should == File.read(File.join(File.dirname(__FILE__), '..', '..', 'spec/fixtures/sample_post_response.html'))

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
        MyGateway
          .any_instance
          .stub(:callback_hash)
          .with({
            "amount" => "1295",
            "ref" => "REF-123",
            "sig" => "MTI5NQ"
          })
          .and_return({
            :success => true,
            :amount => 1295,
            :reference => 'REF-123',
          })


        browser.get '/pay/my_gateway/callback?amount=1295&ref=REF-123&sig=MTI5NQ'

        # The request should have the processed response in its environment
        browser.last_request.env['omnipay.response'].should == {
          :success => true,
          :amount => 1295,
          :reference => 'REF-123',
          :raw => {
            "amount" => "1295",
            "ref" => "REF-123",
            "sig" => "MTI5NQ"
          }
        }

        # It should then have been redirected to the app
        browser.last_response.status.should == 404
        browser.last_response.body.should == 'App : Not Found'

      end

    end

  end


  describe 'context storing' do

    before(:each) do

      # Simulate a working gateway implementation
      MyGateway.any_instance
        .stub(:request_phase)
        .and_return(['GET', 'http://host.tld', {}])

      MyGateway.any_instance
        .stub(:callback_hash)
        .and_return({
          :success => true,
          :amount => 1095,
          :reference => 'REF-123',
        })
    end

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
      browser.last_request.env['omnipay.response'][:context].should == nil
    end

  end



  describe 'configuration' do

    pending

  end


end