# Secrets Management

> **This describes the earlier AWS and Kubernetes deployment.** The live app runs on Azure Container Apps, where the database
> password, `SECRET_KEY_BASE` and `SOLR_URL` are Container Apps secrets (`pgpass`, `secretkey`, `solrurl`) set by
> `infra/azure/containerapps.sh` or the portal; see [../../infra/azure/README.md](../../infra/azure/README.md). The rules still
> hold: no secret in git, a file, a message or a pull request. The Solr password hash in `solr/security.json` and the secret
> must be changed together. The AWS and Kubernetes steps below apply only if that deployment is used again.

How application secrets are stored, delivered to the running app, and rotated.

## Overview

Secrets are **not** committed to git. They live in **AWS Secrets Manager** and are
pulled into the cluster at runtime by the **External Secrets Operator (ESO)**, which
creates a Kubernetes `Secret` that the app pods consume via `envFrom`.

```
AWS Secrets Manager (client account)
        │  GetSecretValue
        ▼
External Secrets Operator  ──creates──▶  K8s Secret: ead-ccs-secrets
  (SecretStore + ExternalSecret)                 │  envFrom.secretRef
                                                 ▼
                                    ead-ccs (Rails), ead-ccs-index (Job)
```

ESO reaches the secret via a **cross-account role chain**: the operator's namespace
role in the AWS platform account assumes an IAM role in our client account, and that role
has read access to the secret.

```
platform ESO role                          client-account role
arn:…:352826034930:role/                   arn:…:956880924330:role/
applications-ap-southeast-4-               ead-ccs-<env>-secrets
ead-ccs-<env>-external-secrets   ──sts:AssumeRole──▶   (secretsmanager:GetSecretValue)
```

## Where everything lives

| Piece | Location |
|---|---|
| AWS secret | Secrets Manager, client account `956880924330`, region `ap-southeast-4` |
| Client-account IAM role | `arn:aws:iam::956880924330:role/ead-ccs-<env>-secrets` (trust + read policy) |
| Platform ESO role (trust principal) | `arn:aws:iam::352826034930:role/applications-ap-southeast-4-ead-ccs-<env>-external-secrets` |
| `SecretStore` + `ExternalSecret` | `ead-ccs-kube-manifests` → `base/application-secrets.yaml` |
| Per-environment ARNs (role + secret) | `ead-ccs-kube-manifests` → `<env>/kustomization.yaml` (patches) |
| Resulting K8s Secret | `ead-ccs-secrets` in namespace `ead-ccs-<env>` |
| Consumers | `base/deployment.yaml`, `base/index-job.yaml` (`envFrom.secretRef`) |
| Solr password hash | this repo → `solr/security.json` (see [Solr authentication](#solr-authentication)) |

## Secret contents

The AWS secret is a JSON object. ESO's `dataFrom.extract` maps every key into the K8s Secret.

| Key | Used by | Notes |
|---|---|---|
| `SECRET_KEY_BASE` | Rails | session/cookie signing key |
| `DATABASE_URL` | Rails | full Postgres connection string (embeds the password) |
| `POSTGRES_PASSWORD` | Postgres / Rails | must match `DATABASE_URL` |
| `SOLR_URL` | Rails, indexer | includes Solr credentials: `http://solr:<pass>@solr:8983/solr/blacklight-core` |
| `SOLR_USER`, `SOLR_PASSWORD` | Rails, indexer | Solr BasicAuth credentials |

Non-sensitive settings stay in the ConfigMap (`<env>/config.env`).

## Solr authentication

Solr BasicAuth is the one secret that lives in **two places that must stay in sync**,
because Solr can't read an env var, it reads a *hashed* password from a file:

1. **`solr/security.json`** (this repo) — the **hashed** password, baked into the Solr
   image at build time via the `COPY solr/security.json …` line in the `Dockerfile`.
2. **AWS Secrets Manager** — the **plaintext** password, in `SOLR_PASSWORD` and embedded
   in `SOLR_URL`, which Rails uses to authenticate to Solr.

The hash format is `base64(sha256(sha256(salt+password))) base64(salt)`. To (re)generate
it for a chosen password, use the helper at <https://clemente-biondo.github.io/> or:

```bash
python3 - <<'PY'
import hashlib, base64, os
pw = "CHOSEN_PLAINTEXT"          # must equal AWS SOLR_PASSWORD
salt = os.urandom(32)
d = hashlib.sha256(hashlib.sha256(salt + pw.encode()).digest()).digest()
print('"solr":"%s %s"' % (base64.b64encode(d).decode(), base64.b64encode(salt).decode()))
PY
```

> Note: If they drift (hash ≠ plaintext), Rails gets `401`s from Solr.

## Rotating secrets

### Any key except Solr and the DB password

1. Update the value in AWS Secrets Manager (AWSPowerUserAccess account, `ap-southeast-4`).
2. Trigger a refresh (ESO otherwise re-reads hourly):
   ```bash
   kubectl annotate externalsecret ead-ccs-secrets -n ead-ccs-<env> \
     force-sync=$(date +%s) --overwrite
   ```
3. Restart consumers so they pick up the new env values (K8s injects `envFrom` at pod start)

### `SECRET_KEY_BASE`

Same as above.

### Database password

`DATABASE_URL` and `POSTGRES_PASSWORD` must match the Postgres password. The
in-cluster Postgres only sets its password when it **initialises an empty data
directory**, so changing the value alone will not change an existing DB's password.
To rotate:

1. Update `SOLR`-unrelated keys (`POSTGRES_PASSWORD`, `DATABASE_URL`) in AWS.
2. Wipe and re-initialise Postgres (dev/test only): delete the `postgres-data` PVC so
   the pod re-initialises with the new password.
3. Refresh ESO and restart the app (see above).

For production DBs (managed RDS) rotate on the database first, then update the AWS
secret to match.

### Solr password (two-places)

1. Choose the new plaintext password
2. Regenerate the hash and update `solr/security.json` in this repo (see
   [Solr authentication](#solr-authentication)); commit.
3. Rebuild and deploy the Solr image (the hash is baked in at build time).
4. Update the AWS secret: set `SOLR_PASSWORD` to the new plaintext and update `SOLR_URL`
   to `http://solr:<new-plaintext>@solr:8983/solr/blacklight-core`.
5. Refresh ESO, then restart both the app and Solr:
   ```bash
   kubectl annotate externalsecret ead-ccs-secrets -n ead-ccs-<env> force-sync=$(date +%s) --overwrite
   kubectl rollout restart deployment/ead-ccs deployment/solr -n ead-ccs-<env>
   ```

## Verifying and troubleshooting

```bash
# Store + sync health
kubectl get secretstore aws-secretsmanager -n ead-ccs-<env>   # READY should be True
kubectl get externalsecret ead-ccs-secrets -n ead-ccs-<env>   # STATUS should be SecretSynced
kubectl describe secretstore aws-secretsmanager -n ead-ccs-<env> # exact error in conditions

# Keys present in the synced secret (values are base64)
kubectl get secret ead-ccs-secrets -n ead-ccs-<env> -o yaml
```

| Symptom | Likely cause |
|---|---|
| `SecretStore … ValidationFailed`, `AccessDenied … sts:AssumeRole` | Client-account role missing, its trust policy doesn't name the platform ESO role, or the SecretStore `role` patch still holds the placeholder ARN |
| Rails `401` from Solr | `solr/security.json` hash and AWS `SOLR_PASSWORD` have drifted |
