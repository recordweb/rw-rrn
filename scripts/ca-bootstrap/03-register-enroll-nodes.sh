#!/bin/bash
# =============================================================================
# scripts/ca-bootstrap/03-register-enroll-nodes.sh
# =============================================================================
# Step 3 of the RWRRN crypto-material bootstrap sequence.
#
# FIX v2 vs. previous version: TLS-profile enrollments store the CA root
# certificate under msp/tlscacerts/ (NOT msp/cacerts/, which only exists for
# regular/non-TLS enrollments). enroll_node_tls() now copies from the
# correct directory, with a fallback to cacerts/ for older fabric-ca-client
# versions that may still use that path.
#
# EXECUTION CONTEXT (temporary — Option A, see note in Step 1 script):
#   Run INSIDE the CA container (ca.tws.rwrrn.recordweb.dev).
#
# WHAT THIS DOES:
#   For each of orderer0, orderer1, peer0, peer1:
#     1. Registers a node identity with the CA (registrar = the matching org
#        admin from Step 2: tws-orderer-admin for orderers, tws-org-admin
#        for peers).
#     2. Enrolls the MSP certificate (signing identity) into the exact
#        directory structure docker-compose.yml expects.
#     3. Enrolls a SEPARATE TLS certificate (--enrollment.profile tls) with
#        the node's own hostname as CSR host/CN, laid out as
#        server.crt/server.key/ca.crt under .../tls.
#
# WHAT THIS DOES NOT DO:
#   - Does NOT start/restart any orderer or peer container.
#   - Does NOT create the orderer system channel / genesis block.
#   - Idempotent per-node/per-cert-type: skips any enrollment whose target
#     directory already contains a certificate.
#
# HOW TO RUN:
#   docker compose exec ca.tws.rwrrn.recordweb.dev bash
#   bash /etc/hyperledger/scripts/ca-bootstrap/03-register-enroll-nodes.sh
#
# PREREQUISITE:
#   Step 2 script has run successfully.
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
: "${PEER0_NAME:?PEER0_NAME not set in .env}"
: "${PEER0_ENROLL_ID:?PEER0_ENROLL_ID not set in .env}"
: "${PEER0_ENROLL_SECRET:?PEER0_ENROLL_SECRET not set in .env}"
: "${PEER1_NAME:?PEER1_NAME not set in .env}"
: "${PEER1_ENROLL_ID:?PEER1_ENROLL_ID not set in .env}"
: "${PEER1_ENROLL_SECRET:?PEER1_ENROLL_SECRET not set in .env}"

CRYPTO_ROOT="/etc/hyperledger/crypto-config"
CA_TLS_CERT="/etc/hyperledger/fabric-ca-server/tls-cert.pem"
ORDERER_ADMIN_HOME="${CRYPTO_ROOT}/ordererOrganizations/${ORG_DOMAIN}/users/${ORDERER_ADMIN_USER}"
ORG_ADMIN_HOME="${CRYPTO_ROOT}/peerOrganizations/${ORG_DOMAIN}/users/${ORG_ADMIN_USER}"

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
  echo "${id_name} MSP enrolled -> ${target_msp_home}/msp"
}

enroll_node_tls() {
  local id_name="$1"
  local id_secret="$2"
  local hostname="$3"
  local target_tls_home="$4"
  local final_tls_dir="$5"

  if [[ -f "${final_tls_dir}/server.crt" ]] && [[ -f "${final_tls_dir}/server.key" ]]; then
    echo "${id_name} TLS cert already present at ${final_tls_dir} — skipping."
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

  # TLS-profile enrollments store the CA root cert under tlscacerts/, not
  # cacerts/ (that directory only exists for regular/ecert enrollments).
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

  echo "${id_name} TLS cert enrolled -> ${final_tls_dir}"
}

# =============================================================================
# Orderers (registrar: tws-orderer-admin, MSP: TWSOrdererMSP)
# =============================================================================
ORDERER_BASE="${CRYPTO_ROOT}/ordererOrganizations/${ORG_DOMAIN}/orderers"

for triple in "${ORDERER0_NAME}:${ORDERER0_ENROLL_ID}:${ORDERER0_ENROLL_SECRET}" \
              "${ORDERER1_NAME}:${ORDERER1_ENROLL_ID}:${ORDERER1_ENROLL_SECRET}"; do
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
echo "Next: verify SANs on the TLS certs from the VPS host (openssl not"
echo "available inside this container), then try starting the containers."
echo "Do not proceed automatically — confirm this step's output first."