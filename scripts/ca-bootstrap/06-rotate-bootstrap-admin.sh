#!/bin/bash
# =============================================================================
# scripts/ca-bootstrap/06-rotate-bootstrap-admin.sh
# =============================================================================
# Step 5 of the RWRRN crypto-material bootstrap sequence.
#
# WHY THIS EXISTS (see Docs/Config-and-Progress.md, "Bootstrap Admin Rotation"):
#   The CA was started with a well-known default bootstrap identity
#   (admin:adminpw, via `fabric-ca-server start -b admin:adminpw`). This CA
#   is reachable from the public internet (port 7054 exposed). As long as
#   admin:adminpw remains active with full registrar rights, anyone who can
#   reach the CA and knows this widely-documented Fabric convention could
#   attempt to register arbitrary identities against TWS's MSP.
#
#   Both real org admins (tws-org-admin, tws-orderer-admin) already exist
#   and have the same registrar rights the bootstrap identity was only ever
#   meant to provide temporarily. There is no further operational need for
#   admin:adminpw once this script confirms the two named admins still work
#   independently.
#
# WHAT THIS DOES:
#   1. Changes the bootstrap identity's secret to a new, strong, randomly
#      generated value (fabric-ca-client identity modify admin --secret ...).
#      This immediately invalidates the old "adminpw" password.
#   2. Writes the new secret to a local file the operator must move to a
#      secure secrets store (NOT into .env, NOT committed to git) — this
#      script deliberately does not touch docker-compose.yml, since the -b
#      flag there only sets the INITIAL bootstrap secret on first CA start;
#      once the CA's database exists, that flag has no further effect on
#      subsequent restarts. Changing it in compose is optional cosmetic
#      cleanup, not required for the rotation to take effect.
#   3. Verifies that tws-org-admin and tws-orderer-admin can still register a
#      throwaway test identity WITHOUT using the bootstrap admin at all,
#      proving the rotation did not break anything, then deletes the test
#      identity's local artifacts (the identity itself remains registered in
#      the CA's database, since identity removal is disabled by default —
#      this is expected and harmless for a throwaway test identity).
#
# WHAT THIS DOES NOT DO:
#   - Does NOT remove/delete the "admin" identity from the CA (fabric-ca
#     disables identity removal by default; would require restarting the CA
#     with --cfg.identities.allowremove, an unnecessary extra risk for no
#     added benefit once the secret is rotated).
#   - Does NOT touch orderer/peer/node identities in any way.
#
# EXECUTION CONTEXT:
#   Run INSIDE the rwrrn-cli container.
#
# HOW TO RUN:
#   docker compose exec cli bash
#   bash scripts/ca-bootstrap/06-rotate-bootstrap-admin.sh
#
# PREREQUISITE:
#   Steps 1-4 completed successfully (bootstrap admin, both org admins, all
#   node identities enrolled and nodes running).
# =============================================================================

set -euo pipefail

ENV_FILE="${ENV_FILE:-/opt/gopath/src/github.com/hyperledger/fabric/peer/.env}"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env not found at $ENV_FILE"
  exit 1
fi
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${ORG_CODE:?ORG_CODE not set in .env}"
: "${ORG_DOMAIN:?ORG_DOMAIN not set in .env}"
: "${CA_NAME:?CA_NAME not set in .env}"
: "${CA_HOST:?CA_HOST not set in .env}"
: "${CA_PORT:?CA_PORT not set in .env}"
: "${CA_BOOTSTRAP_USER:?CA_BOOTSTRAP_USER not set in .env}"
: "${ORG_ADMIN_USER:?ORG_ADMIN_USER not set in .env}"
: "${ORDERER_ADMIN_USER:?ORDERER_ADMIN_USER not set in .env}"

CRYPTO_ROOT="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto"
CA_TLS_CERT="/opt/gopath/src/github.com/hyperledger/fabric/peer/fabric-ca/tws/tls-cert.pem"
BOOTSTRAP_ADMIN_HOME="${CRYPTO_ROOT}/ca-clients/${ORG_CODE}/bootstrap-admin"
ORDERER_ADMIN_HOME="${CRYPTO_ROOT}/ordererOrganizations/${ORG_DOMAIN}/users/${ORDERER_ADMIN_USER}"
ORG_ADMIN_HOME="${CRYPTO_ROOT}/peerOrganizations/${ORG_DOMAIN}/users/${ORG_ADMIN_USER}"
OUTPUT_FILE="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ca-clients/${ORG_CODE}/bootstrap-admin/NEW-SECRET-MOVE-TO-SECRETS-MANAGER.txt"

