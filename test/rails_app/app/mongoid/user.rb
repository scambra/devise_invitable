class User
  include Mongoid::Document
  include Shim

  field :created_at, :type => DateTime

  devise :database_authenticatable, :confirmable, :invitable
end
