class User < ApplicationRecord
  # :user is petergate's implicit default role; :admin manages users via
  # Admin::UsersController. Add roles here if the app ever needs more.
  petergate(roles: [ :admin ], multiple: false)

  # No :registerable — there is no public signup, admins create accounts.
  # No :recoverable — house decision (ADR 2026-08-13): username is the Flex
  # email, the initial password is that same email, and "Forgot your
  # password?" is a mailto: to the support mailbox instead of a reset flow.
  # :trackable feeds the usage report (sign_in_count / last_sign_in_at);
  # UserSession tracks real session durations.
  devise :database_authenticatable, :rememberable, :validatable, :trackable

  has_many :user_sessions, dependent: :destroy
end
