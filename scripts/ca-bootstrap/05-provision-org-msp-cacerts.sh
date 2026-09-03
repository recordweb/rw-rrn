#!/bin/bash
# =============================================================================
# scripts/ca-bootstrap/05-provision-org-msp-cacerts.sh
# =============================================================================
# Step 6 of the RWRRN crypto-material bootstrap sequence.

# v2 CHANGE (2026-09-03): also provisions msp/tlscacerts/ at the org level,
# in addition to msp/cacerts/. Both are required, for two DIFFERENT Fabric
# subsystems:
#   - msp/cacerts/      -> used by configtxgen when validating/loading the
#                          Organization's MSP (signing/identity CA).
#   - msp/tlscacerts/   -> used by the ORDERER CLUSTER layer (BFT/Raft
#                          inter-consenter gRPC) to build each org's
#                          ServerRootCAs via msp.GetTLSRootCerts(), which
#                          reads ONLY tlscacerts/, never cacerts/. Without
#                          it, orderers fail to connect to each other with:
#                            "server root CA cert is nil"
#                            (orderer/common/cluster/connectionsmgr.go)
#                          and the peer side sees:
#                            "tls: bad certificate"
#                          (hit and fixed 2026-09-03, during Stage 1 Step
#                          2.5 — all 4 orderers individually joined the
#                          channel via osnadmin, but SmartBFT cluster
#                          communication between them then failed).
# Since our CA issues one certificate that serves as root for both regular
# (ecert) and TLS enrollments (single Fabric CA, no separate TLS sub-CA),
# the SAME .pem file is copied into both cacerts/ and tlscacerts/.

# WHY THIS IS NEEDED (original v1 rationale, still applies to cacerts/):
# configtxgen requires each Organization's top-level MSP directory
# (Organizations[].MSPDir in configtx.yaml) to contain a valid CA root
# certificate under msp/cacerts/, plus a NodeOUs config.yaml. Steps 01-04
# only ever wrote node-level MSPs and admin identities — nobody ever
# populated the org-level msp/cacerts/ or msp/tlscacerts/, because a live
# Fabric CA (unlike cryptogen) does not create these directories
# automatically.

# WHAT THIS DOES:
# For both the orderer org (TWSOrdererMSP) and the peer org (TWSOrgMSP):
#   1. Takes the CA root certificate already present in a node's enrolled
#      MSP (orderers/<node0>/msp/cacerts/*.pem) as the authoritative source
#      — it is the same root CA for every identity in this organisation.
#   2. Copies it into the org-level msp/cacerts/ directory (for configtxgen
#      / regular MSP validation).
#   3. Copies it into the org-level msp/tlscacerts/ directory (for orderer
#      cluster TLS trust — see v2 note above).
#   4. Writes the matching NodeOUs config.yaml (same pattern as Step 03's
#      write_node_ou_config, applied here at org level).
# Admincerts at org level are already handled by Step 04 — this script does
# not touch them.

# EXECUTION CONTEXT:
# Run INSIDE the rwrrn-cli container (same as Steps 02/03).

# HOW TO RUN:
#   docker compose exec cli bash
#   bash scripts/ca-bootstrap/05-provision-org-msp-cacerts.sh

# PREREQUISITE:
# Step 03 has completed for at least orderer0 and peer0 (their node MSPs
# must already contain msp/cacerts/*.pem — this is where we copy from).

# IDEMPOTENT: if an org-level msp/cacerts/ or msp/tlscacerts/ already
# contains a .pem file, that copy step is skipped individually. Safe to
# re-run (e.g. after upgrading from v1 of this script, running it again
# will backfill the missing tlscacerts/ without redoing cacerts/).

# AFTER RUNNING THIS SCRIPT (v2 upgrade from v1):
# If orderers were already started/joined to a channel before tlscacerts/
# existed at the org level, restart ALL orderer containers (one at a time,
# checking logs after each) so they re-read the org MSP with tlscacerts/
# now present:
#   docker compose restart orderer0.tws.rwrrn.recordweb.dev
#   docker compose logs orderer0.tws.rwrrn.recordweb.dev --tail=30
#   (repeat for orderer1, orderer2, orderer3, one at a time)
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

copy_ca_cert_into() {
  local label="$1"
  local source_dir="$2"
  local dest_dir="$3"

  if [[ -d "${dest_dir}" ]] && [[ -n "$(ls -A "${dest_dir}" 2>/dev/null)" ]]; then
    echo "${label} already present at ${dest_dir} — skipping copy."
    return 0
  fi
  if [[ ! -d "${source_dir}" ]] || [[ -z "$(ls -A "${source_dir}" 2>/dev/null)" ]]; then
    echo "ERROR: source cacerts not found or empty at ${source_dir}"
    echo "Run Step 03 (03-register-enroll-nodes.sh) first."
    return 1
  fi
  mkdir -p "${dest_dir}"
  cp "${source_dir}/"*.pem "${dest_dir}/"
  chmod 644 "${dest_dir}/"*.pem
  echo "Copied CA root cert -> ${dest_dir}/ (${label})"
}

provision_org_msp() {
  local org_label="$1"
  local source_node_msp="$2"
  local org_msp_dir="$3"

  echo ""
  echo "---- ${org_label} ----"

  copy_ca_cert_into "cacerts (MSP/configtxgen)" \
    "${source_node_msp}/cacerts" \
    "${org_msp_dir}/cacerts"

  copy_ca_cert_into "tlscacerts (orderer cluster TLS trust)" \
    "${source_node_msp}/cacerts" \
    "${org_msp_dir}/tlscacerts"

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
echo "Org-level MSPs now have cacerts + tlscacerts + admincerts + config.yaml."
echo "If orderers were already running/joined before tlscacerts/ existed,"
echo "restart them ONE AT A TIME now (see header comment) so the cluster"
echo "layer picks up the org TLS root CA."
