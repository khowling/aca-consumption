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

export A_PGNAME=khtest01

## Developer
export A_PGUSER=$(az account show --query "user.name" -o tsv | jq -R -r @uri)
export A_PGPASSWORD="$(az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv  | jq -R -r @uri)"

bun run ./index.ts


## Build container


## Grant the MI access

[Create Postgres user for the MI](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-connect-with-managed-identity#create-an-azure-database-for-postgresql-flexible-server-user-for-your-managed-identity)

```
export A_MI_PGUSER=testmi
psql postgres://${A_PGUSER}:${A_PGPASSWORD}@${A_PGNAME}.postgres.database.azure.com/postgres?sslmode=require  -c "select * from pgaadauth_create_principal('${A_MI_PGUSER}', false, false);"
```


## MI
export A_PGUSER=testmi

bun run ./index.ts

export A_PGPASSWORD=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://ossrdbms-aad.database.windows.net' -H Metadata:true -s | jq -r '.access_token' | jq -r -R @uri)


psql postgres://${A_PGUSER}:${A_PGPASSWORD}@${A_PGNAME}.postgres.database.azure.com/postgres?sslmode=require




