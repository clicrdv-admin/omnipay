module Omnipay

  # Base adapter class
  # Inherited by specific implementations
  class Adapter

    # Handle adapter and payment configuration
    # Can be defined
    # - at the class level
    # - at the adapter initialization
    # - at the payment redirection (only payment config)
    # Adapter config is mandatory
    # Payment config is not, but extra fields are

    ConfigField = Struct.new(:explaination, :value, :mandatory)

    DEFAULT_ADAPTER_CONFIG = {
      :sandbox => ConfigField.new('when enabled, the payment are not actually withdrawn', true, nil)
    }

    DEFAULT_PAYMENT_CONFIG = {
      :amount       => ConfigField.new('The amount (in cents) to pay', nil, true),
      :reference    => ConfigField.new('The local reference of the payment', nil, true),
      :currency     => ConfigField.new('The ISO 4217 code for the currency to use', 'USD', true),
      :locale       => ConfigField.new('The ISO 639-1 locale code for the payment page', 'en', true),
      :title        => ConfigField.new('The title to display on the payment page', nil, false),
      :description  => ConfigField.new('A description to display on the payment page', nil, false),
      :template_url => ConfigField.new('The url for the template to use on the payment page', nil, false)
    }


    # ========================
    # Setup the adapter config
    # ========================

    # Accessor to the adapter config
    def self.adapter_config
      @adapter_config ||= Omnipay::Helpers.deep_dup(DEFAULT_ADAPTER_CONFIG)
    end

    # Add a new config field to the adapter.
    # Is mandatory and unfilled. 
    # If default value or optional => should be a payment config
    def self.config(name, explaination)
      adapter_config[name] = ConfigField.new(explaination, nil, true)
    end


    # ====================================
    # Setup the payment redirection config
    # ====================================

    # Accessor to the payment config
    def self.payment_config
      @payment_config ||= Omnipay::Helpers.deep_dup(DEFAULT_PAYMENT_CONFIG)
    end

    # Add a new field to the payment config
    # Options are :mandatory (default false) and :default (default nil)
    def self.custom_payment_param(name, explaination, opts = {})
      if payment_config.has_key?(name)
        raise ArgumentError, "Cannot add custom payment param #{name}, as it already exists and is : #{payment_config[name].explaination}"
      end
      payment_config[name] = ConfigField.new(explaination, opts[:default], !!opts[:mandatory])
    end

    # Setup default values for existing payment params
    def self.default_payment_params(default_values)
      default_values.each do |name, default_value|
        payment_config[name] && ( payment_config[name].value = default_value )
      end
    end


    # ===================
    # Setup if IPN or not
    # ===================

    def self.enable_ipn
      @ipn_enabled = true
    end

    def self.ipn?
      !!@ipn_enabled
    end


    # =============================
    # Actual adapter instance logic
    # =============================

    def initialize(config = {})
      payment_config = config.delete(:payment)

      @adapter_config = build_adapter_config(config)
      @payment_config = build_payment_config(payment_config)
    end


    # Config easy readers
    # from : {:foo => ConfigField(..., value='bar')}
    # to   : config.foo # => 'bar'
    def config
      @config ||= OpenStruct.new(Hash[@adapter_config.map{|name, config_field| [name, config_field.value]}])
    end

    def default_payment_params
      @default_payment_params ||= OpenStruct.new(Hash[@payment_config.map{|name, config_field| [name, config_field.value]}])
    end


    # ================
    # Public interface
    # ================

    def request_phase(params, ipn_url, callback_url)
      payment_params = Omnipay::Helpers.deep_dup(@payment_config)

      # Merge params with default payment config
      params.each do |name, value|
        payment_params[name] && payment_params[name].value = value
      end

      # Validate payment params
      payment_params.each do |name, config_field|
        if config_field.mandatory && config_field.value.nil?
          raise ArgumentError, "Mandatory payment parameter #{name} is not defined. It is supposed to be #{config_field.explaination}"          
        end
      end

      # {name => config_field} to OpenStruct(name => value)
      payment_params = OpenStruct.new(
        Hash[ payment_params.map{|name, config_field| [name, config_field.value]} ]
      )

      # Forward to the right method (redirection_with_ipn or redirection)
      if self.class.ipn?
        return payment_page_redirection_ipn(payment_params, ipn_url, callback_url)
      else
        return payment_page_redirection(payment_params, callback_url)
      end
    end


    def ipn_hash(request)
      request = Rack::Request.new(request.env.dup)
      return validate_payment_notification(request)
    end


    def callback_hash(request)
      request = Rack::Request.new(request.env.dup)
      return validate_callback_status(request)
    end


    # ===============================
    # Logic to redefine in subclasses
    # ===============================

    def payment_page_redirection(amount, reference, callback_url, params)      
      raise NoMethodError, "To redefine in adapter implementation"
    end

    def payment_page_ipn_redirection(amount, reference, callback_url, ipn_url, params)
      raise NoMethodError, "To redefine in adapter implementation"
    end


    def validate_payment_notification(request)
      raise NoMethodError, "To redefine in adapter implementation"
    end


    def validate_callback_status(request)
      raise NoMethodError, "To redefine in adapter implementation"
    end


    protected

    # ==========================
    # Helpers to format response
    # ==========================

    def payment_error(message)
      status_error(message)
    end

    def payment_failed(reference, reason)
      status_failed(reason).merge(
        :reference => reference
      )
    end

    def payment_canceled(reference)
      status_canceled.merge(
        :reference => reference
      )
    end

    def payment_successful(reference, transaction_id, amount)
      status_successful.merge(
        :amount => amount,
        :transaction_id => transaction_id,
        :reference => reference 
      )
    end

    def payment_status_changed(reference, transaction_id, status)
      {
        :reference => reference,
        :transaction_id => transaction_id,
        :status => status 
      }
    end

    def status_error(message = '')
      {:success => false, :status => Omnipay::INVALID_RESPONSE, :error_message => message}
    end

    def status_failed(message = '')
      {:success => false, :status => Omnipay::PAYMENT_REFUSED, :error_message => message}
    end

    def status_canceled
      {:success => false, :status => Omnipay::CANCELATION}
    end

    def status_successful
      {:success => true,  :status => Omnipay::SUCCESS}
    end


    private

    # Build the instance adapter config from the class one and a hash of value overrides
    def build_adapter_config(overrides)
      # Clone the default config
      adapter_config = Omnipay::Helpers.deep_dup(self.class.adapter_config)

      # Override its values
      overrides.each do |name, value|
        next unless adapter_config.has_key? name
        adapter_config[name].value = value
      end

      # Validate it
      adapter_config.each do |name, config_field|
        if config_field.mandatory && config_field.value == nil
          raise ArgumentError, "Mandatory config field #{name} is not defined. It is supposed to be #{config_field.explaination}"
        end
      end

      return adapter_config
    end


    # Build the instance payment config from the class one and a hash of value overrides
    def build_payment_config(overrides)
      overrides ||= {} # Nil can be passed as an argument

      # Clone the default config
      payment_config = Omnipay::Helpers.deep_dup(self.class.payment_config)

      # Override its values
      overrides.each do |name, value|
        next unless payment_config.has_key? name
        payment_config[name].value = value
      end

      # No validation, done at the redirection time
      return payment_config
    end

  end

end