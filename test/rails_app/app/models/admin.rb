class Admin < PARENT_MODEL_CLASS
  include Mongoid::Document if DEVISE_ORM == :mongoid
  devise :database_authenticatable, :registerable, :timeoutable, :recoverable, :encryptable, :encryptor => :sha1
end
