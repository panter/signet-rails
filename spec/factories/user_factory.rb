class User < ActiveRecord::Base
  validates_uniqueness_of :uid
  has_many :o_auth2_credentials, dependent: :destroy
end

class OAuth2Credential < ActiveRecord::Base
  belongs_to :user
  serialize :signet, Hash
  validates_uniqueness_of :name, scope: :id
end
