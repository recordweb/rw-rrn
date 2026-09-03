#!/bin/bash
# =============================================================================
# scripts/ca-bootstrap/02-register-enroll-org-admins.sh
# =============================================================================
# Step 2 of the RWRRN crypto-material bootstrap sequence.
#
# EXECUTION CONTEXT (temporary — Option A, see note in Step 1 script):
#   Run INSIDE the CA container (ca.tws.rwrrn.recordweb.dev).
#
# WHAT THIS DOES:
#   Using the bootstrap admin's MSP from Step 1, registers and enrolls TWO
#   real, named admin identities with the CA:
#     - tws-org-admin      -> admin for TWSOrgMSP (peers)
#     - tws-orderer-admin  -> admin for TWSOrdererMSP (orderers)
#   Both get the `admin` type and full registrar rights, so each can later
#   register further identities (orderer/peer nodes) for its own MSP.
#
# WHAT THIS DOES NOT DO:
#   - Does NOT create orderer0/orderer1/peer0/peer1 identities (Step 3+).
#   - Does NOT rotate/disable the CA bootstrap admin yet (Step 4, after we've
#     verified these two admins work).
#   - Idempotent per-identity: if an admin's MSP already exists locally, its
#     enrollment is skipped; if the CA already has the identity registered
#     (e.g. partial previous run), registration errors are treated as
#     non-fatal ("already registered") and enrollment still proceeds.
#
# FIX v2 vs. previous versions: fabric-ca-client's --id.attrs parser splits
# on EVERY comma in the whole argument, no backslash-escaping honored. The
# value list for hf.Registrar.Roles must instead be wrapped in double quotes
# INSIDE the attribute string (name=value pair with a quoted value), per the
# Fabric CA documentation, e.g.:  --id.attrs '"hf.Registrar.Roles=client,orderer,peer,admin"'
# i.e. the outer shell quoting must preserve literal double quotes as part
# of the value passed to the CA client, which then treats the double-quoted
# segment as one atomic field despite the embedded commas.
#
# HOW TO RUN:
#   docker compose exec ca.tws.rwrrn.recordweb.dev bash
#   bash /etc/hyperledger/scripts/ca-bootstrap/02-register-enroll-org-admins.sh
#
# PREREQUISITE:
#   Step 1 script has run successfully (bootstrap admin MSP exists).
# =============================================================================

set -euo pipefail

ENV_FILE="${ENV_FILE:-/etc/hyperledger/.env}"
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
: "${ORG_ADMIN_USER:?ORG_ADMIN_USER not set in .env}"
: "${ORG_ADMIN_PASS:?ORG_ADMIN_PASS not set in .env}"
: "${ORDERER_ADMIN_USER:?ORDERER_ADMIN_USER not set in .env}"
: "${ORDERER_ADMIN_PASS:?ORDERER_ADMIN_PASS not set in .env}"
: "${PEER_MSP_ID:?PEER_MSP_ID not set in .env}"
: "${ORDERER_MSP_ID:?ORDERER_MSP_ID not set in .env}"

CRYPTO_ROOT="/etc/hyperledger/crypto-config"
BOOTSTRAP_ADMIN_HOME="${CRYPTO_ROOT}/ca-clients/${ORG_CODE}/bootstrap-admin"
CA_TLS_CERT="/etc/hyperledger/fabric-ca-server/tls-cert.pem"

if [[ ! -d "${BOOTSTRAP_ADMIN_HOME}/msp/signcerts" ]]; then
  echo "ERROR: bootstrap admin MSP not found at ${BOOTSTRAP_ADMIN_HOME}/msp"
  echo "Run Step 1 (01-enroll-bootstrap-admin.sh) first."
  exit 1
fi

