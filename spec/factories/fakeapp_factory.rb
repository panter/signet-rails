class FakeApp < Sinatra::Base
  attr_accessor :callback
  get '/' do
    @callback.call env if @callback
    'Root'
  end
  get '/signet/google/auth_callback' do
    @callback.call env if @callback
    'Auth Callback'
  end
end
