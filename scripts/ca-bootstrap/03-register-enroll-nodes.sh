#!/bin/bash
# =============================================================================
# scripts/ca-bootstrap/03-register-enroll-nodes.sh
# =============================================================================
# Step 3 of the RWRRN crypto-material bootstrap sequence.
#
# v5 CHANGE: switched execution context from the CA container (Option A) to
# the dedicated rwrrn-cli tools container (Option B), per the 2026-09-03
# decision to move all fabric-ca-client / channel-bootstrap operations into
# one purpose-built tools image instead of running fabric-ca-client inside
# the CA server container.
#
# Path prefix changed from /etc/hyperledger/... (CA container mounts) to
# /opt/gopath/src/github.com/hyperledger/fabric/peer/... (cli container
# mounts — same host directories, different mount point inside the
# container). No script LOGIC changed, only the base paths.
#
# Still extended for 4 orderers (orderer0-orderer3), required for SmartBFT
# (minimum 4 consenters). Since orderer0/orderer1/peer0/peer1 already have
# valid certificates from prior runs, this script will skip them (idempotent)
# and only actually enroll orderer2/orderer3.
#
# EXECUTION CONTEXT:
#   Run INSIDE the rwrrn-cli container (built from fabric-tools/Dockerfile.tools).
#
# HOW TO RUN:
#   docker compose exec cli bash
#   bash scripts/ca-bootstrap/03-register-enroll-nodes.sh
#   (cli's working_dir is already .../peer, so the relative path works)
#
# PREREQUISITE:
#   Step 1 and 2 already completed (bootstrap admin, tws-org-admin,
#   tws-orderer-admin all enrolled — visible under ./crypto-config on the
#   host, and thus also visible here via the cli container's crypto mount).
#   .env must contain ORDERER2_*/ORDERER3_* variables.
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
: "${CA_NAME:?CA_NAME not set in .env}"
: "${CA_HOST:?CA_HOST not set in .env}"
: "${CA_PORT:?CA_PORT not set in .env}"
: "${ORG_ADMIN_USER:?ORG_ADMIN_USER not set in .env}"
: "${ORG_ADMIN_PASS:?ORG_ADMIN_PASS not set in .env}"
: "${ORDERER_ADMIN_USER:?ORDERER_ADMIN_USER not set in .env}"
: "${ORDERER_ADMIN_PASS:?ORDERER_ADMIN_PASS not set in .env}"
: "${ORDERER0_NAME:?ORDERER0_NAME not set in .env}"
: "${ORDERER0_ENROLL_ID:?ORDERER0_ENROLL_ID not set in .env}"
: "${ORDERER0_ENROLL_SECRET:?ORDERER0_ENROLL_SECRET not set in .env}"
: "${ORDERER1_NAME:?ORDERER1_NAME not set in .env}"
: "${ORDERER1_ENROLL_ID:?ORDERER1_ENROLL_ID not set in .env}"
: "${ORDERER1_ENROLL_SECRET:?ORDERER1_ENROLL_SECRET not set in .env}"
: "${ORDERER2_NAME:?ORDERER2_NAME not set in .env}"
: "${ORDERER2_ENROLL_ID:?ORDERER2_ENROLL_ID not set in .env}"
: "${ORDERER2_ENROLL_SECRET:?ORDERER2_ENROLL_SECRET not set in .env}"
: "${ORDERER3_NAME:?ORDERER3_NAME not set in .env}"
: "${ORDERER3_ENROLL_ID:?ORDERER3_ENROLL_ID not set in .env}"
: "${ORDERER3_ENROLL_SECRET:?ORDERER3_ENROLL_SECRET not set in .env}"
: "${PEER0_NAME:?PEER0_NAME not set in .env}"
: "${PEER0_ENROLL_ID:?PEER0_ENROLL_ID not set in .env}"
: "${PEER0_ENROLL_SECRET:?PEER0_ENROLL_SECRET not set in .env}"
: "${PEER1_NAME:?PEER1_NAME not set in .env}"
: "${PEER1_ENROLL_ID:?PEER1_ENROLL_ID not set in .env}"
: "${PEER1_ENROLL_SECRET:?PEER1_ENROLL_SECRET not set in .env}"

