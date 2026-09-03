#!/bin/bash
# =============================================================================
# scripts/ca-bootstrap/04-copy-admincerts-to-nodes.sh
# =============================================================================
# Step 4 of the RWRRN crypto-material bootstrap sequence.
#
# WHY THIS IS NEEDED:
#   Orderer/peer startup failed with:
#     "administrators must be declared when no admin ou classification is set"
#   Even with NodeOUs enabled (config.yaml present with AdminOUIdentifier),
#   Fabric's local MSP loader still requires at least one certificate in
#   admincerts/ for each node's local MSP folder — this is what lets Fabric
#   resolve "who is an admin of this MSP" when the node starts up, independent
#   of channel-level MSP config (which is a separate, later concern once we
#   create channels).
#
# WHAT THIS DOES:
#   Copies the enrolled org-admin certificate into admincerts/ for every
#   node's local MSP:
#     - tws-orderer-admin's cert -> orderer0/msp/admincerts/, orderer1/msp/admincerts/
#     - tws-org-admin's cert     -> peer0/msp/admincerts/,   peer1/msp/admincerts/
#   Also copies each org-admin's own MSP folder into a top-level
#   crypto-config/.../msp location (Fabric convention: <org>/msp/admincerts
#   at the organization level, used later for channel/genesis config), so
#   this material is ready for the channel-creation step too.
#
# EXECUTION CONTEXT:
#   Can run on the VPS HOST directly (plain file copy, no fabric-ca-client
#   needed) — no need to enter any container for this step.
#
# HOW TO RUN:
#   cd /opt/rwrrn
#   bash scripts/ca-bootstrap/04-copy-admincerts-to-nodes.sh
# =============================================================================

set -euo pipefail

ENV_FILE="${ENV_FILE:-/opt/rwrrn/.env}"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env not found at $ENV_FILE"
  exit 1
fi
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${ORG_DOMAIN:?ORG_DOMAIN not set in .env}"
: "${ORG_ADMIN_USER:?ORG_ADMIN_USER not set in .env}"
: "${ORDERER_ADMIN_USER:?ORDERER_ADMIN_USER not set in .env}"
: "${ORDERER0_NAME:?ORDERER0_NAME not set in .env}"
: "${ORDERER1_NAME:?ORDERER1_NAME not set in .env}"
: "${PEER0_NAME:?PEER0_NAME not set in .env}"
: "${PEER1_NAME:?PEER1_NAME not set in .env}"

CRYPTO_ROOT="/opt/rwrrn/crypto-config"
ORDERER_ADMIN_CERT="${CRYPTO_ROOT}/ordererOrganizations/${ORG_DOMAIN}/users/${ORDERER_ADMIN_USER}/msp/signcerts/cert.pem"
ORG_ADMIN_CERT="${CRYPTO_ROOT}/peerOrganizations/${ORG_DOMAIN}/users/${ORG_ADMIN_USER}/msp/signcerts/cert.pem"

if [[ ! -f "$ORDERER_ADMIN_CERT" ]]; then
  echo "ERROR: orderer admin cert not found at $ORDERER_ADMIN_CERT"
  exit 1
fi
if [[ ! -f "$ORG_ADMIN_CERT" ]]; then
  echo "ERROR: org admin cert not found at $ORG_ADMIN_CERT"
  exit 1
fi

copy_admincert() {
  local admin_cert="$1"
  local node_msp_dir="$2"
  mkdir -p "${node_msp_dir}/admincerts"
  cp "${admin_cert}" "${node_msp_dir}/admincerts/cert.pem"
  echo "Copied admin cert -> ${node_msp_dir}/admincerts/cert.pem"
}

echo "== Orderer nodes (admin: ${ORDERER_ADMIN_USER}) =="
copy_admincert "${ORDERER_ADMIN_CERT}" \
  "${CRYPTO_ROOT}/ordererOrganizations/${ORG_DOMAIN}/orderers/${ORDERER0_NAME}/msp"
copy_admincert "${ORDERER_ADMIN_CERT}" \
  "${CRYPTO_ROOT}/ordererOrganizations/${ORG_DOMAIN}/orderers/${ORDERER1_NAME}/msp"

echo ""
echo "== Peer nodes (admin: ${ORG_ADMIN_USER}) =="
copy_admincert "${ORG_ADMIN_CERT}" \
  "${CRYPTO_ROOT}/peerOrganizations/${ORG_DOMAIN}/peers/${PEER0_NAME}/msp"
copy_admincert "${ORG_ADMIN_CERT}" \
  "${CRYPTO_ROOT}/peerOrganizations/${ORG_DOMAIN}/peers/${PEER1_NAME}/msp"

echo ""
echo "== Org-level admincerts (for later channel/genesis config) =="
mkdir -p "${CRYPTO_ROOT}/ordererOrganizations/${ORG_DOMAIN}/msp/admincerts"
cp "${ORDERER_ADMIN_CERT}" "${CRYPTO_ROOT}/ordererOrganizations/${ORG_DOMAIN}/msp/admincerts/cert.pem"
mkdir -p "${CRYPTO_ROOT}/peerOrganizations/${ORG_DOMAIN}/msp/admincerts"
cp "${ORG_ADMIN_CERT}" "${CRYPTO_ROOT}/peerOrganizations/${ORG_DOMAIN}/msp/admincerts/cert.pem"
echo "Org-level admincerts staged for channel bootstrap step."

echo ""
echo "== Done =="
echo "Restart orderer0 to verify the panic is resolved:"
echo "  docker compose up -d orderer0.tws.rwrrn.recordweb.dev"
echo "  docker compose logs orderer0.tws.rwrrn.recordweb.dev --tail=30"
echo "Do not start all four nodes at once yet — verify orderer0 first."
