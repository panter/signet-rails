require 'signet/oauth_2'
require 'signet/rails'
require 'rack/utils'

module Signet
  module Rails

    class Handler # this is the Rack middleware - it responds to call(env)

      # we are initialized here with the app that is above us in the stack
      # i.e. where we relay the request (unless handled)
      def initialize(app, opts = {}, auth_opts = {}, &block)
        @app = app
        @options = opts
        @auth_options = auth_opts
      end

      # The Rack entry point. This method gets called from the Rack middleware below us 
      # in the stack. If we need to handle the request we respond else we pass the request
      # up the stack and then persist the oauth tokens 
      def call(env)

        # Make this Handler available to the env
        # TODO rework this to use singleton?
        env["signet.#{options[:name]}"] = self

        status, headers, body = nil, nil, nil

        # TODO: better way than a gross if elsif block?
        #
        # There are two requests which we do something with:
        #
        # 1. on_auth_path? - a request to auth against a particular
        # provider. We respond to this by redirecting to the provider's
        # authorization_uri, translating appropriate options
        # 
        # 2. on_auth_callback_path? - the callback from the provider's
        # authorization_uri (ultimately) which will have an authorisation
        # code. We respond to this by extracting the code, getting an 
        # access token (and response token), persisting said tokens then
        # forwarding the request to the next Rack app up the stack. When
        # the Rack app above us responds we parse the env to extract 
        # the potentially modified TODO finish
        if on_auth_path?(env)
          status, headers, body = create_auth_redirect_response env
        else
          if on_auth_callback_path?(env)
            process_auth_callback env
          end

          status, headers, body = @app.call(env)

          # did we create an instance during the process of @app.call?
          # if so persist
          instance = env["signet.#{options[:name]}.instance"]
          if instance
            save_token_state instance, instance.client
            instance.persist
          end
        end

        # notice here that only on_auth_path?(env) will ensure we respond
        # otherwise status will be nil
        [status, headers, body]
      end


      # Take a persistence wrapper object and a Signet::OAuth2Client
      # and transfer the :persist_attrs to the persistence wrapper
      def save_token_state wrapper, client
        if not wrapper.credentials.respond_to?(options[:storage_attr])
          raise "Persistence object does not support the storage attribute #{options[:storage_attr]}"
        end

        if (store_hash = wrapper.credentials.method(options[:storage_attr]).call).nil?
          store_hash = wrapper.credentials.method("#{options[:storage_attr]}=").call({})
        end

        # not nice... the wrapper.credentials.changed? will only be triggered if we clone the hash
        # Is this a bug? https://github.com/rails/rails/issues/11968
        # TODO: check if there is a better solution
        store_hash = store_hash.clone

        for i in options[:persist_attrs]
          if client.respond_to?(i)
            # only transfer the value if it is non-nil
            store_hash[i.to_s] = client.method(i).call unless client.method(i).call.nil?
          end
        end

        wrapper.credentials.method("#{options[:storage_attr]}=").call(store_hash)
      end

      # The inverse of save_token_state
      def load_token_state wrapper, client
        if not wrapper.credentials.respond_to?(options[:storage_attr])
          raise "Persistence object does not support the storage attribute #{options[:storage_attr]}"
        end

        if not (store_hash = wrapper.credentials.method(options[:storage_attr]).call).nil?
          for i in options[:persist_attrs]
            if client.respond_to?(i.to_s+'=')
              client.method(i.to_s+'=').call(store_hash[i.to_s])
            end
          end
        end
      end

      # TODO the code separation here is not great. Refactoring so that 
      # we don't have to publicly expose our options would be best
      def options
        # TODO: Signet does not dup the options that are passed to it...
        # hence 'our' value would be corrupted were it not dup'ed here
        @options.dup
      end

      def auth_options(env)
        # TODO: Signet does not dup the options that are passed to it...
        # hence 'our' value would be corrupted were it not dup'ed here
        ret = @auth_options.dup

        # the redirect uri can't be set at config time (when we mount the
        # Rack middleware) - it must be done at request time. TODO really?
        # Build the redirect_uri from the env in which we are called
        unless ret.include? :redirect_uri and not ret[:redirect_uri].nil?
          req = Rack::Request.new env
          scheme = req.ssl? ? 'https' : 'http'
          ret[:redirect_uri] = "#{scheme}://#{req.host_with_port}/signet/#{options[:name]}/auth_callback"
        end
        ret
      end
      
      private

      def create_auth_redirect_response(env)
        # we build the redirect uri from an OAuth2 client
        # clearly we don't need token state loaded... indeed
        # it probably doesn't exist for this user if we're being
        # asked to auth
        client = Factory.create_from_env(options[:name], env, load_token: false)

        response = Rack::Response.new

        # if it needs reiterating... we can't set the redirect uri 
        # at config time because we don't have certain config
        # available like server_name etc. This is available at request
        # time (i.e. now)
        redirect_uri = client.authorization_uri(auth_options(env)).to_s
        response.redirect(redirect_uri)

        # will return status, headers, body
        response.finish
      end

      def process_auth_callback(env)

        client = Factory.create_from_env options[:name], env, load_token: false
        query_string_params = Rack::Utils.parse_query(env['QUERY_STRING'])
        client.code = query_string_params['code']
        client.redirect_uri = auth_options(env)[:redirect_uri]

        raise ArgumentError, 'Missing authorization code in auth_callback' unless client.code

        # TODO is there a better way of passing in a connection for testing?
        client.fetch_access_token!({connection: options[:connection]})

        if options[:handle_auth_callback]
          user_oauth_credentials = options[:extract_credentials_from_env_by_oauth_id].call env, client, client.decoded_id_token['sub']
          save_token_state user_oauth_credentials, client
          user_oauth_credentials.persist
          env["signet.#{options[:name]}.persistence_obj"] = user_oauth_credentials.credentials
        else
          env["signet.#{options[:name]}.auth_client"] = client
        end
      end

      def on_auth_path?(env)
        "/signet/#{options[:name]}/auth" == env['PATH_INFO'] && 'GET' == env['REQUEST_METHOD']
      end

      def on_auth_callback_path?(env)
        "/signet/#{options[:name]}/auth_callback" == env['PATH_INFO'] && 'GET' == env['REQUEST_METHOD']
      end
    end
  end
end
