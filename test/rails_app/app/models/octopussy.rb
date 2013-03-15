# This model is here for the generators' specs
class Octopussy < PARENT_MODEL_CLASS
  if DEVISE_ORM == :mongoid
    include Mongoid::Document

    ## Database authenticatable
    field :email,              :type => String, :default => ""
    field :encrypted_password, :type => String, :default => ""
    validates_presence_of :email
    validates_presence_of :encrypted_password

  end
  devise :database_authenticatable, :validatable, :confirmable
end
