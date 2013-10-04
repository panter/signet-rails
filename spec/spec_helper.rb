require 'signet/rails'
require 'sinatra/base'
require 'factory_girl'
require 'faraday'
require 'faraday/adapter/test'
require 'securerandom'
require 'jwt'

Dir[File.dirname(__FILE__)+"/support/*.rb"].each {|file| require file }
Dir[File.dirname(__FILE__)+"/*factory.rb"].each {|file| require file }
Dir[File.dirname(__FILE__)+"/factories/*.rb"].each {|file| require file }

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'
end

