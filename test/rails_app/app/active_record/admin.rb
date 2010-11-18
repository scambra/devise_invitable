class Admin < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :timeoutable, :recoverable, :encryptable, :encryptor => :sha1
end