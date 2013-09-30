require 'spec_helper'
require 'signet/rails'
require 'rack/test'
require 'sinatra/base'

class FakeApp < Sinatra::Base
  get "/" do
    "Hello"
  end
end

module Signet
  module Rails
    describe 'default settings' do
      include Rack::Test::Methods

      def app
        Builder.new FakeApp.new
      end

      it 'says hello' do
        get '/'
        expect(last_response).to be_ok
      end
    end
  end
end
