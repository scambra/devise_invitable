class User < PARENT_MODEL_CLASS
  if DEVISE_ORM == :mongoid
    include Mongoid::Document
    field :username, :type => String
  end
  devise :database_authenticatable, :registerable, :validatable, :confirmable, :invitable, :recoverable
  
  attr_accessible :email, :username, :password, :password_confirmation, :skip_invitation
  
  validates :username, :length => { :maximum => 20 }
end
