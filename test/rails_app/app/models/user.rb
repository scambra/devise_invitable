class User < PARENT_MODEL_CLASS
  if DEVISE_ORM == :mongoid
    include Mongoid::Document

    ## Database authenticatable
    field :email,              :type => String, :null => false, :default => ""
    field :encrypted_password, :type => String, :null => false, :default => ""

    ## Recoverable
    field :reset_password_token,   :type => String
    field :reset_password_sent_at, :type => Time

    ## Confirmable
    field :confirmation_token,   :type => String
    field :confirmed_at,         :type => Time
    field :confirmation_sent_at, :type => Time
    field :unconfirmed_email,    :type => String # Only if using reconfirmable

    ## Invitable
    field :invitation_token,       :type => String
    field :invitation_sent_at,     :type => Time
    field :invitation_accepted_at, :type => Time
    field :invitation_limit,       :type => Integer
    field :invited_by_id,          :type => Integer
    field :invited_by_type,        :type => String


    field :username
    attr_accessible :username, :email, :password, :password_confirmation, :remember_me
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
