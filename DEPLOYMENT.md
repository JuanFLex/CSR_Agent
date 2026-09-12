# Deployment — UAT on k-lvl2393

Runbook to run the CSR Supply Visibility portal on **k-lvl2393**
(`10.5.3.242`, FQDN `k-lvl2393.k-l.flex.com`), alongside DGS, SmartQuote,
excel_processor and mice_consolidator. Same model as those: a **systemd
service** running Puma on a private port, reverse-proxied by **nginx under a
subpath**, against the local **PostgreSQL 14** cluster.

| Setting | Value |
|---|---|
| Subpath | `/csr/` |
| Puma port | `3006` — taken: 3000 DGS, 3001 SmartQuote, 3002 mice_consolidator, 3003 snow_agents, 3004 dgs-uat, 3005 lockbox |
| Code dir | `/railsapps/code/csr_agent` |
| App databases | `csr_agent_production` + `csr_agent_production_queue` (role `csr_agent`) |
| Reporting DB | SQL Server `SQLPR5256.flex.com:15001`, **read-only**, never migrated |
| systemd unit | `/etc/systemd/system/csr_agent.service` (`User=infinex`, `Group=csg_bi`) |
| nginx site | `/etc/nginx/sites-available/railsapps` |

When in doubt, mirror `dgs.service` and the `/dgs/` nginx block. The host's own
documentation is `~/code/brain/03-Infra/k-lvl2393.md`, and the traps below were
learned deploying Lockbox on 2026-09-03
(`~/code/brain/05-Journal/2026-09-03-lockbox-despliegue-y-siete-bloqueantes.md`).

## 0. Blockers to clear first

1. **FreeTDS.** The `tiny_tds` gem needs it to build and to run; without it
   `bundle install` fails and the reporting connection cannot open:
   `sudo apt-get install -y freetds-dev freetds-bin`.
2. ~~No authentication.~~ **Resolved.** Devise + PeterGate gate every page
   behind sign-in; there is no self-signup, so accounts are created by an
   admin (see "First admin" below). A non-admin cannot reach `/admin/users`
   or `/admin/usage`.

## 1. PostgreSQL role + databases

Solid Queue runs the scheduled ingests, so the queue database is not optional.
`db:prepare` creates both from `database.yml`.

```bash
sudo -u postgres psql <<'SQL'
CREATE ROLE csr_agent WITH LOGIN PASSWORD 'CHANGE_ME';
CREATE DATABASE csr_agent_production OWNER csr_agent;
CREATE DATABASE csr_agent_production_queue OWNER csr_agent;
SQL
```

There is no cache or cable database: Solid Cache and Solid Cable were removed.

## 2. Get the code

```bash
bash                       # the login shell is ksh; without this there is no `bundle`
cd /railsapps/code
git clone git@github.com:JuanFLex/CSR_Agent.git csr_agent
cd csr_agent
```

asdf's global Ruby on this host is 3.3.3, but every app runs 3.3.0. Run Ruby
commands from inside the checkout, where `.ruby-version` decides.

## 3. Gems

```bash
bundle config set --local without 'development test'
bundle install        # needs freetds-dev (step 0)
```

## 4. systemd service

Secrets stay out of the unit file — the unit files are world-readable:

```bash
sudo install -m 640 -o root -g csg_bi /dev/null /etc/csr_agent.env
sudoedit /etc/csr_agent.env
```

`640 root:csg_bi` follows `snow_agents.env`, so `infinex` can run
`. /etc/csr_agent.env` without sudo — which the manual ingest in step 8 needs.
The tradeoff is that any `csg_bi` member reads the SQL Server password; that
login is read-only by design. Use `600 root:root` (the `lockbox.env` pattern)
if that is not acceptable.

```ini
# /etc/csr_agent.env
RAILS_ENV=production
PORT=3006
RAILS_RELATIVE_URL_ROOT=/csr
RAILS_MAX_THREADS=5
RAILS_MASTER_KEY=CHANGE_ME

# Shown on the sign-in page in place of a password-reset link (there is no
# self-service reset — see "First admin" below).
CSR_SUPPORT_MAILBOX=CHANGE_ME@flex.com

# Postgres — everything this app writes
CSR_APP_DB_HOST=localhost
CSR_APP_DB_PORT=5432
CSR_APP_DB_NAME=csr_agent_production
CSR_APP_DB_USER=csr_agent
CSR_APP_DB_PASSWORD=CHANGE_ME

# SQL Server — read-only, a db_datareader login and nothing more
CSR_DB_HOST=SQLPR5256.flex.com
CSR_DB_PORT=15001
CSR_DB_NAME=p_infinex
CSR_READONLY_USER=CHANGE_ME
CSR_READONLY_PASSWORD=CHANGE_ME

# Solid Queue inside Puma: one process for UAT. See "Jobs" below.
SOLID_QUEUE_IN_PUMA=1
```

```bash
sudoedit /etc/systemd/system/csr_agent.service
```

```ini
[Unit]
Description=CSR Supply Visibility portal (Puma)
After=network.target postgresql@14-main.service
Wants=postgresql@14-main.service

[Service]
Type=simple
User=infinex
Group=csg_bi
WorkingDirectory=/railsapps/code/csr_agent
EnvironmentFile=/etc/csr_agent.env
# Not optional: systemd inherits nothing from the login shell, and without
# these bundle exec fails with status=127 / "command not found: puma", even
# though the same command works by hand.
Environment=GEM_HOME=/export/home/infinex/.asdf/installs/ruby/3.3.0/lib/ruby/gems/3.3.0
Environment=GEM_PATH=/export/home/infinex/.asdf/installs/ruby/3.3.0/lib/ruby/gems/3.3.0
Environment=PATH=/export/home/infinex/.asdf/installs/ruby/3.3.0/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/export/home/infinex/.asdf/installs/ruby/3.3.0/bin/bundle exec puma -C config/puma.rb
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

## 5. Database + assets

```bash
cd /railsapps/code/csr_agent
set -a; . /etc/csr_agent.env; set +a

