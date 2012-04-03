class Admin < PARENT_MODEL_CLASS
  if DEVISE_ORM == :mongoid
    include Mongoid::Document
    ## Database authenticatable
    field :email,              :type => String, :null => false, :default => ""
    field :encrypted_password, :type => String, :null => false, :default => ""

    ## Confirmable
    field :confirmation_token,   :type => String
    field :confirmed_at,         :type => Time
    field :confirmation_sent_at, :type => Time
    field :unconfirmed_email,    :type => String # Only if using reconfirmable

  end



  devise :database_authenticatable, :validatable
  include DeviseInvitable::Inviter
end
