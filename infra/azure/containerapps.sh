#!/usr/bin/env bash
# Deploys the web app and Solr into an existing Azure Container Apps environment (no VM, no Microsoft.Network
# registration, no storage mount). Images must already be in the registry (run the "Push images to Azure Container
# Registry" workflow first). Solr's index lives on the container's disk, so it is empty after any restart; the web
# app re-fills it on start (AUTO_INDEX=true) from the CSV files baked into its image. Nothing secret is printed; run
# after `az login`.
#
#   SUBSCRIPTION=<id> RG=<resource group> ACR=<registry name> PG=<postgres server> ENVNAME=<env> \
#   TAG=<image tag, e.g. the commit SHA> infra/azure/containerapps.sh
#
# Lessons from the first deploy (Azure for Students, "Express" environments):
#  - Pin TAG to a commit SHA. A moving tag such as "latest" can be served from the node's cache, and a changed tag is
#    what makes Azure start a new replica (restart/revision commands are not supported there).
#  - Solr 10 starts in cloud mode by default; the core made by precreate-core needs --user-managed.
#  - Solr's internal ingress is still reachable from the internet, so it gets a random password (security.json from a
#    secret) and the web app reaches it by its full https address with the password in a secret.
#  - The database only needs the plpgsql extension allow-listed (azure.extensions=plpgsql).
set -euo pipefail

: "${SUBSCRIPTION:?set SUBSCRIPTION}"
: "${RG:?set RG}"
: "${ACR:?set ACR (registry name, e.g. ccsacr80e9cc)}"
: "${PG:?set PG (Postgres server name, e.g. ccs-pg-80e9cc)}"
: "${ENVNAME:?set ENVNAME (existing Container Apps environment)}"
: "${TAG:?set TAG (image tag, use the commit SHA)}"
: "${MEDIA_BASE_URL:?set MEDIA_BASE_URL (where the audio, video and PDF files are served from, no trailing slash)}"

az account set --subscription "$SUBSCRIPTION"
az extension add --name containerapp --upgrade --only-show-errors

ACR_USER="$(az acr credential show -n "$ACR" --query username -o tsv)"
ACR_PASS="$(az acr credential show -n "$ACR" --query 'passwords[0].value' -o tsv)"
REG="$ACR.azurecr.io"

# Postgres: Rails' schema enables plpgsql, which Azure only allows once it is allow-listed. Set a fresh admin password
# (the one from creation was never shown) and keep it in a Container App secret.
az postgres flexible-server parameter set -g "$RG" --server-name "$PG" --name azure.extensions --value plpgsql -o none
PGPASS="$(openssl rand -hex 24)"
az postgres flexible-server update -n "$PG" -g "$RG" --admin-password "$PGPASS" -o none
SECRET_KEY_BASE="$(openssl rand -hex 64)"

# Solr password and security.json (basic auth, salted double sha256 as Solr expects).
SOLR_PW="$(openssl rand -hex 20)"
SECURITY_JSON="$(SOLR_PW="$SOLR_PW" python3 - <<'PY'
import base64, hashlib, json, os
salt = os.urandom(16)
digest = hashlib.sha256(hashlib.sha256(salt + os.environ["SOLR_PW"].encode()).digest()).digest()
credential = base64.b64encode(digest).decode() + " " + base64.b64encode(salt).decode()
print(json.dumps({
  "authentication": {"blockUnknown": True, "class": "solr.BasicAuthPlugin", "credentials": {"solr": credential}, "forwardCredentials": False},
  "authorization": {"class": "solr.RuleBasedAuthorizationPlugin",
                    "permissions": [{"name": "security-edit", "role": "admin"}], "user-role": {"solr": "admin"}}
}))
PY
)"

