class User < PARENT_MODEL_CLASS
  if DEVISE_ORM == :mongoid
    include Mongoid::Document
    field :username, :type => String
  end
  devise :database_authenticatable, :registerable, :validatable, :confirmable, :invitable, :recoverable
  
  attr_accessible :email, :username, :password, :password_confirmation, :skip_invitation
  attr_accessor :callback_works
  validates :username, :length => { :maximum => 20 }
  
  attr_accessor :testing_accepting_or_not_invited
  validates :username, :presence => true, :if => :testing_accepting_or_not_invited_validator?

  def testing_accepting_or_not_invited_validator?
    testing_accepting_or_not_invited && accepting_or_not_invited?
  end

  after_invitation_accepted do |object|
    object.callback_works = true
  end
end
