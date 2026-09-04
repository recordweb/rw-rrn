#!/bin/bash
# =============================================================================
# scripts/ca-bootstrap/04-copy-admincerts-to-nodes.sh
# =============================================================================
# Step 4 of the RWRRN crypto-material bootstrap sequence.
#
# v2 CHANGE: extended from 2 to 4 orderers (orderer0-orderer3) for the
# SmartBFT expansion. Peers remain at 2 (peer0/peer1).
#
# WHY THIS IS NEEDED:
#   Orderer/peer startup fails with:
#     "administrators must be declared when no admin ou classification is set"
#   unless admincerts/ contains at least one certificate per node's local MSP.
#
# EXECUTION CONTEXT:
#   Run on the VPS HOST directly (plain file copy, no fabric-ca-client
#   needed) — no need to enter any container. Requires sudo if crypto-config
#   files are owned by root (they are, since the CA container writes them
#   as root).
#
# HOW TO RUN:
#   cd /opt/rw-rrn
#   sudo bash scripts/ca-bootstrap/04-copy-admincerts-to-nodes.sh
#
# PREREQUISITE:
#   Step 3 (v4) has run successfully for all four orderers and both peers.
# =============================================================================

set -euo pipefail

ENV_FILE="${ENV_FILE:-/opt/rw-rrn/.env}"
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
: "${ORDERER2_NAME:?ORDERER2_NAME not set in .env}"
: "${ORDERER3_NAME:?ORDERER3_NAME not set in .env}"
: "${PEER0_NAME:?PEER0_NAME not set in .env}"
: "${PEER1_NAME:?PEER1_NAME not set in .env}"

CRYPTO_ROOT="/opt/rw-rrn/crypto-config"
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
  if [[ -f "${node_msp_dir}/admincerts/cert.pem" ]]; then
    echo "admincert already present at ${node_msp_dir}/admincerts/cert.pem — skipping."
    return 0
  fi
  mkdir -p "${node_msp_dir}/admincerts"
  cp "${admin_cert}" "${node_msp_dir}/admincerts/cert.pem"
  chmod 644 "${node_msp_dir}/admincerts/cert.pem"
  echo "Copied admin cert -> ${node_msp_dir}/admincerts/cert.pem"
}

echo "== Orderer nodes (admin: ${ORDERER_ADMIN_USER}) =="
for node_name in "${ORDERER0_NAME}" "${ORDERER1_NAME}" "${ORDERER2_NAME}" "${ORDERER3_NAME}"; do
  copy_admincert "${ORDERER_ADMIN_CERT}" \
    "${CRYPTO_ROOT}/ordererOrganizations/${ORG_DOMAIN}/orderers/${node_name}/msp"
done

echo ""
echo "== Peer nodes (admin: ${ORG_ADMIN_USER}) =="
for node_name in "${PEER0_NAME}" "${PEER1_NAME}"; do
  copy_admincert "${ORG_ADMIN_CERT}" \
    "${CRYPTO_ROOT}/peerOrganizations/${ORG_DOMAIN}/peers/${node_name}/msp"
done

echo ""
echo "== Org-level admincerts (for later channel/genesis config) =="
mkdir -p "${CRYPTO_ROOT}/ordererOrganizations/${ORG_DOMAIN}/msp/admincerts"
cp "${ORDERER_ADMIN_CERT}" "${CRYPTO_ROOT}/ordererOrganizations/${ORG_DOMAIN}/msp/admincerts/cert.pem"
mkdir -p "${CRYPTO_ROOT}/peerOrganizations/${ORG_DOMAIN}/msp/admincerts"
cp "${ORG_ADMIN_CERT}" "${CRYPTO_ROOT}/peerOrganizations/${ORG_DOMAIN}/msp/admincerts/cert.pem"
chmod 644 "${CRYPTO_ROOT}/ordererOrganizations/${ORG_DOMAIN}/msp/admincerts/cert.pem"
chmod 644 "${CRYPTO_ROOT}/peerOrganizations/${ORG_DOMAIN}/msp/admincerts/cert.pem"
echo "Org-level admincerts staged for channel bootstrap step."

echo ""
echo "== Done =="
echo "Start orderer2 and orderer3 ONE AT A TIME to verify:"
echo "  docker compose up -d orderer2.tws.rwrrn.recordweb.dev"
echo "  docker compose logs orderer2.tws.rwrrn.recordweb.dev --tail=30"
echo "  (then) docker compose up -d orderer3.tws.rwrrn.recordweb.dev"
echo "  docker compose logs orderer3.tws.rwrrn.recordweb.dev --tail=30"
echo "Do not start all remaining services at once yet."
