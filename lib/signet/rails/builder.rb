require 'signet/rails'
require 'active_support/core_ext/string'

module Signet
  module Rails

    # The overall structure:
    #
    # Builder - used to create OAuth2 providers. These providers are Rack middleware
    # and instances of Handler. A Builder can create multiple providers. See initialize
    # def below
    #
    # Handler - Rack middleware that represents and instance of an OAuth2 provider
    #
    # Factory - a dumb factory that takes an env and returns an instance of 
    # a named Signet::OAuth2::Client
    class Builder < ::Rack::Builder

      class << self
        attr_accessor :default_options 
      end

      # User can set default_options for all providers via this static accessor 
      #
      # TODO not very pretty.... can we refactor?
      Builder.default_options = {}

      # Options accepted by this Builder
      #
      # TODO obviously we can find a better way of packaging defaults e.g. Google setup
      OPTIONS = {
        # What returned OAuth2 values are persisted?
        #
        # Google config is the default. See:
        #
        # https://developers.google.com/accounts/docs/OAuth2WebServer#handlingtheresponse
        #
        # specifically, the section that deals with the 'shape' of the response to a request
        # for an access token
        persist_attrs: [:refresh_token, :access_token, :expires_in],

        # What is the name of this provider? It will be used in the auth and auth_callback urls:
        #
        # /signet/google/auth - to authorise a user
        # /signet/google/auth_callback - to handle the response from the OAuth2 provider
        name: :google,

        # What type is this provider? Is it a login-based OAuth2 adapter? If so, the callback 
        # will be used to identify a user and create one if necessary, specifically the uid
        # in the response will be used as a secondary key in the user table 
        #
        # Options: 
        #       :login - as described above
        #       :webserver - the expectation will be that 
        type: :webserver,

        # TODO need to define this better
        storage_attr: :signet,

        # TODO: see https://developers.google.com/accounts/docs/OAuth2Login#authenticationuriparameters
        approval_prompt: 'auto',
        authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
        token_credential_uri: 'https://accounts.google.com/o/oauth2/token',

        # whether we handle the persistence of the auth callback or simply pass-through
        handle_auth_callback: true,

        # These need to be set either as default_options or per provider
        client_id: nil,
        client_secret: nil,

        # redirect_uri can be set otherwise it will default based on the Rack env
        redirect_uri: nil,

        # A method which takes a Rack env and a Signet::OAuth2::Client (minus
        # credentials) and returns a persistence wrapped object TODO finish
        extract_credentials_from_env: nil,

        # TODO
        extract_credentials_from_env_by_oauth_id: nil,

        # What connection object to use (Signet::OAuth2::Client will default to a Faraday default if 
        # this is not set)
        connection: nil,
      }

      def self.set_default_options(opts = {})
        Builder.default_options = opts.symbolize_keys
      end

      # Standard ::Rack::Builder initialize
      # 
      # It is expected that after creating an instance of Signet::Rails::Builder one will call
      # provider at least one in order to add an instance of the Handler Rack middleware to the
      # Rack. e.g.
      #
      # class FakeApp < Sinatra::Base
      #   get "/" do
      #     "Hello"
      #   end
      # end
      #
      # Signet::Rails::Builder.new FakeApp.new do
      #   provider name: :google...
      # end
      def initialize(app, &block)
        super
      end

      # Called when constructing the Rack stack
      def call(env)
        to_app.call(env)
      end

      # add an OAuth2 Handler to the initialize'ed app, defined by options
      def provider(opts = {}, &block)
        combined_options = OPTIONS.merge \
          Builder.default_options.merge \
          opts.symbolize_keys

        provider_name = combined_options[:name]

        # the following defaults depend on other defaults... hence are initialised here
        # If customising either, clearly a similar effect can be achieved in the calling
        # code or by passing in a &block which get invoked in Rack space (see the use call
        # below)

        # minor efficiency gain... only load the ActiveRecord persistance wrapper if the 
        # user hasn't set either extract_credentials_from_env or extract_credentials_from_env_by_oauth_id

        unless combined_options[:extract_credentials_from_env] and combined_options[:extract_credentials_from_env_by_oauth_id]
          require 'active_record'
          require 'signet/rails/wrappers/active_record' 
        end

        # TODO document
        # Deliberately left verbose to give an example (although the code that follows
        # could hardly be desribed as example) of what's required
        combined_options[:extract_credentials_from_env] ||= lambda do |env, client|
          oac = nil
          session = env['rack.session']
          if !!session && !!session[:user_id]
            begin
              u = ::User.find(session[:user_id])
              oac = u.o_auth2_credentials.where(name: combined_options[:name]).first
            rescue ::ActiveRecord::RecordNotFound => e
            end
          end
          Signet::Rails::Wrappers::ActiveRecord.new oac, client
        end

        combined_options[:extract_credentials_from_env_by_oauth_id] ||= lambda do |env, client, id|
          oac = nil
          begin
            u = nil
            if combined_options[:type] == :login
              u = ::User.where(uid: combined_options[:name].to_s + "_" + id).first_or_create
            else
              session = env['rack.session']
              if !!session && !!session[:user_id]
                begin
                  u = ::User.find(session[:user_id])
                rescue ::ActiveRecord::RecordNotFound => e
                end
              else
                raise "Expected to be able to find user in session"
              end
            end

            oac = u.o_auth2_credentials.where(name: combined_options[:name]).first_or_initialize

          rescue ::ActiveRecord::RecordNotFound => e
            # TODO 
          end

          Signet::Rails::Wrappers::ActiveRecord.new oac, client
        end

        # TODO: check here we have the basics?

        # TODO: better auth_options split?
        auth_option_keys = [:prompt, :redirect_uri, :approval_prompt, :client_id, :access_type]
        auth_options = combined_options.slice(*auth_option_keys)

        # verify we have certain required values
        if combined_options[:type] == :login
          raise ArgumentError, 'Client id is required for a type: :login provider' unless auth_options[:client_id] and auth_options[:client_id].is_a? String 
          raise ArgumentError, 'Scope is required' unless combined_options[:scope] 
          # TODO error handling for scope: must be a string or array of strings
        end

        use Signet::Rails::Handler, combined_options, auth_options, &block
      end

    end
  end
end
