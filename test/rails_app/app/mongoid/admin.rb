class Admin
  include Mongoid::Document
  include Shim
  
  devise :database_authenticatable, :timeoutable, :registerable, :recoverable, :encryptable, :encryptor => :sha1
end