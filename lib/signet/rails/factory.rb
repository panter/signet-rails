require 'signet/oauth_2/client'

module Signet
  module Rails

    # Factory for creating instances of the Signet::OAuth2::Client or extracting 
    # them from an existing env
    #
    # There are two use cases:
    #
    # 1. This is called from within the user app (e.g. Rails) - in this case we 
    # extract an existing instance from the env provided by the Handler Rack 
    # middleware. We then load the persisted token information (if there is any)
    # and set that on the client. The client is then returned.
    #
    #   name: the provider name
    #   env: the env available to the caller e.g. request.env in rails
    #   options: left blank
    #
    # 2. This is called from within the Handler Rack Middleware (as described above)
    # In this case, we have have to construct the client instance from the Handler
    # options (previously configured)
    #
    #   name: the provider name
    #   env: the env available to the caller e.g. request.env in rails, the env
    #        from the previous Rack middleware in the case of a Handler
    #   options: load_token: false
    #
    # In either case, we can rely on env["signet.<HANDLER_NAME>"] being set at the 
    # point of calling
    class Factory

      def self.create_from_env(name, env, options = { load_token: true })
        # TODO: checking of env not pretty...thread safe? best approach? 
        
        # If there is already an instance in this env, return it
        env["signet.#{name}.instance"] ||
        # else create one from the handler
        create_client_from_handler(env["signet.#{name}"], name, env, options)
      end

      private

      def self.create_client_from_handler(handler, name, env, options)
        # There should be a handler set at this stage... big problems otherwise
        raise ArgumentError, "Unable to find signet handler named #{name}" unless handler

        client = Signet::OAuth2::Client.new handler.options

        # at this point we have satisfied use case 2

        # here is use case 1; the client we have created thus far is blank as far
        # as access/refresh tokens are concerned. If we are calling from a user app
        # then we want that loaded (for the current user)
        if options[:load_token]
          obj = handler.options[:extract_credentials_from_env].call env, client
          handler.load_token_state obj, client

          # store the created instance in the env for future use/persistance 
          env["signet.#{name}.instance"] = obj
        end

        client
      end
    end
  end
end