# --- Helper: register (idempotent) + enroll one admin identity -------------
register_and_enroll_admin() {
  local id_name="$1"
  local id_secret="$2"
  local msp_id="$3"
  local target_home="$4"

  echo ""
  echo "---- ${id_name} (MSP: ${msp_id}) ----"

  if [[ -d "${target_home}/msp/signcerts" ]] && \
     [[ -n "$(ls -A "${target_home}/msp/signcerts" 2>/dev/null)" ]]; then
    echo "${id_name} already enrolled at ${target_home}/msp — skipping."
    return 0
  fi

  # Register using the bootstrap admin's identity as registrar.
  # NOTE: the roles list is wrapped in literal double quotes as part of the
  # attribute value (\"...\") so fabric-ca-client treats the comma-separated
  # list as one field instead of splitting on every comma.
  export FABRIC_CA_CLIENT_HOME="${BOOTSTRAP_ADMIN_HOME}"
  echo "Registering ${id_name} with CA..."
  set +e
  register_output=$(fabric-ca-client register \
    --id.name "${id_name}" \
    --id.secret "${id_secret}" \
    --id.type admin \
    --id.attrs "\"hf.Registrar.Roles=client,orderer,peer,admin\"" \
    --id.attrs "hf.Registrar.Attributes=*" \
    --id.attrs "hf.Revoker=true" \
    --id.attrs "hf.GenCRL=true" \
    --id.attrs "admin=true:ecert" \
    --caname "${CA_NAME}" \
    -u "https://${CA_HOST}:${CA_PORT}" \
    --tls.certfiles "${CA_TLS_CERT}" 2>&1)
  register_status=$?
  set -e

  echo "$register_output"
  if [[ $register_status -ne 0 ]]; then
    if echo "$register_output" | grep -qi "is already registered"; then
      echo "Note: ${id_name} was already registered with the CA — continuing to enroll."
    else
      echo "ERROR: registration of ${id_name} failed (see output above)."
      return 1
    fi
  fi

  # Enroll as the new identity itself (fresh FABRIC_CA_CLIENT_HOME).
  mkdir -p "${target_home}"
  export FABRIC_CA_CLIENT_HOME="${target_home}"
  echo "Enrolling ${id_name}..."
  fabric-ca-client enroll \
    -u "https://${id_name}:${id_secret}@${CA_HOST}:${CA_PORT}" \
    --caname "${CA_NAME}" \
    --tls.certfiles "${CA_TLS_CERT}"

  # Fabric requires an explicit config.yaml (NodeOUs) in each MSP for
  # OU-based classification (admin/peer/orderer/client) to work correctly
  # when this MSP is later used by peer/orderer binaries.
  local ca_cert_file
  ca_cert_file="$(ls "${target_home}/msp/cacerts" | head -n1)"
  cat > "${target_home}/msp/config.yaml" <<EOF
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

  echo "${id_name} enrolled. MSP: ${target_home}/msp"
}

# --- TWSOrgMSP admin ---------------------------------------------------------
register_and_enroll_admin \
  "${ORG_ADMIN_USER}" \
  "${ORG_ADMIN_PASS}" \
  "${PEER_MSP_ID}" \
  "${CRYPTO_ROOT}/peerOrganizations/${ORG_DOMAIN}/users/${ORG_ADMIN_USER}"

# --- TWSOrdererMSP admin -----------------------------------------------------
register_and_enroll_admin \
  "${ORDERER_ADMIN_USER}" \
  "${ORDERER_ADMIN_PASS}" \
  "${ORDERER_MSP_ID}" \
  "${CRYPTO_ROOT}/ordererOrganizations/${ORG_DOMAIN}/users/${ORDERER_ADMIN_USER}"

echo ""
echo "== Done =="
echo "Peer-org admin (${PEER_MSP_ID}):     ${CRYPTO_ROOT}/peerOrganizations/${ORG_DOMAIN}/users/${ORG_ADMIN_USER}/msp"
echo "Orderer-org admin (${ORDERER_MSP_ID}): ${CRYPTO_ROOT}/ordererOrganizations/${ORG_DOMAIN}/users/${ORDERER_ADMIN_USER}/msp"
echo ""
echo "Next step (Step 3): register and enroll orderer0/orderer1 node identities,"
echo "using tws-orderer-admin as registrar, then peer0/peer1 using tws-org-admin."
echo "Do not proceed automatically — confirm this step's output first."
