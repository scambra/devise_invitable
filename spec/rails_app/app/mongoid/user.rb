class User
  include Mongoid::Document
  include Shim
  
  field :created_at, :type => DateTime
  field :name,       :type => String
  
  devise :database_authenticatable, :validatable, :confirmable, :invitable
  
  validates :name, :length => { :maximum => 20 }
end