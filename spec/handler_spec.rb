require 'spec_helper'

describe Signet::Rails::Handler do

  # lightweight sinatra app for testing 
  # wraps in Rack::Lint and puts the Signet::Rails::Handler in the middleware stack
  def base_app opts = {}
    app_1 = FakeApp.new
    app_2 = Rack::Lint.new app_1
    app_3 = Signet::Rails::Builder.new app_2 do
      provider opts
    end
    app_4 = Rack::Lint.new app_3
    app_5 = Rack::Session::Cookie.new app_4, secret: SecureRandom.hex(64)
    app_6 = Rack::Lint.new app_5

    # Sinatra wraps our top app... let's get it back out again
    # for @top
    @base, @top = [app_6, (app_1.instance_variable_get :@instance)]
    @app_env = nil
    @top.callback = lambda do |env|
      @app_env = env
    end
    @req = request @base
    [@base, @top]
  end

  def req_get uri, env_opts = {}
    @req.get uri, env(env_opts)
  end

  def create_login_app opts = {}
    base_app opts.merge({type: :login})
  end

  DEFAULT_ENV = {
    "SERVER_NAME" => "myitcv.org.uk",
    "SERVER_PORT" => "4321"
  }.freeze

  def request app
    req = Rack::MockRequest.new app
  end

  def env opts = {}
    # a slight abuse of options that are passed to Rack::MockRequest.env_for
    # we overload opts to also allow the setting of :cookie
    # This option is stripped out if set and translated into an HTTP_COOKIE 
    # option
    opts = opts.dup
    if opts.include? :cookie
      cookie = if options[:cookie].is_a?(Rack::Response)
                 options[:cookie]["Set-Cookie"]
               else
                 options[:cookie]
               end
      opts.delete :cookie
      opts["HTTP_COOKIE"] = cookie || ""
    end
    e = DEFAULT_ENV.dup.merge opts
  end

  before do
    @faraday = Faraday.new do |builder|
      builder.adapter :test do |stub|
        stub.post('/o/oauth2/token') {
          id_token = {"iss"=>"accounts.google.com", "aud"=>"id", "token_hash"=>"my_token_hash", "at_hash"=>"M0rVHD8aKqJRMwlpkWuvrw", "cid"=>"id", "azp"=>"id", "id"=>"myitcv", "sub"=>"105997489348527668257", "iat"=>12, "exp"=>42}
          resp_body = { "access_token" => "my_access_token", "token_type" => "Bearer", "expires_in" => 1234, "id_token" => JWT.encode(id_token, 'secret'), "refresh_token" => "my_refresh_token" }
          [ 200, {}, JSON.dump(resp_body) ]
        }
      end
    end
  end

  context 'that is login based' do
    context 'with default arguments' do
      it 'should require a string client id' do
        exception = nil
        begin
          create_login_app
        rescue ArgumentError => e
          exception = e
        end
        expect(exception).not_to be_nil
        expect(exception.message).to eq('Client id is required for a type: :login provider')
      end

      it 'should require a scope to be defined' do
        exception = nil
        begin
          create_login_app client_id: 'id'
        rescue ArgumentError => e
          exception = e
        end
        expect(exception).not_to be_nil
        expect(exception.message).to eq('Scope is required')
      end

      # TODO
      it 'should require scope to be a(n array of) string(s)'

      # TODO
      it 'should handle scope strings that contain commas'
      # i.e. it should behave as if an array was passed in

      it 'should handle untrimmed scope strings' do
        create_login_app client_id: 'id', scope: ' test '
        resp = req_get '/signet/google/auth'
        expect(resp.body).to be_empty
        expect(resp.original_headers['Location']).to eq('https://accounts.google.com/o/oauth2/auth?access_type=offline&approval_prompt=auto&client_id=id&redirect_uri=http://myitcv.org.uk:4321/signet/google/auth_callback&response_type=code&scope=test')
      end

      it 'should redirect to google' do
        create_login_app client_id: 'id', scope: 'test'
        resp = req_get '/signet/google/auth'
        expect(resp.body).to be_empty
        expect(resp.original_headers['Location']).to eq('https://accounts.google.com/o/oauth2/auth?access_type=offline&approval_prompt=auto&client_id=id&redirect_uri=http://myitcv.org.uk:4321/signet/google/auth_callback&response_type=code&scope=test')
      end

      it 'should redirect for an auth request'

      it 'errors if rack.session is not available'

      it 'should handle multiple scopes' do
        create_login_app client_id: 'id', scope: ['test','trial']
        resp = req_get '/signet/google/auth'
        expect(resp.body).to be_empty
        expect(resp.original_headers['Location']).to eq('https://accounts.google.com/o/oauth2/auth?access_type=offline&approval_prompt=auto&client_id=id&redirect_uri=http://myitcv.org.uk:4321/signet/google/auth_callback&response_type=code&scope=test%20trial')
      end

      it 'should handle url scopes' do
        create_login_app client_id: 'id', scope: ['https://www.googleapis.com/auth/userinfo.email']
        resp = req_get '/signet/google/auth'
        expect(resp.body).to be_empty
        expect(resp.original_headers['Location']).to eq('https://accounts.google.com/o/oauth2/auth?access_type=offline&approval_prompt=auto&client_id=id&redirect_uri=http://myitcv.org.uk:4321/signet/google/auth_callback&response_type=code&scope=https://www.googleapis.com/auth/userinfo.email')
      end

      it 'should require an auth_code on auth callback' do
        create_login_app client_id: 'id', scope: 'scope'
        exception = nil
        begin
          resp = req_get '/signet/google/auth_callback'
        rescue ArgumentError => e
          exception = e
        end
        expect(exception).not_to be_nil
        expect(exception.message).to eq('Missing authorization code in auth_callback')
      end

      it 'should attempt to get an access_token on auth_callback' do
        create_login_app client_id: 'id', scope: 'scope', connection: @faraday

        # TODO this could be made stronger
        @faraday.app.should_receive(:call).and_call_original
        resp = req_get '/signet/google/auth_callback', params: {code: '123'}
        credentials = @app_env['signet.google.persistence_obj']
        expect(resp.body).to eq('Auth Callback')
        expect(@app_env['signet.google']).to be_a(Signet::Rails::Handler)
        expect(credentials).not_to be_nil
        expect(credentials.signet).not_to be_nil
        expect(credentials.signet['refresh_token']).to eq('my_refresh_token')
      end
    end
  end
  context 'that is google-based' do
    it 'should redirect based on provider name' do
      base, top = base_app name: :google, type: :login, client_id: 'id', client_secret: 456, scope: 'myscope'
      req = request base
      resp = req.get '/signet/google/auth'
    end
  end
  it 'should be google-based'
  it 'should test default options'
  it 'should handle option :handle_auth_callback false'
end