# Solr. --args cannot carry "-c" followed by a script, so the command is set from a small YAML file (no secrets in it).
SOLR_YAML="$(mktemp)"
trap 'rm -f "$SOLR_YAML"' EXIT
cat > "$SOLR_YAML" <<EOF
properties:
  template:
    containers:
      - name: ccs-solr
        image: $REG/ccs-solr:$TAG
        command: ["bash"]
        args: ["-c", "init-var-solr; precreate-core blacklight-core /opt/solr/server/solr/configsets/blacklight-conf; printf %s \"\$SOLR_SECURITY_JSON\" > /var/solr/data/security.json; exec solr-foreground --user-managed"]
        resources:
          cpu: 1.0
          memory: 2Gi
EOF

if az containerapp show -n ccs-solr -g "$RG" -o none 2>/dev/null; then
  az containerapp secret set -n ccs-solr -g "$RG" --secrets securityjson="$SECURITY_JSON" -o none
  az containerapp update -n ccs-solr -g "$RG" --yaml "$SOLR_YAML" -o none
  az containerapp update -n ccs-solr -g "$RG" --set-env-vars SOLR_SECURITY_JSON=secretref:securityjson -o none
else
  az containerapp create -n ccs-solr -g "$RG" --environment "$ENVNAME" \
    --image "$REG/ccs-solr:$TAG" --registry-server "$REG" --registry-username "$ACR_USER" --registry-password "$ACR_PASS" \
    --ingress internal --target-port 8983 --transport http --min-replicas 1 --max-replicas 1 --cpu 1 --memory 2Gi \
    --secrets securityjson="$SECURITY_JSON" --env-vars SOLR_SECURITY_JSON=secretref:securityjson -o none
  az containerapp update -n ccs-solr -g "$RG" --yaml "$SOLR_YAML" -o none
  az containerapp update -n ccs-solr -g "$RG" --set-env-vars SOLR_SECURITY_JSON=secretref:securityjson -o none
fi

SOLR_FQDN="$(az containerapp show -n ccs-solr -g "$RG" --query properties.configuration.ingress.fqdn -o tsv)"
SOLR_URL="https://solr:${SOLR_PW}@${SOLR_FQDN}/solr/blacklight-core"

WEB_ENV=(RAILS_ENV=production RAILS_ASSUME_SSL=true RAILS_FORCE_SSL=true AUTO_INDEX=true
  POSTGRES_HOST="$PG.postgres.database.azure.com" POSTGRES_DB=ead_ccs POSTGRES_USER=ead_ccs PGSSLMODE=require
  POSTGRES_PASSWORD=secretref:pgpass SECRET_KEY_BASE=secretref:secretkey SOLR_URL=secretref:solrurl
  CCS_MEDIA_BASE_URL="$MEDIA_BASE_URL")

if az containerapp show -n ccs-web -g "$RG" -o none 2>/dev/null; then
  az containerapp secret set -n ccs-web -g "$RG" --secrets pgpass="$PGPASS" secretkey="$SECRET_KEY_BASE" solrurl="$SOLR_URL" -o none
  az containerapp update -n ccs-web -g "$RG" --image "$REG/ccs-web:$TAG" --set-env-vars "${WEB_ENV[@]}" -o none
else
  az containerapp create -n ccs-web -g "$RG" --environment "$ENVNAME" \
    --image "$REG/ccs-web:$TAG" --registry-server "$REG" --registry-username "$ACR_USER" --registry-password "$ACR_PASS" \
    --ingress external --target-port 3000 --min-replicas 1 --max-replicas 1 --cpu 1 --memory 2Gi \
    --secrets pgpass="$PGPASS" secretkey="$SECRET_KEY_BASE" solrurl="$SOLR_URL" \
    --env-vars "${WEB_ENV[@]}" -o none
fi

FQDN="$(az containerapp show -n ccs-web -g "$RG" --query properties.configuration.ingress.fqdn -o tsv)"
az containerapp update -n ccs-web -g "$RG" --set-env-vars RAILS_HOSTS="$FQDN" -o none
echo "Deployed. Site: https://$FQDN"
echo "The web app indexes the bundled CSV files into Solr in the background; search fills in after a few minutes."