CRYPTO_ROOT="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto"
CA_TLS_CERT="/opt/gopath/src/github.com/hyperledger/fabric/peer/fabric-ca/tws/tls-cert.pem"
ORDERER_ADMIN_HOME="${CRYPTO_ROOT}/ordererOrganizations/${ORG_DOMAIN}/users/${ORDERER_ADMIN_USER}"
ORG_ADMIN_HOME="${CRYPTO_ROOT}/peerOrganizations/${ORG_DOMAIN}/users/${ORG_ADMIN_USER}"

if [[ ! -f "$CA_TLS_CERT" ]]; then
  echo "ERROR: CA TLS cert not found at $CA_TLS_CERT"
  echo "Check that docker-compose.yml mounts ./fabric-ca into the cli container."
  exit 1
fi
if [[ ! -d "${ORDERER_ADMIN_HOME}/msp/signcerts" ]]; then
  echo "ERROR: ${ORDERER_ADMIN_USER} MSP not found at ${ORDERER_ADMIN_HOME}/msp"
  exit 1
fi
if [[ ! -d "${ORG_ADMIN_HOME}/msp/signcerts" ]]; then
  echo "ERROR: ${ORG_ADMIN_USER} MSP not found at ${ORG_ADMIN_HOME}/msp"
  exit 1
fi

write_node_ou_config() {
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
}

register_node() {
  local registrar_home="$1"
  local id_name="$2"
  local id_secret="$3"
  local id_type="$4"

  export FABRIC_CA_CLIENT_HOME="${registrar_home}"
  set +e
  register_output=$(fabric-ca-client register \
    --id.name "${id_name}" \
    --id.secret "${id_secret}" \
    --id.type "${id_type}" \
    --caname "${CA_NAME}" \
    -u "https://${CA_HOST}:${CA_PORT}" \
    --tls.certfiles "${CA_TLS_CERT}" 2>&1)
  register_status=$?
  set -e
  echo "$register_output"
  if [[ $register_status -ne 0 ]] && ! echo "$register_output" | grep -qi "is already registered"; then
    echo "ERROR: registration of ${id_name} failed."
    return 1
  fi
  return 0
}

enroll_node_msp() {
  local id_name="$1"
  local id_secret="$2"
  local target_msp_home="$3"

  if [[ -d "${target_msp_home}/msp/signcerts" ]] && \
     [[ -n "$(ls -A "${target_msp_home}/msp/signcerts" 2>/dev/null)" ]]; then
    echo "${id_name} MSP already enrolled at ${target_msp_home}/msp — skipping."
    return 0
  fi

  mkdir -p "${target_msp_home}"
  export FABRIC_CA_CLIENT_HOME="${target_msp_home}"
  fabric-ca-client enroll \
    -u "https://${id_name}:${id_secret}@${CA_HOST}:${CA_PORT}" \
    --caname "${CA_NAME}" \
    --csr.cn "${id_name}" \
    --tls.certfiles "${CA_TLS_CERT}"

  write_node_ou_config "${target_msp_home}/msp"
  chmod 644 "${target_msp_home}/msp/signcerts/"*.pem 2>/dev/null || true
  echo "${id_name} MSP enrolled -> ${target_msp_home}/msp"
}