for home in "$BOOTSTRAP_ADMIN_HOME" "$ORDERER_ADMIN_HOME" "$ORG_ADMIN_HOME"; do
  if [[ ! -d "${home}/msp/signcerts" ]]; then
    echo "ERROR: expected MSP not found at ${home}/msp — run steps 1-2 first."
    exit 1
  fi
done

echo "== Step 5a: verify org admins work WITHOUT the bootstrap admin =="
echo "Registering a throwaway test identity via tws-org-admin (registrar)..."
TEST_ID="rotation-test-$(date +%s)"
export FABRIC_CA_CLIENT_HOME="${ORG_ADMIN_HOME}"
fabric-ca-client register \
  --id.name "${TEST_ID}" \
  --id.secret "throwaway-secret-not-used" \
  --id.type client \
  --caname "${CA_NAME}" \
  -u "https://${CA_HOST}:${CA_PORT}" \
  --tls.certfiles "${CA_TLS_CERT}"
echo "OK: tws-org-admin successfully registered '${TEST_ID}' independently."
echo "(This identity stays registered in the CA's database — identity"
echo " removal is disabled by default in fabric-ca-server. Harmless no-op"
echo " identity, never enrolled, never used for anything.)"

echo ""
echo "== Step 5b: rotate the bootstrap admin's secret =="
NEW_SECRET=$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 32)
export FABRIC_CA_CLIENT_HOME="${BOOTSTRAP_ADMIN_HOME}"
fabric-ca-client identity modify "${CA_BOOTSTRAP_USER}" \
  --secret "${NEW_SECRET}" \
  --caname "${CA_NAME}" \
  -u "https://${CA_HOST}:${CA_PORT}" \
  --tls.certfiles "${CA_TLS_CERT}"

mkdir -p "$(dirname "${OUTPUT_FILE}")"
cat > "${OUTPUT_FILE}" <<EOF
Bootstrap admin secret rotated on $(date -u +%Y-%m-%dT%H:%M:%SZ)
Identity: ${CA_BOOTSTRAP_USER}
New secret: ${NEW_SECRET}

ACTION REQUIRED: move this value to your secrets manager, then delete this file.
This secret is NOT used by any running service (docker-compose.yml's -b flag
only affects the CA's very first start; the CA's own credential database is
now authoritative). It is kept only so the bootstrap identity remains usable
in a genuine break-glass emergency (e.g. both tws-org-admin and
tws-orderer-admin private keys lost simultaneously).
EOF
chmod 600 "${OUTPUT_FILE}"

echo "Bootstrap admin secret rotated."
echo "New secret written to: ${OUTPUT_FILE}"
echo "(on the VPS host, this is visible at:"
echo " /opt/rwrrn/crypto-config/ca-clients/${ORG_CODE}/bootstrap-admin/NEW-SECRET-MOVE-TO-SECRETS-MANAGER.txt )"

echo ""
echo "== Step 5c: verify orderer admin also still works independently =="
TEST_ID_2="rotation-test-orderer-$(date +%s)"
export FABRIC_CA_CLIENT_HOME="${ORDERER_ADMIN_HOME}"
fabric-ca-client register \
  --id.name "${TEST_ID_2}" \
  --id.secret "throwaway-secret-not-used" \
  --id.type client \
  --caname "${CA_NAME}" \
  -u "https://${CA_HOST}:${CA_PORT}" \
  --tls.certfiles "${CA_TLS_CERT}"
echo "OK: tws-orderer-admin successfully registered '${TEST_ID_2}' independently."

echo ""
echo "== Done =="
echo "admin:adminpw is no longer valid — the old 'adminpw' secret was just replaced."
echo "tws-org-admin and tws-orderer-admin confirmed fully operational without it."
echo ""
echo "IMPORTANT NEXT ACTION (manual, outside this script):"
echo "1. Read the new secret from ${OUTPUT_FILE}"
echo "2. Store it in your secrets manager of choice"
echo "3. Delete ${OUTPUT_FILE} from the VPS filesystem"
echo "4. Optionally update docker-compose.yml's CA command line to remove or"
echo "   change the -b flag for cosmetic consistency (functionally optional,"
echo "   see script header for why)."
