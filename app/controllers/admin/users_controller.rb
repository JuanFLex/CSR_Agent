class Admin::UsersController < ApplicationController
  # :all as a Symbol, not [:all] — petergate only expands the symbol form to
  # the controller's actions ([:all] in an array is taken literally and denies
  # everything.
  access admin: :all

  before_action :set_user, only: [ :edit, :update, :destroy ]

  def index
    @users = User.order(:email)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(create_params)
    @user.roles = params.dig(:user, :roles).to_s
    if @user.save
      redirect_to admin_users_path, notice: "User #{@user.email} created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    # petergate's roles= sanitizes: anything not in User::ROLES becomes :user.
    @user.roles = params.dig(:user, :roles).to_s
    if @user.update(update_params)
      redirect_to admin_users_path, notice: "User #{@user.email} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user == current_user
      redirect_to admin_users_path, alert: "You can't delete your own account."
    else
      @user.destroy
      redirect_to admin_users_path, notice: "User #{@user.email} deleted."
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end

  # House convention: a blank password on create defaults to the email, so
  # "username = Flex email, initial password = the same email" holds without
  # anyone having to type it twice.
  def create_params
    permitted = user_params
    if permitted[:password].blank?
      permitted[:password] = permitted[:password_confirmation] = permitted[:email]
    end
    permitted
  end

  # Blank password on edit means "keep the current one" — Devise's
  # validatable would otherwise reject the empty string.
  def update_params
    permitted = user_params
    permitted.except(:password, :password_confirmation).merge(
      permitted.slice(:password, :password_confirmation).compact_blank
    )
  end
end
