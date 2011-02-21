class User
  include Mongoid::Document
  include Shim
  
  field :created_at, :type => DateTime
  field :username,   :type => String
  
  devise :database_authenticatable, :registerable, :validatable, :confirmable, :invitable
  
  validates :username, :length => { :maximum => 20 }
end
