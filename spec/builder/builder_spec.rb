require 'spec_helper'
require 'signet/rails'
require 'rack/test'
require 'factory_girl'

describe 'signet-rails' do
  include Rack::Test::Methods

  def app
    FactoryGirl.create(:fake_app)
  end

  it 'says hello' do
    get '/'
    expect(last_response).to be_ok
  end
end
