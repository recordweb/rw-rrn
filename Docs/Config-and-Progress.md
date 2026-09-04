# RWRRN Build Log & Configuration Reference

Status: LIVING DOCUMENT — tracks actual progress, decisions-in-execution, and step-by-step how-to guidance for the RecordWeb RootResolver Network build.
Last updated: 2026-09-03

Companion documents:
- `02 RootResolver-Network Operating Handbook.md` — the operating document (architecture, governance, rollout plan).
- `03 Statuten-RecordWeb-Trust-Association.md` — draft statutes for the operating association.
- This document (`Config-and-Progress.md`) — the operational build log: what has actually been done, in what order, with reusable step-by-step instructions.

Working method with AI: small interactive steps. The assistant proposes a concrete next step; the human executes and confirms (or reports errors) before proceeding. This document is updated only at significant milestones, not after every micro-step, so that work can resume in a fresh chat session without losing context.

Repository: [recordweb/rwrrn](https://github.com/recordweb/rwrrn) — holds the planning documents, network configuration (`docker-compose.yml`, `configtx.yaml`), the custom tools image (`fabric-tools/`), CA-bootstrap scripts (`scripts/ca-bootstrap/`), and the GitHub Actions deployment workflow (`.github/workflows/deploy.yml`).



## Decision Log (2026-09-02 / 2026-09-03)

These decisions supersede anything stated differently in `RootResolver-Network-Planning.md` and are treated as authoritative until that document is formally updated.

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | All CA administration (enroll/register operations) runs from the `cli` service (image `rwrrn-fabric-tools`), not from inside the `ca.tws...` server container. | Cleaner separation of concerns: the CA container stays a pure server; all client-side operations happen from one dedicated admin-tools container. This was an interim workaround (running `fabric-ca-client` inside the CA container) during initial bootstrap, now retired. |
| D2 | Crypto material is generated via a **live Fabric CA server**, not `cryptogen`. | Required for a network that must support ongoing identity issuance as new node types/operators are added (see `RootResolver-Network-Planning.md` Section 4.6). `cryptogen` only supports a one-time, static crypto-material generation and is unsuitable beyond throwaway test networks. |
| D3 | Test-channel name: **`rw-gnr-test`**, distinct from the eventual production channel name `rw-gnr`. | Keeps the Stage 1 SmartBFT test channel unambiguous and clearly disposable, while signalling its relationship to the eventual production channel. Channel name is valid per Fabric's naming rule (`[a-z][a-z0-9.-]*`, max 249 chars). |
| D4 | Channel capability ceilings differ **per capability group** in Fabric 3.1.5: `Channel` tops out at `V3_0`, but `Orderer` tops out at `V2_0` and `Application` tops out at `V2_5`. There is no `OrdererV3_0` or `ApplicationV3_0` constant in Fabric's source (`common/capabilities/*.go`). | Confirmed by direct source inspection on 2026-09-03 after both were tried and rejected at runtime (see Bugs Encountered, Step 2). BFT itself is activated via `OrdererType: BFT` + `ConsenterMapping`, not via any Orderer/Application capability flag — only the **Channel** capability needs to be `V3_0` for BFT, per the official BFT configuration doc. |

---

## Repository Layout (current)

```
rwrrn/
├── .github/workflows/deploy.yml      # SSH deploy on push to main (git fetch + reset --hard + docker compose up -d)
├── docker-compose.yml                 # All 8 services: CA, orderer0-3, peer0-1, cli
├── configtx.yaml                      # Channel configuration (BFT, ConsenterMapping, capabilities) — see Step 2 below
├── .env.template                      # Copy to .env on the VPS, fill in real secrets — NEVER commit .env itself
├── fabric-tools/
│   └── Dockerfile.tools               # Builds rwrrn-fabric-tools (peer/configtxgen/.../fabric-ca-client bundle)
├── fabric-ca/tws/                     # Fabric CA server home dir (auto-generated on first start; contains CA root key)
├── crypto-config/                     # All enrolled MSP + TLS material (mounted into CA, orderer, peer, cli containers)
├── channel-artifacts/                 # Genesis block(s), fetched config blocks — see Step 2 below
├── scripts/ca-bootstrap/
│   ├── 01-enroll-bootstrap-admin.sh   # Enrolls the CA's built-in bootstrap identity (admin:adminpw)
│   ├── 02-register-enroll-org-admins.sh  # Registers + enrolls tws-org-admin (TWSOrgMSP) and tws-orderer-admin (TWSOrdererMSP)
│   ├── 03-register-enroll-nodes.sh    # Registers + enrolls orderer0-3 and peer0-1 (MSP + TLS certs each)
│   ├── 04-copy-admincerts-to-nodes.sh # Copies admin certs into each node's admincerts/ (required for NodeOUs to resolve admin rights)
│   ├── 05-provision-org-msp-cacerts.sh   # Populates ORG-level msp/cacerts/ + msp/tlscacerts/ + config.yaml (required for configtxgen AND orderer cluster TLS trust — see Step 2 below)
│   └── 06-rotate-bootstrap-admin.sh   # Rotates/retires the CA bootstrap admin (admin:adminpw) — DONE, see Bootstrap Admin Rotation section
└── Docs/
    ├── 01 RecordWeb RootResolver-Network Evaluation
    ├── 02 RootResolver-Network Operating Handbook
    ├── 03 Statuten-RecordWeb-Trust-Association
    ├── 04 How-to-Join-RWRRN-Channel.md
    └── Config-and-Progress.md         # This file
```

---

## How to Run the Bootstrap Scripts (reference table)

**Golden rule**: scripts that call `fabric-ca-client` (01–03) run inside the `cli` container. Script 04 (plain file copy) and script 05 (org-level MSP provisioning) run inside the `cli` container as well (05 needs the crypto mount, not root on the host). Script 06 (bootstrap admin rotation) runs inside the `cli` container. None of these scripts run automatically as part of `deploy.yml` — they are always triggered manually via SSH, on purpose, so that crypto-material generation never happens as a side effect of a routine `git push`.

| Script | Runs where | Command | Idempotent? |
|--------|-----------|---------|-------------|
| `01-enroll-bootstrap-admin.sh` | Inside `cli` container | `docker compose exec cli bash` → `bash scripts/ca-bootstrap/01-enroll-bootstrap-admin.sh` | Yes — skips if bootstrap admin MSP already exists |
| `02-register-enroll-org-admins.sh` | Inside `cli` container | same pattern, script `02-...` | Yes — skips per-identity if already enrolled |
| `03-register-enroll-nodes.sh` | Inside `cli` container | same pattern, script `03-...` | Yes — skips per-node/per-cert-type if all 3 files (server.crt/server.key/ca.crt or msp/signcerts) already exist |
| `04-copy-admincerts-to-nodes.sh` | Directly on VPS host (needs `sudo` — crypto-config files are root-owned) | `cd /opt/rw-rrn && sudo bash scripts/ca-bootstrap/04-copy-admincerts-to-nodes.sh` | Yes — skips per-node if admincert already present |
| `05-provision-org-msp-cacerts.sh` | Inside `cli` container | same pattern, script `05-...` | Yes — skips cacerts/tlscacerts/config.yaml individually if already present |
| `06-rotate-bootstrap-admin.sh` | Inside `cli` container | same pattern, script `06-...` | Yes — see Bootstrap Admin Rotation section |

**Required order**: 01 → 02 → 03 → 04 → 05 → 06, in this sequence for a first-time bootstrap. 05 must run, and its resulting org-level `msp/cacerts/` + `msp/tlscacerts/` must be in place, **before** `configtxgen` generates any genesis/channel block that will actually be distributed to orderers (see Step 2, Bugs Encountered — a block generated before 05's `tlscacerts/` fix had to be discarded and regenerated).

**After running 03 + 04 for any new/changed node**: start that one node with `docker compose up -d <service>` and check `docker compose logs <service> --tail=30` before starting the next one. Never start all nodes at once after a crypto-material change — this keeps failures isolated to one node at a time.



## Stage 1 — TWS Only

### Goal

Stand up a single-organisation Fabric test network for TWS: 1 CA, 4 orderers (SmartBFT-ready), 2 peers, reachable under the `tws.rwrrn.recordweb.dev` hostnames, as a foundation to validate chaincode logic and operational scripts end-to-end before any other organisation joins.

### Step 1.1 — DNS Records for TWS Nodes (DONE — 2026-09-02)

DNS `A` records in Cloudflare for the `recordweb.dev` zone, all **DNS only** (grey cloud, not proxied) — required because Fabric nodes communicate via gRPC/mTLS directly, which does not work through Cloudflare's HTTP(S) reverse proxy.

| Type | Hostname | Value | Proxy status |
|------|----------|-------|---------------|
| A | `ca.tws.rwrrn.recordweb.dev` | `83.228.219.30` | DNS only |
| A | `orderer0.tws.rwrrn.recordweb.dev` | `83.228.219.30` | DNS only |
| A | `orderer1.tws.rwrrn.recordweb.dev` | `83.228.219.30` | DNS only |
| A | `orderer2.tws.rwrrn.recordweb.dev` | `83.228.219.30` | DNS only |
| A | `orderer3.tws.rwrrn.recordweb.dev` | `83.228.219.30` | DNS only |
| A | `peer0.tws.rwrrn.recordweb.dev` | `83.228.219.30` | DNS only |
| A | `peer1.tws.rwrrn.recordweb.dev` | `83.228.219.30` | DNS only |

**How-to (reusable for Stage 2/3):** Cloudflare dashboard → zone → DNS > Records → Add record → Type `A`, Proxy status = DNS only, TTL Auto. Verify with `dig <hostname> +short`.

### Step 1.2 — Port Scheme (DONE — 2026-09-03)

Flat +100 offset per orderer from `orderer0`. Admin port = general port + 3. Operations port sequential from 9443.

| Node | Hostname | General/Peer port | Admin/Chaincode port | Operations port |
|------|----------|--------------------|------------------------|-------------------|
| CA | `ca.tws.rwrrn.recordweb.dev` | 7054 | — | — |
| Orderer 0 | `orderer0.tws.rwrrn.recordweb.dev` | 7050 | 7053 | 9443 |
| Orderer 1 | `orderer1.tws.rwrrn.recordweb.dev` | 7150 | 7153 | 9543 |
| Orderer 2 | `orderer2.tws.rwrrn.recordweb.dev` | 7250 | 7253 | 9643 |
| Orderer 3 | `orderer3.tws.rwrrn.recordweb.dev` | 7350 | 7353 | 9743 |
| Peer 0 | `peer0.tws.rwrrn.recordweb.dev` | 7051 | 7052 | 9444 |
| Peer 1 | `peer1.tws.rwrrn.recordweb.dev` | 8051 | 8052 | 9445 |

### Step 1.3 — Firewall / Open Ports (DONE — 2026-09-02/03)

Inbound ports needed on the TWS VPS: **7050-7054, 7150-7153, 7250-7253, 7350-7353**, plus operations ports **9443, 9543, 9643, 9743, 9444, 9445** if external monitoring access is desired (otherwise internal-only is sufficient).

### Step 1.4 — Docker Compose, Fabric CA, and Crypto Material (DONE — 2026-09-02/03)

**Status: COMPLETE.** All 8 services (CA, orderer0-3, peer0-1, cli) run stably on Fabric 3.1.5 with valid MSP + TLS certificates, as of 2026-09-03.

Summary of what was built, in order:

1. **CA server configured with correct TLS SAN** (`FABRIC_CA_SERVER_CSR_HOSTS=ca.tws.rwrrn.recordweb.dev,localhost`) — the CA's auto-generated TLS certificate initially only covered `localhost` and its container ID, causing `fabric-ca-client enroll` to fail with a hostname-verification error. Fixed by wiping the auto-generated CA state (`fabric-ca/tws/*`) and restarting with the CSR host env var set, so the CA regenerates its root identity and TLS cert correctly on first boot.
2. **Bootstrap admin enrolled** (`01-enroll-bootstrap-admin.sh`) — the CA's built-in `admin:adminpw` identity (set via `fabric-ca-server start -b admin:adminpw`) enrolled as a Fabric CA client, producing a local MSP used only to register the real org admins in the next step. This bootstrap identity is intentionally never used directly by any node — see Bootstrap Admin Rotation below for why and how it was retired.
3. **Two named org admins registered + enrolled** (`02-register-enroll-org-admins.sh`): `tws-org-admin` (MSP `TWSOrgMSP`, registrar for peer identities) and `tws-orderer-admin` (MSP `TWSOrdererMSP`, registrar for orderer identities) — see Decision D1 for why two separate admins/MSPs instead of one shared `OrdererMSP`.
4. **All 6 node identities registered + enrolled** (`03-register-enroll-nodes.sh`): `orderer0`-`orderer3` (registrar: `tws-orderer-admin`) and `peer0`/`peer1` (registrar: `tws-org-admin`). Each node gets both an MSP (signing) certificate and a separate TLS certificate (`--enrollment.profile tls`), laid out exactly as `docker-compose.yml`'s volume mounts expect.
5. **Admin certificates copied into each node's `admincerts/`** (`04-copy-admincerts-to-nodes.sh`) — required because Fabric's NodeOUs mechanism still needs at least one admin certificate physically present in each node's local MSP folder to resolve "who is an admin of this MSP" at node startup, even with `NodeOUs.Enable: true` configured.
6. **`rwrrn-fabric-tools` custom image built** (`fabric-tools/Dockerfile.tools`, see Decision D6) — replaces the discontinued `hyperledger/fabric-tools` Docker Hub image. Built automatically by `docker compose up -d` via the `build:` directive on the `cli` service.
7. **Fabric images upgraded to 3.1.5** for orderer/peer/cli; CA stays on `fabric-ca:1.5` (versioned independently, compatible with Fabric 3.x networks).
8. **Orderer count raised from 2 to 4** (`orderer2`/`orderer3` added) to meet SmartBFT's minimum-consenter requirement — see Decision D3/D4.

**Bugs encountered and fixed during this build** (kept here for future organisations following this same path):

- `fabric-ca-client` binary missing when first attempted inside the plain `fabric-tools:2.5`/`3.1` container — resolved by building the custom `rwrrn-fabric-tools` image (Decision D6/D7).
- `--id.attrs` with a comma-separated value (`hf.Registrar.Roles=client,orderer,peer,admin`) gets mis-parsed by `fabric-ca-client` unless the whole value is wrapped in literal double quotes as part of the argument string (`"\"hf.Registrar.Roles=...\""`).
- TLS-profile enrollments (`--enrollment.profile tls`) store the CA root certificate under `msp/tlscacerts/`, not `msp/cacerts/` (which only exists for regular/ecert enrollments) — a script that only checked `cacerts/` silently failed to produce `ca.crt`.
- Docker Hub does not have a `hyperledger/fabric-tools` tag beyond `2.5` — Fabric v3.0+ no longer publishes this image at all (confirmed via `hyperledger/fabric` issue #5178).
- A naive `tar -xzf fabric-release.tar.gz -C /` clobbers the system `/bin/sh` (Fabric release tarballs extract their own `bin/`/`config/` at archive root) — fixed by extracting into an isolated `/opt/fabric` directory and symlinking only the needed binaries into `/usr/local/bin`.
- After the Fabric 2.5 → 3.1 image upgrade, `orderer0`/`orderer1` failed with `'' has invalid keys: Kafka` even though the correct 3.1.5 image was in use — caused by stale data in the old `orderer0_data`/`orderer1_data` Docker named volumes (created under Fabric 2.5) containing a now-incompatible config structure. Fixed by stopping the affected orderer, removing its container AND its named volume (`docker volume rm rwrrn_orderer<N>_data`), then recreating — this loses no MSP/TLS material (that lives in `crypto-config/` on the host, not in the named volume) and no ledger data (no channel existed yet).

---

## Bootstrap Admin Rotation (DONE — 2026-09-03)

**Status: COMPLETE.** Executed via `06-rotate-bootstrap-admin.sh` on 2026-09-03, after Stage 1 Step 2 (channel bootstrap) completed successfully.

The Fabric CA was originally started with a hardcoded bootstrap identity, `admin:adminpw` (see `docker-compose.yml`, `command: sh -c 'fabric-ca-server start -b admin:adminpw -d'`). This identity was rotated/retired because:

- `admin:adminpw` is a well-known, publicly documented default used across virtually every Fabric tutorial and reference deployment. Anyone who could reach `ca.tws.rwrrn.recordweb.dev:7054` and knew this convention could attempt to authenticate as this identity.
- This bootstrap identity had full registrar rights (it was used to register `tws-org-admin` and `tws-orderer-admin`) — leaving it active indefinitely would have left the CA's registrar capability tied to a well-known default credential.
- The two named admins (`tws-org-admin`, `tws-orderer-admin`) already had the same registrar capabilities the bootstrap identity was only ever meant to provide temporarily, and were confirmed working well before rotation.

The bootstrap admin's secret has been rotated to a new, strong, non-default value (recorded outside this repository, per `.env` conventions — never committed). `tws-org-admin`/`tws-orderer-admin` continue to register new identities independently, unaffected by the rotation.



## Stage 1 — Step 2: Channel Bootstrap (SmartBFT) — DONE (2026-09-03)

**Status: COMPLETE AND VERIFIED.** The application channel `rw-gnr-test` (see Decision D3 for naming) is live across all 6 TWS nodes: orderer0-orderer3 (all `status: active`, SmartBFT cluster communicating with all 4 subchannels `READY`, view-leader elected) and peer0/peer1 (both joined, both report identical `height:1` / `currentBlockHash`, matching AnchorPeer configuration verified in the live channel config).

### What was built, in order

1. **`configtx.yaml` created** at the repo root, defining `TWSOrdererOrg` (MSP `TWSOrdererMSP`, `OrdererEndpoints` for all 4 orderers) and `TWSOrg` (MSP `TWSOrgMSP`, `AnchorPeers: peer0`), `OrdererType: BFT`, a full `ConsenterMapping` (4 entries: Identity = node MSP signcert, ClientTLSCert = ServerTLSCert = node TLS server.crt), and a single profile `RootResolverTestApplicationGenesis` (no system channel — Fabric 3.x application channels bootstrap directly).
2. **Genesis/application-channel block generated** via `configtxgen -profile RootResolverTestApplicationGenesis -channelID rw-gnr-test -outputBlock ...` from inside the `cli` container.
3. **Channel created on all 4 orderers** via the Channel Participation API (`osnadmin channel join`), each confirmed `Status: 201` / `"status": "active"`.
4. **Verified SmartBFT cluster communication** between all 4 orderers via `docker compose logs` (subchannels to all peers `READY`, `SmartBFT-v3 is now servicing chain`, view-leader elected) — this required a fix and a full channel-recreate cycle, see Bugs Encountered below.
5. **peer0 and peer1 joined the channel** via `peer channel join -b <block>`, both confirmed via `peer channel list` and `peer channel getinfo` (`height:1`, identical block hash on both peers).
6. **AnchorPeer verified** in the live channel config (fetched via `peer channel fetch config` + `configtxlator proto_decode`): `TWSOrgMSP.AnchorPeers` correctly shows `peer0.tws.rwrrn.recordweb.dev:7051`.
7. **Endorsement policy**: left at the channel-wide default set in `configtx.yaml` (`Application.Policies.Endorsement: MAJORITY Endorsement`, resolving to `OR('TWSOrgMSP.peer')`). Chaincode-specific endorsement policies (via lifecycle `--signature-policy`) are deferred to a future chaincode-focused session — no chaincode is installed yet.

### Used commands

#### CLI Container restart (if configtx.yaml has changed)
``` bash
docker compose restart cli
```

#### Channel remove

``` bash
docker compose exec cli bash -c '
for cfg in \
  "orderer0.tws.rwrrn.recordweb.dev:7053:orderer0.tws.rwrrn.recordweb.dev" \
  "orderer1.tws.rwrrn.recordweb.dev:7153:orderer1.tws.rwrrn.recordweb.dev" \
  "orderer2.tws.rwrrn.recordweb.dev:7253:orderer2.tws.rwrrn.recordweb.dev" \
  "orderer3.tws.rwrrn.recordweb.dev:7353:orderer3.tws.rwrrn.recordweb.dev" \
; do
  IFS=":" read -r host port node <<< "$cfg"
  echo "=== Removing channel from ${node} ==="
  osnadmin channel remove \
    --channelID root-resolver-test \
    -o "${host}:${port}" \
    --ca-file "crypto/ordererOrganizations/tws.rwrrn.recordweb.dev/orderers/${node}/tls/ca.crt" \
    --client-cert "crypto/ordererOrganizations/tws.rwrrn.recordweb.dev/orderers/${node}/tls/server.crt" \
    --client-key "crypto/ordererOrganizations/tws.rwrrn.recordweb.dev/orderers/${node}/tls/server.key"
done
'
```

#### Genesis-Block and orderer channel join

``` bash
docker compose exec cli bash -c '
rm -f channel-artifacts/root-resolver-test.block
FABRIC_CFG_PATH=/opt/gopath/src/github.com/hyperledger/fabric/peer \
configtxgen -profile RwGnrApplicationGenesis \
  -channelID rw-gnr \
  -outputBlock channel-artifacts/rw-gnr.block \
  -configPath /opt/gopath/src/github.com/hyperledger/fabric/peer
echo "CONFIGTXGEN EXIT CODE: $?"

for cfg in \
  "orderer0.tws.rwrrn.recordweb.dev:7053:orderer0.tws.rwrrn.recordweb.dev" \
  "orderer1.tws.rwrrn.recordweb.dev:7153:orderer1.tws.rwrrn.recordweb.dev" \
  "orderer2.tws.rwrrn.recordweb.dev:7253:orderer2.tws.rwrrn.recordweb.dev" \
  "orderer3.tws.rwrrn.recordweb.dev:7353:orderer3.tws.rwrrn.recordweb.dev" \
; do
  IFS=":" read -r host port node <<< "$cfg"
  echo "=== Joining ${node} ==="
  osnadmin channel join \
    --channelID rw-gnr \
    --config-block channel-artifacts/rw-gnr.block \
    -o "${host}:${port}" \
    --ca-file "crypto/ordererOrganizations/tws.rwrrn.recordweb.dev/orderers/${node}/tls/ca.crt" \
    --client-cert "crypto/ordererOrganizations/tws.rwrrn.recordweb.dev/orderers/${node}/tls/server.crt" \
    --client-key "crypto/ordererOrganizations/tws.rwrrn.recordweb.dev/orderers/${node}/tls/server.key"
  echo ""
done
'
```

#### Peer 0 join

``` bash
docker compose exec cli bash -c '
peer channel join -b channel-artifacts/rw-gnr.block
echo "EXIT CODE: $?"
'
```

#### Peer 1 joinen

``` bash
docker compose exec cli bash -c '
CORE_PEER_ADDRESS=peer1.tws.rwrrn.recordweb.dev:8051 \
CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/tws.rwrrn.recordweb.dev/peers/peer1.tws.rwrrn.recordweb.dev/tls/server.crt \
CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/tws.rwrrn.recordweb.dev/peers/peer1.tws.rwrrn.recordweb.dev/tls/server.key \
CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/tws.rwrrn.recordweb.dev/peers/peer1.tws.rwrrn.recordweb.dev/tls/ca.crt \
peer channel join -b channel-artifacts/rw-gnr.block
echo "EXIT CODE: $?"
'
```

#### Verification

``` bash
docker compose exec cli bash -c '
peer channel list
echo "---"
CORE_PEER_ADDRESS=peer1.tws.rwrrn.recordweb.dev:8051 \
CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/tws.rwrrn.recordweb.dev/peers/peer1.tws.rwrrn.recordweb.dev/tls/server.crt \
CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/tws.rwrrn.recordweb.dev/peers/peer1.tws.rwrrn.recordweb.dev/tls/server.key \
CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/tws.rwrrn.recordweb.dev/peers/peer1.tws.rwrrn.recordweb.dev/tls/ca.crt \
peer channel list
'

docker compose exec cli bash -c '
peer channel fetch config channel-artifacts/rw-gnr_config_block.pb \
  -c rw-gnr \
  -o orderer0.tws.rwrrn.recordweb.dev:7050 \
  --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/tws.rwrrn.recordweb.dev/orderers/orderer0.tws.rwrrn.recordweb.dev/tls/ca.crt
echo "FETCH EXIT CODE: $?"
echo ""
configtxlator proto_decode --input channel-artifacts/rw-gnr_config_block.pb --type common.Block --output channel-artifacts/rw-gnr_config_block.json
echo "DECODE EXIT CODE: $?"
echo ""
cat channel-artifacts/rw-gnr_config_block.json | grep -A15 "AnchorPeers"
'
```

### Bugs encountered and fixed during Step 2 (kept here for future organisations following this same path — MC/NB will hit the same issues)

- **Multi-document YAML silently hides content**: an early draft of `configtx.yaml` used `---` document separators between top-level sections (`Organizations`, `Capabilities`, `Application`, `Orderer`, `Channel`, `Profiles`). `configtxgen`'s Viper-based loader only reads the **first** YAML document in a multi-document stream, so everything after the first `---` (including the `Profiles` section itself) was invisible to the tool — surfacing as `Could not find profile: ...` even though the profile was clearly present in the file. **Fix**: the entire file must be a single YAML document; never use `---` separators in `configtx.yaml`.
- **Global `Orderer.Addresses` incompatible with Channel capability V3_0**: `configtxgen` rejected a config with both a global `Orderer.Addresses` list and per-org `OrdererEndpoints` set, with `global orderer endpoints exist, but can not be used with V3_0 capability`. **Fix**: remove the global `Addresses:` list entirely; rely exclusively on each orderer org's `OrdererEndpoints`.
- **`Consortiums: {}` no longer valid in Fabric v3.x profiles**: left over from pre-v3 examples; Fabric 3.x has no system channel, so `configtxgen` emits `Warning: 'Consortiums' should be nil since system channel is no longer supported in Fabric v3.x`. **Fix**: remove `Consortiums:` from the profile entirely (harmless as a warning, but removed for cleanliness).
- **Org-level MSP missing `msp/cacerts/`**: `configtxgen` failed with `could not load a valid ca certificate from directory .../msp/cacerts: stat ...: no such file or directory`. Steps 01-04 only ever populated **node**-level and **admin**-level MSPs; nobody had populated the **organisation**-level `MSPDir` referenced directly by `configtx.yaml`'s `Organizations[].MSPDir`, because a live Fabric CA (unlike `cryptogen`) never creates this directory automatically. **Fix**: new script `05-provision-org-msp-cacerts.sh` (see Repository Layout), which copies the CA root cert (already present in any enrolled node's `msp/cacerts/`) into both `ordererOrganizations/.../msp/cacerts/` and `peerOrganizations/.../msp/cacerts/`, plus writes the matching NodeOUs `config.yaml` at the org level.
- **Org-level MSP also missing `msp/tlscacerts/` — orderer cluster TLS fails even though `configtxgen` succeeds**: after fixing `cacerts/` above, `configtxgen` ran fine and all 4 orderers individually joined the channel (`osnadmin` returned `201`/`active` for each). However, `docker compose logs` on any orderer showed a continuous stream of `server root CA cert is nil` (from `orderer/common/cluster/connectionsmgr.go`) and `tls: bad certificate` — the SmartBFT consenters could not open gRPC connections to each other. Root cause, confirmed by inspecting Fabric's source (`orderer/common/cluster/util.go`): the cluster layer derives each org's `ServerRootCAs` via `msp.GetTLSRootCerts()`, which reads **only** `msp/tlscacerts/`, never `msp/cacerts/` — a completely different directory from the one `configtxgen` needs. **Fix**: extended `05-provision-org-msp-cacerts.sh` to also populate `msp/tlscacerts/` at the org level (same source `.pem`, since this CA has no separate TLS sub-CA). **Important consequence**: because the *already-generated and already-distributed* genesis block had the org MSP baked in *without* `tlscacerts/`, fixing the files on disk was not enough — the channel had to be fully removed from all 4 orderers (`osnadmin channel remove`), the block regenerated, and all 4 orderers rejoined, before the cluster TLS fix took effect. **Takeaway for MC/NB**: always run `05-provision-org-msp-cacerts.sh` to completion (with both `cacerts/` and `tlscacerts/` populated) *before* generating the block that will actually be distributed — regenerating after the fact requires a full channel remove/rejoin cycle.
- **`Orderer.Capabilities: V3_0` does not exist**: `osnadmin channel join` failed on the very first attempt with `Orderer capability V3_0 is required but not supported`, despite all orderer binaries confirmed running `v3.1.5` (verified via `orderer version` and `configtxgen --version` — no version mismatch). Root cause, confirmed by inspecting Fabric's source (`common/capabilities/orderer.go`): the highest defined Orderer-capability constant is `OrdererV2_0 = "V2_0"` — there is no `OrdererV3_0`. **Fix**: set `Orderer.Capabilities: V2_0`, not `V3_0`. Only the **Channel**-level capability needs to be `V3_0` to enable BFT.
- **`Application.Capabilities: V3_0` does not exist either — same mistake, different capability group**: after fixing the Orderer capability and successfully rejoining all 4 orderers, `peer channel join` failed with `Application capability V3_0 is required but not supported`. Root cause, confirmed the same way (`common/capabilities/application.go`): the highest defined Application-capability constant is `ApplicationV2_5` — there is no `ApplicationV3_0`. **Fix**: set `Application.Capabilities: V2_5`. This required a second full channel remove/regenerate/rejoin cycle (see Decision D10 for the generalised rule this produced).
- **Relative crypto-material paths fail for any peer other than the `cli` container's configured default (`peer0`)**: commands like `peer channel join` or `peer channel fetch config` work with **relative** paths (e.g. `crypto/peerOrganizations/.../ca.crt`) only when using the `cli` service's built-in default `CORE_PEER_*` environment (which points at `peer0`, using **absolute** paths baked into `docker-compose.yml`). As soon as any command overrides `CORE_PEER_ADDRESS`/`CORE_PEER_TLS_*` to target `peer1` (or fetches from an orderer) using a **relative** path for the TLS file, it fails with `open /etc/hyperledger/fabric/crypto/...: no such file or directory` — a different, wrong base directory is used for relative-path resolution in that code path. **Fix**: always use the **full absolute path** (`/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/...`) for any `CORE_PEER_TLS_*`/`--cafile`/`--client-cert`/`--client-key` argument passed as an override inside the `cli` container — never rely on relative paths outside of the container's own baked-in defaults.

