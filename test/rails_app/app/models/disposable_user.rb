class DisposableUser < PARENT_MODEL_CLASS
  if DEVISE_ORM == :mongoid
    include Mongoid::Document

    field :email, type: String, default: ''
    field :encrypted_password, type: String, default: ''
  end

  devise :database_authenticatable, :invitable,
    create_resource_on_invitation: true,
    invitations_dependent: :destroy
end
