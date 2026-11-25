# frozen_string_literal: true

class Admin < PARENT_MODEL_CLASS
  if DEVISE_ORM == :mongoid
    include Mongoid::Document
    include Mongoid::Attributes::Dynamic if defined?(Mongoid::Attributes::Dynamic)
    ## Database authenticatable
    field :email,              type: String, default: ''
    field :encrypted_password, type: String, default: ''
    validates :email, presence: true
    validates :encrypted_password, presence: {if: :password_required?}

    ## Confirmable
    field :confirmation_token,   type: String
    field :confirmed_at,         type: Time
    field :confirmation_sent_at, type: Time
    field :unconfirmed_email,    type: String # Only if using reconfirmable
  end

  devise :database_authenticatable, :validatable, :registerable
  include DeviseInvitable::Inviter
end