bundle exec rails db:prepare                  # app schema + Solid Queue schema
RAILS_RELATIVE_URL_ROOT=/csr \
  bundle exec rails assets:precompile         # the subpath MUST be set here
```

Nothing in `db:prepare` touches SQL Server: the `reporting` connection carries
`database_tasks: false`, so Rails schema tasks cannot see it.

## 5a. First admin

There is no self-signup — every account, including the first, is created by
hand. Username is the Flex email; password defaults to that same email
(an admin can change it from `/admin/users` later):

```bash
bundle exec rails runner 'User.create!(email: "x@flex.com", password: "x@flex.com", roles: :admin)'
```

## 6. Start

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now csr_agent
sleep 6                                   # Puma takes ~4s to bind; curl before that lies
sudo systemctl status csr_agent
sudo journalctl -u csr_agent -f           # wait for the "Listening on" line
```

Puma binds `127.0.0.1` only (`config/puma.rb` uses `bind`, never `port`, which
would open every interface and let anyone reach the app around nginx and TLS).

## 7. nginx subpath

Inside the **443 server block** of `/etc/nginx/sites-available/railsapps`,
mirroring `/dgs/`:

```nginx
location /csr/ {
    proxy_pass http://127.0.0.1:3006;          # no trailing slash: preserve the subpath
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

```bash
sudo nginx -t && sudo systemctl restart nginx     # restart, not reload
```

`force_ssl` and `assume_ssl` are both on; the app trusts `X-Forwarded-Proto`,
which is why the header above is not optional.

## 8. First load

The portal shows nothing until a snapshot exists. Run both ingests by hand
once, then let the schedule take over:

```bash
set -a; . /etc/csr_agent.env; set +a
bundle exec rails runner 'p Csr::Osor::Ingest.new(force: true).call.message'
bundle exec rails runner 'p Csr::Fet::Ingest.new(force: true).call.message'
```

## 9. Backup

Add the app database to the cron backup array in
`/usr/local/bin/backup_postgres.sh`:

```bash
DATABASES=("dgs_production" "excel_processor_production" "mice_consolidator_production" "csr_agent_production")
```

The queue database holds only job state and does not need backing up.

That array has broken three times (a `_development` name, a dead CIFS mount, a
stuck comma), and every time it was found by luck. Verify the edit, then verify
the backup by content rather than by exit code:

```bash
sudo bash -c 'source <(grep "^DATABASES=" /usr/local/bin/backup_postgres.sh); printf "%s\n" "${DATABASES[@]}"' | cat -A
sudo gunzip -t /mnt/postgresql_backup/csr_agent_production_*.backup.gz
```

## 10. Verify

```bash
curl -sI https://k-lvl2393.k-l.flex.com/csr/        # 302 to sign-in now that auth is on
curl -sI https://k-lvl2393.k-l.flex.com/csr/up       # 200, always public — use this for health checks
```

Then search `STL135N8F7AG` (red, with a line-down escalation) and
`RC0402FR-07100RL` (the same MPN across 17 CPNs).

## Jobs

`config/recurring.yml` schedules the ingests in production: OSOR every 15
minutes, FET every hour. They only run while Solid Queue runs.

- `SOLID_QUEUE_IN_PUMA=1` (above) runs the workers inside the web process. One
  unit to manage, fine for UAT.
- For production, a second unit running `bin/jobs` separates them, so a web
  restart does not interrupt a load. Mirror the service above, with
  `ExecStart=/usr/bin/env bundle exec bin/jobs` and without `PORT`.

## Subsequent deploys

```bash
cd /railsapps/code/csr_agent
git pull
bundle install
set -a; . /etc/csr_agent.env; set +a
bundle exec rails db:migrate
RAILS_RELATIVE_URL_ROOT=/csr bundle exec rails assets:precompile
sudo systemctl restart csr_agent
```

## Notes / gotchas

- **The app never writes to SQL Server.** `Reporting::Base` refuses writes and
  the connection is meant to carry a `db_datareader` login. Verify the login
  with `script/sql/verify_reporting_access.sql` before pointing UAT at it.
- **`config/master.key` is not in the repo** (gitignored, and it never was
  committed). Copy it to the server by hand or pass `RAILS_MASTER_KEY` in the
  env file, or the app cannot read its credentials.
- **Always use the FQDN** — the TLS cert covers `k-lvl2393.k-l.flex.com` only.
- **Subpath breaks hardcoded `/` URLs.** Use path helpers; the CSV export link
  and the column pickers already do.
- **Assets are served by Puma** (propshaft); nginx only proxies. If they 404
  under `/csr/`, re-run `assets:precompile` with `RAILS_RELATIVE_URL_ROOT` set
  and restart.
- **A separate pre-prod is a known pattern here.** `dgs-uat.service` runs on
  3004 under `/dgs-uat` from its own checkout. If CSR ever needs the same, copy
  that unit rather than inventing one.
- **A load that shrinks by more than 30%** is parked instead of activated, and
  the previous snapshot keeps serving. Check `Csr::Snapshot.last.notes` when a
  load seems missing.
- **`/csr/` now answers 302, not 200.** Every page redirects to sign-in when
  unauthenticated. Point host health checks (`verify-k-lvl2393.sh`) at
  `/csr/up`, which stays public, not at the root.