enroll_node_tls() {
  local id_name="$1"
  local id_secret="$2"
  local hostname="$3"
  local target_tls_home="$4"
  local final_tls_dir="$5"

  if [[ -f "${final_tls_dir}/server.crt" ]] && \
     [[ -f "${final_tls_dir}/server.key" ]] && \
     [[ -f "${final_tls_dir}/ca.crt" ]]; then
    echo "${id_name} TLS cert already fully present at ${final_tls_dir} — skipping."
    return 0
  fi

  mkdir -p "${target_tls_home}" "${final_tls_dir}"
  export FABRIC_CA_CLIENT_HOME="${target_tls_home}"
  fabric-ca-client enroll \
    -u "https://${id_name}:${id_secret}@${CA_HOST}:${CA_PORT}" \
    --caname "${CA_NAME}" \
    --enrollment.profile tls \
    --csr.cn "${hostname}" \
    --csr.hosts "${hostname},localhost" \
    --tls.certfiles "${CA_TLS_CERT}"

  cp "${target_tls_home}/msp/signcerts/cert.pem" "${final_tls_dir}/server.crt"
  cp "${target_tls_home}/msp/keystore/"*_sk "${final_tls_dir}/server.key"

  if [[ -d "${target_tls_home}/msp/tlscacerts" ]] && \
     [[ -n "$(ls -A "${target_tls_home}/msp/tlscacerts" 2>/dev/null)" ]]; then
    cp "${target_tls_home}/msp/tlscacerts/"*.pem "${final_tls_dir}/ca.crt"
  elif [[ -d "${target_tls_home}/msp/cacerts" ]] && \
       [[ -n "$(ls -A "${target_tls_home}/msp/cacerts" 2>/dev/null)" ]]; then
    cp "${target_tls_home}/msp/cacerts/"*.pem "${final_tls_dir}/ca.crt"
  else
    echo "ERROR: could not find CA root cert in either tlscacerts/ or cacerts/ under ${target_tls_home}/msp"
    return 1
  fi

  chmod 644 "${final_tls_dir}/server.crt" "${final_tls_dir}/ca.crt"
  chmod 600 "${final_tls_dir}/server.key"

  echo "${id_name} TLS cert enrolled -> ${final_tls_dir}"
}

# =============================================================================
# Orderers (registrar: tws-orderer-admin, MSP: TWSOrdererMSP)
# =============================================================================
ORDERER_BASE="${CRYPTO_ROOT}/ordererOrganizations/${ORG_DOMAIN}/orderers"

for triple in "${ORDERER0_NAME}:${ORDERER0_ENROLL_ID}:${ORDERER0_ENROLL_SECRET}" \
              "${ORDERER1_NAME}:${ORDERER1_ENROLL_ID}:${ORDERER1_ENROLL_SECRET}" \
              "${ORDERER2_NAME}:${ORDERER2_ENROLL_ID}:${ORDERER2_ENROLL_SECRET}" \
              "${ORDERER3_NAME}:${ORDERER3_ENROLL_ID}:${ORDERER3_ENROLL_SECRET}"; do
  IFS=":" read -r node_name enroll_id enroll_secret <<< "$triple"
  echo ""
  echo "==== ${node_name} ===="
  register_node "${ORDERER_ADMIN_HOME}" "${enroll_id}" "${enroll_secret}" "orderer"
  enroll_node_msp "${enroll_id}" "${enroll_secret}" "${ORDERER_BASE}/${node_name}"
  enroll_node_tls "${enroll_id}" "${enroll_secret}" "${node_name}" \
    "${ORDERER_BASE}/${node_name}/tls-enroll-tmp" \
    "${ORDERER_BASE}/${node_name}/tls"
done

# =============================================================================
# Peers (registrar: tws-org-admin, MSP: TWSOrgMSP)
# =============================================================================
PEER_BASE="${CRYPTO_ROOT}/peerOrganizations/${ORG_DOMAIN}/peers"

for triple in "${PEER0_NAME}:${PEER0_ENROLL_ID}:${PEER0_ENROLL_SECRET}" \
              "${PEER1_NAME}:${PEER1_ENROLL_ID}:${PEER1_ENROLL_SECRET}"; do
  IFS=":" read -r node_name enroll_id enroll_secret <<< "$triple"
  echo ""
  echo "==== ${node_name} ===="
  register_node "${ORG_ADMIN_HOME}" "${enroll_id}" "${enroll_secret}" "peer"
  enroll_node_msp "${enroll_id}" "${enroll_secret}" "${PEER_BASE}/${node_name}"
  enroll_node_tls "${enroll_id}" "${enroll_secret}" "${node_name}" \
    "${PEER_BASE}/${node_name}/tls-enroll-tmp" \
    "${PEER_BASE}/${node_name}/tls"
done

echo ""
echo "== Done =="
echo "Orderer MSP/TLS material under: ${ORDERER_BASE}/<node>/{msp,tls}"
echo "Peer MSP/TLS material under:    ${PEER_BASE}/<node>/{msp,tls}"
echo ""
echo "Next: run 04-copy-admincerts-to-nodes.sh, then start orderer2/orderer3"
echo "ONE AT A TIME and check logs before starting the next one."
