# Database security check

Run the repository-only checks from the API root:

```bash
./scripts/security_audit.sh
```

Run the same checks against a deployed PostgreSQL database without printing its
credentials:

```bash
AUDIT_DATABASE_URL="$DATABASE_URL" ./scripts/security_audit.sh
```

The script checks:

- runtime environment files are not tracked by Git;
- tracked application files do not contain credential-bearing PostgreSQL URLs;
- Render injects `DATABASE_URL` server-side;
- a remote database URL explicitly requires/verifies TLS;
- the connected application role is not superuser and cannot create roles or
  replicate;
- dangerous provider-specific role attributes are reported;
- backup configuration and restore evidence are not falsely inferred from
  source code.

## Provider checks that still require operational access

Repository inspection cannot prove the following. Verify and record them in the
provider dashboards or a dated operations log:

1. The production database URL exists only in Render/server-side services and
   is absent from Vercel/frontend variables.
2. Neon/Render retention and point-in-time recovery settings are enabled for
   the production project.
3. An encrypted backup exists in R2:
   `./scripts/db_backup_restore.sh list neon`.
4. A selected backup has been restored into a disposable database and the app
   smoke-tested. Record the date, backup key, destination, RPO, and RTO.
5. The production application role owns/has only the schema and table
   privileges required by Rails migrations and runtime queries.

If a real credential has ever appeared in terminal output, chat, logs, or a
tracked commit, rotate it at the provider even if the local file is gitignored.