# 14 - Key Vault Application Integration: Brief Notes

**Learning interface:** Use the Azure portal for this topic’s resource settings, monitoring and cleanup. The companion hands-on gives the exact pages and values. Supplied guest scripts run through the VM’s portal Run command page to install or test software inside the VM.

**Read before:** [Lab 14 - Key Vault application integration](14-Key-Vault-Application-Integration.md)  
**Reading time:** 5–7 minutes. Read [managed identity notes](11-Managed-Identity-RBAC-and-VM-Operations-brief-notes.md) first if tokens/RBAC are new.

## Why use Key Vault?

An application may need a database password or another credential. Embedding it in source code or VM startup text makes accidental sharing and rotation harder. Key Vault centralizes storage and controlled retrieval; the application still needs an identity authorized to ask for that secret.

```text
VM managed identity → Key Vault token → read one secret → use value in memory
```

The lab uses a synthetic credential and checks its shape without printing it. Guide 03 applies a similar retrieval pattern to an actual MySQL connection.

## Terms before creating the vault

| Term | Meaning |
|---|---|
| Vault | The Azure resource organizing protected objects and access configuration |
| Secret | A protected value, such as a password or API credential |
| Key | A cryptographic object used for supported encryption/signing operations; not simply another name for a password |
| Certificate | A digital identity/trust object commonly used with TLS |
| Secret name | The logical identifier, such as `application-token` |
| Secret version | One stored revision of that named secret |
| Versioned URL | Identifies a particular secret revision |
| Versionless URL | Requests the current version according to service behavior |
| Rotation | Coordinated replacement of a credential and its use by dependent systems |

An **API key** can be stored as a Key Vault **secret**. The word “key” in its application name does not mean it must be stored as a Key Vault cryptographic key.

## Operator and application permissions differ

The learner creates/changes the secret with **Key Vault Secrets Officer**. The VM retrieves it with **Key Vault Secrets User** at the dedicated lab-vault scope (which contains only this lab secret). The application should not receive the writer's permission merely because both need to interact with the vault.

This lab uses the **Azure RBAC permission model**. The older **vault access-policy model** is another authorization model, not an extra list you must configure alongside RBAC. Resource-management Contributor alone does not automatically grant the RBAC secret-reading permission used here. See [Key Vault RBAC](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide).

## What happens during retrieval

The VM requests a token intended for Key Vault, sends an HTTPS request naming the secret, and receives the value only if network and authorization checks pass. The value is then in the application process's memory.

The code must not log the value or token while demonstrating success. Printing “PASS” after the expected operation is useful evidence without revealing the credential.

## Versions and rotation are not identical

Creating a new Key Vault version updates stored configuration. It does not change a password on an external database/provider by itself. A coordinated real rotation needs the credential issuer, vault value and application refresh behavior to agree.

A **cache** can reduce repeated secret requests, but it also needs an expiry/refresh strategy. The lab starts a fresh short process, so the next run requests the current value. A long-running production process may continue using a cached older credential.

Also, **key/secret storage** and **data encryption** are different responsibilities. Putting a DB password in Key Vault does not automatically encrypt all application data or configure DB TLS.

## Deletion and recovery protections

**Soft delete** keeps a deleted vault/object recoverable for a retention period. **Purge** is permanent removal when allowed. **Purge protection** prevents bypassing the protected retention behavior. Resource names may remain reserved during recovery retention.

The lab records that remaining lifecycle state rather than disabling organization controls to force instant deletion. See [Key Vault soft delete](https://learn.microsoft.com/en-us/azure/key-vault/general/soft-delete-overview).

## AWS comparison

Secrets Manager/Parameter Store provide familiar secret-configuration responsibilities; Key Vault also has distinct key and certificate capabilities. A managed identity fills a role similar to workload credentials from IAM, but Azure role scopes/token audiences and rotation workflows are different.

## Check your understanding

1. Does a new vault secret version automatically change the database password?
2. Should the app get Secrets Officer just to read its credential?
3. Can a privileged compromised host still access a secret used by its process?

**Answers:** (1) No. (2) No, grant the required read scope. (3) Yes; secure the runtime as well as secret storage.

**Ready for the lab:** You can distinguish storage, authorization, credential use and coordinated rotation.

Further reading: [Key Vault overview](https://learn.microsoft.com/en-us/azure/key-vault/general/overview).
