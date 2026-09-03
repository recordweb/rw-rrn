# RWRRN Build Log & Configuration Reference

Status: LIVING DOCUMENT — tracks actual progress, decisions-in-execution, and step-by-step how-to guidance for the RecordWeb RootResolver Network build.
Last updated: 2026-09-03

Companion documents:
- `RootResolver-Network-Planning.md` — the planning/design document (architecture, governance, rollout plan).
- `Statuten-RecordWeb-Trust-Association.md` — draft statutes for the operating association.
- This document (`Config-and-Progress.md`) — the operational build log: what has actually been done, in what order, with reusable step-by-step instructions.

Working method (agreed): small interactive steps. The assistant proposes a concrete next step; the human executes and confirms (or reports errors) before proceeding. This document is updated only at significant milestones, not after every micro-step, so that work can resume in a fresh chat session without losing context.

Repository: [recordweb/rwrrn](https://github.com/recordweb/rwrrn) — holds the planning documents, network configuration (`docker-compose.yml`), the custom tools image (`fabric-tools/`), CA-bootstrap scripts (`scripts/ca-bootstrap/`), and the GitHub Actions deployment workflow (`.github/workflows/deploy.yml`).

---

## Stage Numbering (current, authoritative)

1. **Stage 1 — TWS only**: TWS stands up its own Fabric CA, 4 orderers, 2 peers. Single-org test network.
2. **Stage 2 — + Association bootstrap/discovery node**: the RecordWeb Trust Association stands up its own minimal organisation (1 CA + 1 non-endorsing peer, `peer.recordweb.org`) as the network's stable anchor peer.
3. **Stage 3 — + MC, + NB**: Melvin Carvalho's and Nicolas Bürkler's organisations join, each with the same node layout as TWS.
4. **Stage 4 — + Authorities**: real governmental / government-delegated organisations join.
5. **Stage 5 — − TWS, − MC, − NB**: pilot organisations withdraw once no non-governmental organisation remains; test phase ends; production channel unlocks.

`RootResolver-Network-Planning.md` Section 7 should be renumbered to match, and its "2 orderers per org" figure updated to 4 (see Decision Log below), at the next significant update of that document.

---

## Decision Log (2026-09-02 / 2026-09-03)

These decisions supersede anything stated differently in `RootResolver-Network-Planning.md` and are treated as authoritative until that document is formally updated.

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Peer-org MSP: `TWSOrgMSP`. Orderer-org MSP: `TWSOrdererMSP` (own dedicated orderer MSP per organisation — "Model B"), not a single shared `OrdererMSP` across all orgs. | Each organisation runs its own Fabric CA and issues all its own identities (Planning doc Section 4.6). A shared `OrdererMSP` would imply a shared orderer-org CA across TWS/MC/NB, which contradicts the "each org has its own CA" principle. |
| D2 | Fabric version: **3.1.x** (not 2.5 LTS), with images pinned to `hyperledger/fabric-orderer:3.1`, `hyperledger/fabric-peer:3.1`. | Adopted before any channel exists, avoiding a later migration. Note: v2.5.x remains Fabric's officially declared LTS line as of this writing; v3.1.x is actively maintained but not (yet) LTS-labelled. Accepted trade-off in exchange for SmartBFT and a currently-maintained codebase. |
| D3 | Consensus: **SmartBFT** (Byzantine Fault Tolerant), not Raft. | SmartBFT requires a minimum of 4 consenters (formula `3F+1`, F=1) to tolerate even one faulty/malicious orderer. With only 2 orderers, BFT provides zero fault tolerance. TWS's orderer count was therefore raised from 2 to 4 to make BFT viable from Stage 1 onward — see D4. Actual `OrdererType: BFT` activation happens at channel-creation time (configtx), not in docker-compose. |
| D4 | TWS orderer count: **4** (`orderer0`-`orderer3`), not 2. Peer count unchanged at 2 (`peer0`/`peer1`). | Direct consequence of D3. SmartBFT's minimum-node requirement applies to orderers only, not peers. `RootResolver-Network-Planning.md` Section 3.1's "2 orderers per org" figure is superseded for TWS; whether this also applies to MC/NB is an open item for Stage 3. |
| D5 | Orderer port scheme: flat **+100 offset per orderer** from `orderer0`, replacing the earlier ad-hoc +1000/+3 scheme. | Simpler, predictable, easy to extend to further orderers. See updated Step 1.2 table below. **Breaking change**: `orderer1` moved from 8050/8053/9446 to 7150/7153/9543 — firewall rules must be updated. |
| D6 | `hyperledger/fabric-tools` Docker image is **not used**. A custom image `rwrrn-fabric-tools` is built from `fabric-tools/Dockerfile.tools` (via `docker compose build`, automatic on `docker compose up -d`). | Hyperledger confirmed (github.com/hyperledger/fabric issue #5178) that no `fabric-tools` image has been published since Fabric v3.0; the recommended path is to build your own from the official release binaries. The custom image bundles Fabric client binaries (peer, configtxgen, configtxlator, cryptogen, osnadmin) AND `fabric-ca-client` in one image, so it also serves as the CA administration tool (see D7). |
| D7 | All CA administration (enroll/register operations) runs from the `cli` service (image `rwrrn-fabric-tools`), not from inside the `ca.tws...` server container. | Cleaner separation of concerns: the CA container stays a pure server; all client-side operations happen from one dedicated admin-tools container. This was an interim workaround (running `fabric-ca-client` inside the CA container) during initial bootstrap, now retired. |
| D8 | Crypto material is generated via a **live Fabric CA server**, not `cryptogen`. | Required for a network that must support ongoing identity issuance as new node types/operators are added (see `RootResolver-Network-Planning.md` Section 4.6). `cryptogen` only supports a one-time, static crypto-material generation and is unsuitable beyond throwaway test networks. |

---

## Repository Layout (current)

```
rwrrn/
├── .github/workflows/deploy.yml      # SSH deploy on push to main (git fetch + reset --hard + docker compose up -d)
├── docker-compose.yml                 # All 8 services: CA, orderer0-3, peer0-1, cli
├── .env.template                      # Copy to .env on the VPS, fill in real secrets — NEVER commit .env itself
├── fabric-tools/
│   └── Dockerfile.tools               # Builds rwrrn-fabric-tools (peer/configtxgen/.../fabric-ca-client bundle)
├── fabric-ca/tws/                     # Fabric CA server home dir (auto-generated on first start; contains CA root key)
├── crypto-config/                     # All enrolled MSP + TLS material (mounted into CA, orderer, peer, cli containers)
├── channel-artifacts/                 # Reserved for channel genesis blocks / configtx outputs (channel bootstrap step)
├── scripts/ca-bootstrap/
│   ├── 01-enroll-bootstrap-admin.sh   # Enrolls the CA's built-in bootstrap identity (admin:adminpw)
│   ├── 02-register-enroll-org-admins.sh  # Registers + enrolls tws-org-admin (TWSOrgMSP) and tws-orderer-admin (TWSOrdererMSP)
│   ├── 03-register-enroll-nodes.sh    # Registers + enrolls orderer0-3 and peer0-1 (MSP + TLS certs each)
│   └── 04-copy-admincerts-to-nodes.sh # Copies admin certs into each node's admincerts/ (required for NodeOUs to resolve admin rights)
└── Docs/
    ├── Config-and-Progress.md         # This file
    ├── RootResolver-Network-Planning.md
    └── Statuten-RecordWeb-Trust-Association.md
```

---

## How to Run the Bootstrap Scripts (reference table)

**Golden rule**: scripts that call `fabric-ca-client` (01–03) run inside the `cli` container. The one script that only copies files on the filesystem (04) runs directly on the VPS host. None of these scripts run automatically as part of `deploy.yml` — they are always triggered manually via SSH, on purpose, so that crypto-material generation never happens as a side effect of a routine `git push`.

| Script | Runs where | Command | Idempotent? |
|--------|-----------|---------|-------------|
| `01-enroll-bootstrap-admin.sh` | Inside `cli` container | `docker compose exec cli bash` → `bash scripts/ca-bootstrap/01-enroll-bootstrap-admin.sh` | Yes — skips if bootstrap admin MSP already exists |
| `02-register-enroll-org-admins.sh` | Inside `cli` container | same pattern, script `02-...` | Yes — skips per-identity if already enrolled |
| `03-register-enroll-nodes.sh` | Inside `cli` container | same pattern, script `03-...` | Yes — skips per-node/per-cert-type if all 3 files (server.crt/server.key/ca.crt or msp/signcerts) already exist |
| `04-copy-admincerts-to-nodes.sh` | Directly on VPS host (needs `sudo` — crypto-config files are root-owned) | `cd /opt/rwrrn && sudo bash scripts/ca-bootstrap/04-copy-admincerts-to-nodes.sh` | Yes — skips per-node if admincert already present |

**Required order**: 01 → 02 → 03 → 04, always in this sequence, because each step's registrar identity depends on the previous step's output (bootstrap admin registers the org admins; org admins register the node identities).

**After running 03 + 04 for any new/changed node**: start that one node with `docker compose up -d <service>` and check `docker compose logs <service> --tail=30` before starting the next one. Never start all nodes at once after a crypto-material change — this keeps failures isolated to one node at a time.

---

## Reference: Existing `root-resolver-testnet` Setup (reviewed 2026-09-02)

The existing `recordweb/root-resolver-testnet` repository (Fabric 2.5 LTS, confirmed running on `vps.recordweb.dev`) uses 2 organisations (`RecordWebOrg`, `SwissGovOrg`), 1 single-node Raft orderer, 1 peer per org, and a `cli` (fabric-tools) container plus application-layer services. This was the baseline the Stage 1 TWS setup adapted from — see the RWRRN docker-compose.yml history for the concrete divergences (own CA, 4 orderers instead of 1, Fabric 3.1 instead of 2.5).

---

## Stage 1 — TWS Only

### Goal

Stand up a single-organisation Fabric test network for TWS: 1 CA, 4 orderers (SmartBFT-ready), 2 peers, reachable under the `tws.rwrrn.recordweb.dev` hostnames, as a foundation to validate chaincode logic and operational scripts end-to-end before any other organisation joins.

### Step 1.1 — DNS Records for TWS Nodes (DONE — 2026-09-02)

**Status: COMPLETE AND VERIFIED.**

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

### Step 1.2 — Port Scheme (UPDATED — 2026-09-03, see Decision D5)

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

**Superseded**: the original plan had only `orderer0`/`orderer1` on 7050/8050. `orderer1` moved to 7150 as part of the 4-orderer/SmartBFT expansion — update any firewall rules referencing the old 8050-8053/9446 range.

### Step 1.3 — Firewall / Open Ports (UPDATED)

Inbound ports needed on the TWS VPS: **7050-7054, 7150-7153, 7250-7253, 7350-7353**, plus operations ports **9443, 9543, 9643, 9743, 9444, 9445** if external monitoring access is desired (otherwise internal-only is sufficient).

### Step 1.4 — Docker Compose, Fabric CA, and Crypto Material (DONE — 2026-09-02/03)

**Status: COMPLETE.** All 8 services (CA, orderer0-3, peer0-1, cli) run stably on Fabric 3.1.5 with valid MSP + TLS certificates, as of 2026-09-03.

Summary of what was built, in order:

1. **CA server configured with correct TLS SAN** (`FABRIC_CA_SERVER_CSR_HOSTS=ca.tws.rwrrn.recordweb.dev,localhost`) — the CA's auto-generated TLS certificate initially only covered `localhost` and its container ID, causing `fabric-ca-client enroll` to fail with a hostname-verification error. Fixed by wiping the auto-generated CA state (`fabric-ca/tws/*`) and restarting with the CSR host env var set, so the CA regenerates its root identity and TLS cert correctly on first boot.
2. **Bootstrap admin enrolled** (`01-enroll-bootstrap-admin.sh`) — the CA's built-in `admin:adminpw` identity (set via `fabric-ca-server start -b admin:adminpw`) enrolled as a Fabric CA client, producing a local MSP used only to register the real org admins in the next step. This bootstrap identity is intentionally never used directly by any node — see Bootstrap Admin Rotation below for why and how it will eventually be retired.
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

## Bootstrap Admin Rotation (why it matters, not yet done)

**Status: OPEN — not yet performed.**

The Fabric CA was started with a hardcoded bootstrap identity, `admin:adminpw` (see `docker-compose.yml`, `command: sh -c 'fabric-ca-server start -b admin:adminpw -d'`). This identity currently still exists and is still valid.

**Why this needs to be rotated/retired**, per `RootResolver-Network-Planning.md` Section 4.6 ("Bootstrap credentials are then rotated/retired"):

- `admin:adminpw` is a well-known, publicly documented default used across virtually every Fabric tutorial and reference deployment. Anyone who can reach `ca.tws.rwrrn.recordweb.dev:7054` and knows this convention can attempt to authenticate as this identity.
- This bootstrap identity currently has full registrar rights (it was used to register `tws-org-admin` and `tws-orderer-admin`) — if it remains active and its password is ever guessed or leaked, an attacker could register arbitrary new identities against the TWS CA, undermining the entire trust model of the organisation's MSP.
- The two named admins (`tws-org-admin`, `tws-orderer-admin`) already exist and have the same registrar capabilities the bootstrap identity was only ever meant to provide temporarily. There is no further operational need for `admin:adminpw` once these two are confirmed working (which they are, as of Stage 1 Step 1.4 completion).

**What rotation/retirement will involve** (to be executed as a discrete next step, not bundled with other changes):
1. Change the bootstrap identity's password via the CA (`fabric-ca-client identity update admin --id.secret <new-strong-secret>`), or disable it entirely if the CA server supports starting without re-registering a bootstrap identity on restart.
2. Update `docker-compose.yml`'s `command:` line accordingly (or remove the `-b` flag if rotation makes it unnecessary going forward).
3. Verify `tws-org-admin`/`tws-orderer-admin` can still register new identities independently of the bootstrap identity (they should — registrar rights were granted at their own registration, not inherited dynamically from the bootstrap admin).

---

## Stage 2 — Association Bootstrap/Discovery Node (NOT STARTED)

Planned scope (see `RootResolver-Network-Planning.md` Section 3.6): 1 Fabric CA + 1 non-endorsing peer for the RecordWeb Trust Association, hostname `peer.recordweb.org`, joined to channels purely for gossip-based discovery, never as a required endorser, no orderer.

---

## Stage 3 — MC, NB Join (NOT STARTED)

Blocked on: MC and NB infrastructure clarification (parked per `RootResolver-Network-Planning.md` Section 8). Open question carried forward: should MC/NB also run 4 orderers each (matching TWS's SmartBFT-driven expansion), or does the BFT consenter-count requirement only need to be satisfied network-wide rather than per-organisation? To be resolved before Stage 3 begins.

---

## Open Items Carried Forward

| # | Item | Status |
|---|------|--------|
| 1 | Bootstrap admin (`admin:adminpw`) rotation/retirement | Open — see dedicated section above |
| 2 | Channel bootstrap (genesis block, `OrdererType: BFT`, `ConsenterMapping` for all 4 orderers, channel creation, peer join) | Open — next major step |
| 3 | Confirm whether `root-resolver-testnet` and the new Stage 1 TWS network run simultaneously on the same VPS; resolve any operations-port collision risk | Open |
| 4 | Reconcile `recordweb.org` already used by the existing testnet's `RecordWebOrg` peer org vs. the plan to register `recordweb.org` for the association (Stage 2) | Open |
| 5 | Whether MC/NB also need 4 orderers each for Stage 3 (see Stage 3 section above) | Open |
| 6 | IPv6 (AAAA) records for TWS nodes | Deferred, not urgent |
| 7 | MC / NB infrastructure | Parked |

---

## Changelog

- 2026-09-02: Document created. Stage numbering, DNS records (Step 1.1), port scheme v1 (Step 1.2, 2 orderers), CA-vs-cryptogen decision pending.
- 2026-09-03: Stage 1 Step 1.4 completed — full crypto-material bootstrap (CA TLS fix, bootstrap admin, two named org admins under Model B MSP split, all node identities, admincerts). Fabric version decision changed from 2.5 LTS to 3.1.x. Consensus decision changed from Raft to SmartBFT, requiring TWS's orderer count to increase from 2 to 4. Port scheme revised (Step 1.2) to a flat +100-per-orderer offset, superseding the original 2-orderer scheme. Custom `rwrrn-fabric-tools` image built to replace the discontinued `hyperledger/fabric-tools` Docker Hub image and to consolidate all CA-client/channel-bootstrap tooling in one place. All 8 services (CA, orderer0-3, peer0-1, cli) confirmed running stably on Fabric 3.1.5. Documented all bugs encountered during this build for reuse by MC/NB. Flagged bootstrap-admin rotation as an open item with rationale. Channel bootstrap (BFT `configtx`, genesis block, channel creation) identified as the next major step.
