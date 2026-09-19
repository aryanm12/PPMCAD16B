# 05 - Managed MySQL and High Availability: Brief Notes

**Learning interface:** Use the Azure portal for this topic’s resource settings, monitoring and cleanup. The companion hands-on gives the exact pages and values. The database client runs through the documented SSH session because SQL, dump/import and data-validation operations execute against MySQL, not in a resource-creation form.

**Read before:** [Lab 05 - MySQL Flexible Server and HA](05-MySQL-Flexible-Server-and-High-Availability.md)  
**Reading time:** 5–7 minutes. Start with [foundation notes](01-Lab-Preparation-and-Cost-Controls-brief-notes.md) if Azure resource scopes are unfamiliar.

## What this lab is teaching

You will connect from a Linux client to a private managed database, write known rows and confirm they persist. Then you will examine what changes when high availability is enabled.

**Azure Database for MySQL Flexible Server** is a managed database service. You control database configuration, access and data; Azure operates the underlying service infrastructure. You do not SSH into its database host as you would into a self-managed MySQL VM.

## Terms you will encounter

| Term | Meaning |
|---|---|
| Server | The managed MySQL service resource and connection endpoint |
| Database/schema | A named collection of database objects inside MySQL |
| Table | Structured records with defined columns |
| Row / column | One record / one field in that record |
| Primary key | A value or combination that uniquely identifies a row |
| SQL client | Software sending queries to the server; installing it does not create a server |
| SQL | The language for defining/querying/changing relational data |
| Endpoint / hostname | The DNS name clients use to find the server |
| Compute tier / SKU | The selected performance/capability configuration |
| Connection | A network/database session between client and server |

The lab's client VM is a convenient place to run `mysql`. It is not where the managed database stores its files.

## The connection has multiple layers

```text
Hostname → DNS resolves private address → TCP 3306 → TLS → MySQL login → SQL
```

**DNS** translates a name into an address. **TCP 3306** is the conventional MySQL network port. **TLS** encrypts the connection and verifies server identity when configured correctly. The database then checks the MySQL username/password and SQL permissions.

The delegated subnet is assigned to the managed MySQL service. The private DNS zone/link makes its name usable from the client VNet. A **VNet link** connects that private DNS zone's resolution context to the VNet. This is distinct from giving a user database permission.

Your Azure Contributor role allows certain resource-management operations. It does not automatically make every SQL login valid. In this exercise, `labadmin` is a MySQL administrator identity, separate from your Azure sign-in.

## Read the SQL by intent

- `CREATE DATABASE` creates a named logical database.
- `CREATE TABLE` defines columns and constraints.
- `INSERT` stores records.
- `SELECT` reads records.
- `COUNT(*)` counts rows; `SUM(amount)` adds the amount values.

The checks expect three rows and total 600. Checking actual values makes the result stronger than simply seeing a successful login. Do not run the destructive commands from later recovery labs against shared databases.

## HA and backup protect different things

**High availability (HA)** reduces interruption from supported infrastructure failures. A standby can take over when the primary fails. **Zone-redundant HA** places primary and standby in different zones; same-zone HA does not provide that zone separation.

**Backup/PITR** supplies historical recovery. If someone deletes the wrong rows and that committed change replicates, HA preserves the new, wrong state too. You need an earlier recovery point to recover the old data.

The core lab uses **Burstable** compute without HA to limit cost. Enabling HA requires a supported tier/configuration and additional capacity. A larger bill does not automatically prove your application's RTO: you still need failover and restore tests. See [MySQL HA concepts](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/concepts-high-availability).

## AWS comparison

RDS for MySQL is a useful service-role comparison. Azure's Flexible Server private VNet integration, delegated subnet and DNS setup differ from an RDS DB subnet group. Do not assume RDS instance classes, default backup settings or connection syntax transfer directly.

## Check your understanding

1. `mysql --version` succeeds. Does that prove a managed database exists?
2. The hostname resolves, but TCP times out. Should you first reset the password?
3. Does HA recover a mistakenly committed DELETE?

**Answers:** (1) No, it proves the client is installed. (2) No, inspect the network path/service state first. (3) No; use historical recovery.

**Ready for the lab:** You can explain server versus client, network versus SQL authentication, and HA versus backup.

Further reading: [MySQL TLS connectivity](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/how-to-connect-tls-ssl).
