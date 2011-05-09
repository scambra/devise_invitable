# This model is here for the generators' specs
class Octopussy < PARENT_MODEL_CLASS
  include Mongoid::Document if DEVISE_ORM == :mongoid
  devise :database_authenticatable, :validatable, :confirmable, :encryptable
end
