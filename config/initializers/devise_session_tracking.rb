# Copied from SmartQuote (excel_processor), proven in production. Hooks into
# Warden's auth cycle to open a UserSession on each login and close it on
# logout, so usage reports get real session durations, not just last_sign_in_at.
#
# - `after_set_user` with `event: :authentication` only fires on a real login,
#   not on every request (that's the `:fetch` event, excluded here).
# - If the server dies with sessions open, they get marked 'orphaned' the next
#   time that user logs in. No cleanup job on purpose (this app has no
#   background jobs); a stale-open session just means its duration is unknown.

Warden::Manager.after_set_user except: :fetch do |user, auth, opts|
  next unless user.is_a?(User)
  next unless opts[:event] == :authentication

  begin
    user.user_sessions.active.update_all(
      ended_at: Time.current,
      duration_seconds: nil,
      sign_out_reason: "orphaned",
      updated_at: Time.current
    )

    new_session = user.user_sessions.create!(
      started_at: Time.current,
      ip_address: auth.request.remote_ip,
      user_agent: auth.request.user_agent
    )

    scope = opts[:scope] || :user
    # String key: the session is serialized to the cookie and symbols get lost.
    auth.session(scope)["session_record_id"] = new_session.id
  rescue StandardError => e
    Rails.logger.error "[SessionTracking] Error creating session record: #{e.message}"
  end
end

Warden::Manager.before_logout do |user, auth, opts|
  next unless user.is_a?(User)

  begin
    scope = opts[:scope] || :user
    scope_session = auth.session(scope)
    session_id = scope_session.is_a?(Hash) ? scope_session["session_record_id"] : nil
    next unless session_id

    UserSession.find_by(id: session_id)&.close!(reason: "manual")
  rescue StandardError => e
    Rails.logger.error "[SessionTracking] Error closing session record: #{e.message}"
  end
end
