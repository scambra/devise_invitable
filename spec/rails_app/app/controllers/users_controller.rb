class UsersController < ApplicationController
  
  def edit
    @user = User.find(current_user.id)
  end
  
  def update
    @user = User.find(current_user.id)
    if @user.update_attributes(params[:user])
      redirect_to root_path
    else
      render :edit
    end
  end
  
end