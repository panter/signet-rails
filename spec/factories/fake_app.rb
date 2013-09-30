require 'sinatra/base'

class FakeApp < Sinatra::Base
  get "/" do
    "Hello"
  end
end

FactoryGirl.define do
  factory :fake_app do
  end
end
