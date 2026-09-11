# Deployment — UAT on k-lvl2393

Runbook to run the CSR Supply Visibility portal on **k-lvl2393**
(`10.5.3.242`, FQDN `k-lvl2393.k-l.flex.com`), alongside DGS, SmartQuote,
excel_processor and mice_consolidator. Same model as those: a **systemd
service** running Puma on a private port, reverse-proxied by **nginx under a
subpath**, against the local **PostgreSQL 14** cluster.

| Setting | Value |
|---|---|
| Subpath | `/csr/` |
| Puma port | `3003` (DGS=3000, SmartQuote=3001, mice_consolidator=3002) |
| Code dir | `/railsapps/code/csr_agent` |
| App databases | `csr_agent_production` + `csr_agent_production_queue` (role `csr_agent`) |
| Reporting DB | SQL Server `SQLPR5256.flex.com:15001`, **read-only**, never migrated |
| systemd units | `/etc/systemd/system/csr_agent.service` |
| nginx site | `/etc/nginx/sites-available/railsapps` |

When in doubt about the Ruby version manager, the deploy user or the nginx
proxy headers, **mirror `dgs.service` and the `/dgs/` nginx block**.

## 0. Blockers to clear first

1. **No git remote.** `git remote -v` is empty, so the server has nothing to
   clone. Either push to a private repo (the way mice_consolidator uses
   `github.com/JuanFLex/mice-project.git`) or rsync the working tree. Decide
   before step 2.
2. **FreeTDS.** The `tiny_tds` gem needs it to build and to run; without it
   `bundle install` fails and the reporting connection cannot open:
   `sudo apt-get install -y freetds-dev freetds-bin`.
3. **No authentication.** This app has no login: whoever reaches the subpath
   sees every customer, part and order. That is fine for a UAT behind the
   internal network; it is a decision to make consciously before the link is
   shared.

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
cd /railsapps/code
git clone <remote decided in step 0> csr_agent
cd csr_agent
```

## 3. Gems

```bash
bundle config set --local without 'development test'
bundle install        # needs freetds-dev (step 0)
```

## 4. systemd service

Secrets stay out of the unit file — the unit files are world-readable:

```bash
sudo install -m 600 /dev/null /etc/csr_agent.env
sudoedit /etc/csr_agent.env
```

```ini
# /etc/csr_agent.env
RAILS_ENV=production
PORT=3003
RAILS_RELATIVE_URL_ROOT=/csr
RAILS_MAX_THREADS=5
RAILS_MASTER_KEY=CHANGE_ME

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
User=<deploy_user>
WorkingDirectory=/railsapps/code/csr_agent
EnvironmentFile=/etc/csr_agent.env
# Match how dgs.service invokes bundler/ruby (rbenv/asdf/system path):
ExecStart=/usr/bin/env bundle exec puma -C config/puma.rb
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

## 6. Start

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now csr_agent
sudo systemctl status csr_agent
sudo journalctl -u csr_agent -f
```

## 7. nginx subpath

Inside the **443 server block** of `/etc/nginx/sites-available/railsapps`,
mirroring `/dgs/`:

```nginx
location /csr/ {
    proxy_pass http://127.0.0.1:3003;          # no trailing slash: preserve the subpath
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

## 10. Verify

```bash
curl -sI https://k-lvl2393.k-l.flex.com/csr/        # 200, via FQDN (the cert covers it only)
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
- **Always use the FQDN** — the TLS cert covers `k-lvl2393.k-l.flex.com` only.
- **Subpath breaks hardcoded `/` URLs.** Use path helpers; the CSV export link
  and the column pickers already do.
- **Assets are served by Puma** (propshaft); nginx only proxies. If they 404
  under `/csr/`, re-run `assets:precompile` with `RAILS_RELATIVE_URL_ROOT` set
  and restart.
- **A load that shrinks by more than 30%** is parked instead of activated, and
  the previous snapshot keeps serving. Check `Csr::Snapshot.last.notes` when a
  load seems missing.
