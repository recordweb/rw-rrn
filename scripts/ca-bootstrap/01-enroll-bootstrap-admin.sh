#!/bin/bash
# =============================================================================
# scripts/ca-bootstrap/01-enroll-bootstrap-admin.sh
# =============================================================================
# Step 1 of the RWRRN crypto-material bootstrap sequence.
#
# CURRENT EXECUTION CONTEXT (temporary — see note at bottom):
#   Runs INSIDE the CA container (ca.tws.rwrrn.recordweb.dev), because that
#   image (hyperledger/fabric-ca:1.5) bundles fabric-ca-client, whereas the
#   `cli` container (hyperledger/fabric-tools:2.5) does not.
#
#   This is a deliberate interim choice (Option A). The project intends to
#   switch later to Option B: a dedicated `fabric-ca-tools` service in
#   docker-compose.yml, so the CA container stays a pure server and the CLI
#   container stays a pure peer/orderer admin client. Do not treat the paths
#   below as final — they will move when Option B lands.
#
# WHAT THIS DOES:
#   Enrolls the Fabric CA's built-in bootstrap identity (admin:adminpw, set
#   via `fabric-ca-server start -b admin:adminpw` in docker-compose.yml) as a
#   Fabric CA *client* identity. Produces a local MSP folder (cert + private
#   key) used for all subsequent `fabric-ca-client register` calls (Step 2+).
#
# WHAT THIS DOES NOT DO:
#   - Does NOT create orderer/peer/org-admin identities yet (Step 2 onward).
#   - Does NOT touch docker-compose.yml or restart any container.
#   - Idempotent: if the bootstrap admin's MSP already exists, exits without
#     re-enrolling (re-enrolling deliberately requires deleting the folder
#     first — never a silent side effect of re-running this script).
#
# HOW TO RUN (manually, via SSH on the VPS, NOT via the deploy workflow):
#   cd /opt/rw-rrn
#   docker compose exec ca.tws.rwrrn.recordweb.dev bash
#   bash /etc/hyperledger/scripts/ca-bootstrap/01-enroll-bootstrap-admin.sh
#
# PREREQUISITE:
#   docker-compose.yml must mount, on the CA service:
#     - ./crypto-config:/etc/hyperledger/crypto-config
#     - ./.env:/etc/hyperledger/.env:ro
#     - ./scripts:/etc/hyperledger/scripts:ro
# =============================================================================

set -euo pipefail

# --- Load configuration ------------------------------------------------------
ENV_FILE="${ENV_FILE:-/etc/hyperledger/.env}"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env not found at $ENV_FILE"
  echo "Check the CA service's volume mounts in docker-compose.yml."
  exit 1
fi
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${ORG_CODE:?ORG_CODE not set in .env}"
: "${CA_NAME:?CA_NAME not set in .env}"
: "${CA_HOST:?CA_HOST not set in .env}"
: "${CA_PORT:?CA_PORT not set in .env}"
: "${CA_BOOTSTRAP_USER:?CA_BOOTSTRAP_USER not set in .env}"
: "${CA_BOOTSTRAP_PASS:?CA_BOOTSTRAP_PASS not set in .env}"

# --- Paths --------------------------------------------------------------------
# NOTE: output is written under /etc/hyperledger/crypto-config, which is
# bind-mounted from ./crypto-config in the repo root — the SAME host folder
# the cli container and the orderer/peer containers already use. This keeps
# a single, shared crypto-config tree regardless of which container performs
# the enrollment.
FABRIC_CA_CLIENT_HOME="/etc/hyperledger/crypto-config/ca-clients/${ORG_CODE}/bootstrap-admin"
CA_TLS_CERT="/etc/hyperledger/fabric-ca-server/tls-cert.pem"

echo "== Step 1: Enroll CA bootstrap admin (${CA_BOOTSTRAP_USER}) =="
echo "CA:          https://${CA_HOST}:${CA_PORT} (name: ${CA_NAME})"
echo "Client home: ${FABRIC_CA_CLIENT_HOME}"

# --- Idempotency check --------------------------------------------------------
if [[ -d "${FABRIC_CA_CLIENT_HOME}/msp/signcerts" ]] && \
   [[ -n "$(ls -A "${FABRIC_CA_CLIENT_HOME}/msp/signcerts" 2>/dev/null)" ]]; then
  echo "Bootstrap admin already enrolled at ${FABRIC_CA_CLIENT_HOME}/msp — skipping."
  echo "(Delete that folder manually first if you intentionally want to re-enroll.)"
  exit 0
fi

# --- Sanity check: is the CA's own TLS cert available locally? ---------------
# Since we're running inside the CA container itself, this file is always
# present at this path once the server has started at least once.
if [[ ! -f "$CA_TLS_CERT" ]]; then
  echo "ERROR: CA TLS cert not found at $CA_TLS_CERT"
  echo "This is unexpected when running inside the CA container itself —"
  echo "check that the server has started successfully at least once."
  exit 1
fi

mkdir -p "${FABRIC_CA_CLIENT_HOME}"
export FABRIC_CA_CLIENT_HOME

# --- Enroll --------------------------------------------------------------------
fabric-ca-client enroll \
  -u "https://${CA_BOOTSTRAP_USER}:${CA_BOOTSTRAP_PASS}@${CA_HOST}:${CA_PORT}" \
  --caname "${CA_NAME}" \
  --tls.certfiles "${CA_TLS_CERT}"

echo ""
echo "== Done =="
echo "Bootstrap admin enrolled. MSP written to:"
echo "  ${FABRIC_CA_CLIENT_HOME}/msp"
echo "(this path is inside ./crypto-config on the VPS host, so it will also"
echo " be visible from the cli container / after switching to Option B)"
echo ""
echo "Next step (Step 2): register the real org admin identity, then register"
echo "and enroll orderer0/orderer1/peer0/peer1. Do NOT proceed automatically —"
echo "confirm this step's output first."