source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.5", ">= 8.0.5.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# PostgreSQL owns everything this app writes: its csr_* tables, users, and the
# Solid Queue database.
gem "pg", "~> 1.5"

# SQL Server is read-only for this app. It holds the CSR_OSOR_AMERICAS staging
# table, loaded by the DBA's own truncate+load process; the app never creates or
# writes an object there. Pinned to the adapter's 8.0 line, which tracks Rails 8.0.
gem "activerecord-sqlserver-adapter", "~> 8.0.11"
gem "tiny_tds"

# SQLite is here for one job: the local stand-in for the staging table, so
# development and test can exercise the reporting connection without reaching
# the DBA's server. Nothing in production uses it.
gem "sqlite3", ">= 2.1"
# json 3.0 dropped the quirks_mode option that ActiveSupport 8.0 still passes on
# every to_json call, which breaks all JSON rendering. Pinned until Rails stops
# sending it.
gem "json", "~> 2.7"
# CSV export of open orders. csv leaves Ruby's default gems in 3.4, so declare it.
gem "csv"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Authentication (accounts created by an admin, no self-signup) and the
# admin-only role check on top of it.
gem "devise", "~> 4.9"
gem "petergate", "~> 3.0"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapter for Active Job
gem "solid_queue"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Minitest 6 ships its mocking helpers as a separate gem.
  gem "minitest-mock"
end
