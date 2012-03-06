class Admin < PARENT_MODEL_CLASS
  if DEVISE_ORM == :mongoid
    include Mongoid::Document 

    ## Database authenticatable
    field :email,              :type => String, :null => true
    field :encrypted_password, :type => String, :null => true
  end
  
  devise :database_authenticatable, :validatable
  include DeviseInvitable::Inviter
end
