class Devise::RegistrationsController < Devise::RegistrationsController
  around_filter :destroy_if_previously_invited, :only => :create


  private

  def destroy_if_previously_invited
    invitation_info = {}

    user_hash = params[:user]
    if user_hash && user_hash[:email]
      @user = User.find_by_email_and_encrypted_password(user_hash[:email], '')
      if @user
        invitation_info[:invitation_sent_at] = @user[:invitation_sent_at]
        invitation_info[:invited_by_id] = @user[:invited_by_id]
        invitation_info[:invited_by_type] = @user[:invited_by_type]
        @user.destroy
      end
    end

    # execute the action (create)
    yield
    # Note that the after_filter is executed at THIS position !

    # Restore info about the last invitation (for later reference)
    # Reset the invitation_info only, if invited_by_id is still nil at this stage:
    @user = User.find_by_email_and_invited_by_id(user_hash[:email], nil)
    if @user
      @user[:invitation_sent_at] = invitation_info[:invitation_sent_at]
      @user[:invited_by_id] = invitation_info[:invited_by_id]
      @user[:invited_by_type] = invitation_info[:invited_by_type]
      @user.save!
    end
  end
end