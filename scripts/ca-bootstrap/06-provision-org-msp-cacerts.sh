#!/bin/bash
# =============================================================================
# scripts/ca-bootstrap/06-provision-org-msp-cacerts.sh
# =============================================================================
# Step 6 of the RWRRN crypto-material bootstrap sequence.

# WHY THIS IS NEEDED:
# configtxgen requires each Organization's top-level MSP directory
# (Organizations[].MSPDir in configtx.yaml, e.g.
# ordererOrganizations/<domain>/msp and peerOrganizations/<domain>/msp) to
# contain a valid CA root certificate under msp/cacerts/, plus a NodeOUs
# config.yaml. Steps 01-04 only ever wrote node-level MSPs
# (orderers/<node>/msp, peers/<node>/msp) and admin identities
# (users/<admin>/msp) — nobody ever populated the org-level msp/cacerts/,
# because a live Fabric CA (unlike cryptogen) does not create this
# directory automatically. Without it, configtxgen fails at channel/genesis
# bootstrap time with:
#   "could not load a valid ca certificate from directory
#   .../msp/cacerts: stat ...: no such file or directory"
# (hit and fixed 2026-09-03, during Stage 1 Step 2 channel bootstrap).

# WHAT THIS DOES:
# For both the orderer org (TWSOrdererMSP) and the peer org (TWSOrgMSP):
#   1. Takes the CA root certificate already present in a node's enrolled
#      MSP (orderers/<node0>/msp/cacerts/*.pem) as the authoritative source
#      — it is the same root CA for every identity in this organisation,
#      since all identities are issued by the same Fabric CA server.
#   2. Copies it into the org-level msp/cacerts/ directory.
#   3. Writes the matching NodeOUs config.yaml (same pattern as Step 03's
#      write_node_ou_config, applied here at org level).
# Admincerts at org level are already handled by Step 04 — this script does
# not touch them.

# EXECUTION CONTEXT:
# Run INSIDE the rwrrn-cli container (same as Steps 02/03).

# HOW TO RUN:
#   docker compose exec cli bash
#   bash scripts/ca-bootstrap/06-provision-org-msp-cacerts.sh

# PREREQUISITE:
# Step 03 has completed for at least orderer0 and peer0 (their node MSPs
# must already contain msp/cacerts/*.pem — this is where we copy from).

# IDEMPOTENT: if an org-level msp/cacerts/ already contains a .pem file,
# that organisation's copy step is skipped. Safe to re-run.
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

: "${ORG_DOMAIN:?ORG_DOMAIN not set in .env}"
: "${ORDERER0_NAME:?ORDERER0_NAME not set in .env}"
: "${PEER0_NAME:?PEER0_NAME not set in .env}"

CRYPTO_ROOT="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto"

write_org_ou_config() {
  local msp_dir="$1"
  local ca_cert_file
  ca_cert_file="$(ls "${msp_dir}/cacerts" | head -n1)"
  cat > "${msp_dir}/config.yaml" <<EOF
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/${ca_cert_file}
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/${ca_cert_file}
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/${ca_cert_file}
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/${ca_cert_file}
    OrganizationalUnitIdentifier: orderer
EOF
  echo "Wrote NodeOUs config -> ${msp_dir}/config.yaml"
}

provision_org_msp() {
  local org_label="$1"
  local source_node_msp="$2"
  local org_msp_dir="$3"

  echo ""
  echo "---- ${org_label} ----"

  if [[ -d "${org_msp_dir}/cacerts" ]] && \
     [[ -n "$(ls -A "${org_msp_dir}/cacerts" 2>/dev/null)" ]]; then
    echo "Org-level cacerts already present at ${org_msp_dir}/cacerts — skipping copy."
  else
    if [[ ! -d "${source_node_msp}/cacerts" ]] || \
       [[ -z "$(ls -A "${source_node_msp}/cacerts" 2>/dev/null)" ]]; then
      echo "ERROR: source node MSP cacerts not found or empty at ${source_node_msp}/cacerts"
      echo "Run Step 03 (03-register-enroll-nodes.sh) first."
      return 1
    fi
    mkdir -p "${org_msp_dir}/cacerts"
    cp "${source_node_msp}/cacerts/"*.pem "${org_msp_dir}/cacerts/"
    chmod 644 "${org_msp_dir}/cacerts/"*.pem
    echo "Copied CA root cert -> ${org_msp_dir}/cacerts/"
  fi

  if [[ -f "${org_msp_dir}/config.yaml" ]]; then
    echo "config.yaml already present at ${org_msp_dir} — skipping."
  else
    write_org_ou_config "${org_msp_dir}"
  fi
}

# --- Orderer org (TWSOrdererMSP) --------------------------------------------
provision_org_msp \
  "Orderer org (TWSOrdererMSP)" \
  "${CRYPTO_ROOT}/ordererOrganizations/${ORG_DOMAIN}/orderers/${ORDERER0_NAME}/msp" \
  "${CRYPTO_ROOT}/ordererOrganizations/${ORG_DOMAIN}/msp"

# --- Peer org (TWSOrgMSP) ----------------------------------------------------
provision_org_msp \
  "Peer org (TWSOrgMSP)" \
  "${CRYPTO_ROOT}/peerOrganizations/${ORG_DOMAIN}/peers/${PEER0_NAME}/msp" \
  "${CRYPTO_ROOT}/peerOrganizations/${ORG_DOMAIN}/msp"

echo ""
echo "== Verify =="
echo "-- Orderer org MSP --"
find "${CRYPTO_ROOT}/ordererOrganizations/${ORG_DOMAIN}/msp" -maxdepth 2
echo ""
echo "-- Peer org MSP --"
find "${CRYPTO_ROOT}/peerOrganizations/${ORG_DOMAIN}/msp" -maxdepth 2

echo ""
echo "== Done =="
echo "Org-level MSPs are now complete (admincerts + cacerts + config.yaml)."
echo "Next: retry the configtxgen dry run (Stage 1 Step 2.3)."
