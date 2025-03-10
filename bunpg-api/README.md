# bunpg-api

To install dependencies:

```bash
bun install
```

To run:

```bash
bun run index.ts
```

This project was created using `bun init` in bun v1.2.2. [Bun](https://bun.sh) is a fast all-in-one JavaScript runtime.


### Postgres Flexible server

[here](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-connect-with-managed-identity)

Setup EntraID

#  connect as the Microsoft Entra administrator user to your Azure Database for PostgreSQL flexible server database

https://bun.sh/docs/api/sql#database-environment-variables

export A_PGNAME=03ae6-acascale

## Developer
export A_PGUSER=$(az account show --query "user.name" -o tsv | jq -R -r @uri)
export A_PGPASSWORD="$(az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv  | jq -R -r @uri)"

## MI
export A_PGUSER=03ae6-acascale-acaenv-identity
export A_PGPASSWORD="$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fossrdbms-aad.database.windows.net%2F' -H Metadata:true -s | jq '.access_token' | jq -R @uri)"


psql postgres://${A_PGUSER}:${A_PGPASSWORD}@${A_PGNAME}.postgres.database.azure.com/postgres?sslmode=require


##  From BICEP
export MID_NAME=03ae6-acascale-acaenv-identity
psql $TLS_POSTGRES_DATABASE_URL  -c "select * from pgaadauth_create_principal('${MID_NAME}', false, false);"


