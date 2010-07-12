class User
  include Mongoid::Document
  include Shim

  field :created_at, :type => DateTime

  devise :database_authenticatable, :validatable, :confirmable, :invitable
end
