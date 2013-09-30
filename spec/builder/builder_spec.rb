require 'spec_helper'

module Signet
  module Rails
    describe 'handler' do
      context 'that is login based' do
        context 'with default arguments' do
          it 'should require a string client id' do
            exception = nil
            begin
              app = login_app
            rescue ArgumentError => e
              exception = e
            end
            expect(exception).not_to be_nil
            expect(exception.message).to eq('Client id is required for a type: :login provider')
          end

          it 'should require a scope to be defined' do
            exception = nil
            begin
              app = login_app client_id: 'id'
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
            app = login_app client_id: 'id', scope: ' test '
            req = request app
            resp = req.get '/signet/google/auth', env
            expect(resp.body).to be_empty
            expect(resp.original_headers['Location']).to eq('https://accounts.google.com/o/oauth2/auth?access_type=offline&approval_prompt=auto&client_id=id&redirect_uri=http://myitcv.org.uk:4321/signet/google/auth_callback&response_type=code&scope=test')
          end

          it 'should redirect to google' do
            app = login_app client_id: 'id', scope: 'test'
            req = request app
            resp = req.get '/signet/google/auth', env
            expect(resp.body).to be_empty
            expect(resp.original_headers['Location']).to eq('https://accounts.google.com/o/oauth2/auth?access_type=offline&approval_prompt=auto&client_id=id&redirect_uri=http://myitcv.org.uk:4321/signet/google/auth_callback&response_type=code&scope=test')
          end

          it 'should handle multiple scopes' do
            app = login_app client_id: 'id', scope: ['test','trial']
            req = request app
            resp = req.get '/signet/google/auth', env
            expect(resp.body).to be_empty
            expect(resp.original_headers['Location']).to eq('https://accounts.google.com/o/oauth2/auth?access_type=offline&approval_prompt=auto&client_id=id&redirect_uri=http://myitcv.org.uk:4321/signet/google/auth_callback&response_type=code&scope=test%20trial')
          end

          it 'should handle url scopes' do
            app = login_app client_id: 'id', scope: ['https://www.googleapis.com/auth/userinfo.email']
            req = request app
            resp = req.get '/signet/google/auth', env
            expect(resp.body).to be_empty
            expect(resp.original_headers['Location']).to eq('https://accounts.google.com/o/oauth2/auth?access_type=offline&approval_prompt=auto&client_id=id&redirect_uri=http://myitcv.org.uk:4321/signet/google/auth_callback&response_type=code&scope=https://www.googleapis.com/auth/userinfo.email')
          end

          it 'should require an auth_code on auth callback' do
            app = login_app client_id: 'id', scope: 'scope'
            req = request app
            resp = req.get '/signet/google/auth_callback', env
            expect(resp.body).to be_empty
            expect(resp.original_headers['Location']).to eq('https://accounts.google.com/o/oauth2/auth?access_type=offline&approval_prompt=auto&client_id=id&redirect_uri=http://myitcv.org.uk:4321/signet/google/auth_callback&response_type=code&scope=https://www.googleapis.com/auth/userinfo.email')

          end
        end
      end
    end

    describe 'login handler' do

      context 'that is google-based' do
        it 'should redirect based on provider name' do
          app = base_app name: :google, type: :login, client_id: 'id', client_secret: 456, scope: 'myscope'
          req = request app
          resp = req.get '/signet/google/auth'
        end
      end
    end

    describe 'default login handler' do
      it 'should be google-based'
    end

  end
end
