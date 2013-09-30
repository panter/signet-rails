# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'signet/rails/version'

Gem::Specification.new do |spec|
  spec.name          = 'signet-rails'
  spec.version       = Signet::Rails::VERSION
  spec.authors       = ['Paul Jolly']
  spec.email         = ['paul@myitcv.org.uk']
  spec.description   = %q{A wrapper around the Google Signet OAuth Library}
  spec.summary       = %q{Incorporate Signet goodness into Rails}
  spec.homepage      = 'https://github.com/myitcv/signet-rails'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 2.14.1'
  spec.add_development_dependency 'sinatra'
  spec.add_development_dependency 'factory_girl', '~> 4.2.0'
  spec.add_dependency 'signet', '~> 0.5.0'
  spec.add_dependency 'rack', '~> 1.5.2'
end
