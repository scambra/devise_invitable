# This model is here for the generators' specs
class Octopussy < PARENT_MODEL_CLASS
  if DEVISE_ORM == :mongoid
    include Mongoid::Document

    ## Database authenticatable
    field :email,              :type => String, :null => false, :default => ""
    field :encrypted_password, :type => String, :null => false, :default => ""

  end
  devise :database_authenticatable, :validatable, :confirmable
end
