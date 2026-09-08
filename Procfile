# Procfile — process types for Render / Foreman / Heroku-style runners.
#
# Render's `render.yaml` (the preferred way to deploy this app) reads
# `startCommand` per service from the blueprint, so this file is largely
# informational. It's useful if you ever run the app with `foreman start`
# locally, or if you switch to a Render "Infrastructure as Code" setup
# that auto-detects process types from a Procfile.
#
# Process types:
#   web       — Puma serving HTTP traffic
#   worker    — Solid Queue supervisor (processes background jobs)
#   release   — runs once per deploy, after the build but before the new
#               code starts serving traffic. Idempotent: creates the DB
#               if missing and applies all pending migrations.
web:      bin/rails server -b 0.0.0.0 -p ${PORT:-3000}
worker:   bin/jobs
release:  bin/rails db:prepare
