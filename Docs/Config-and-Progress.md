# RWRRN Build Log & Configuration Reference

Status: LIVING DOCUMENT — tracks actual progress, decisions-in-execution, and step-by-step how-to guidance for the RecordWeb RootResolver Network build.
Last updated: 2026-09-02

Companion documents:
- `RootResolver-Network.md` — the planning/design document (architecture, governance, rollout plan).
- `Statuten-RecordWeb-Trust-Association.md` — draft statutes for the operating association.
- This document (`Config-and-Progress.md`) — the operational build log: what has actually been done, in what order, with reusable step-by-step instructions.

Working method (agreed): small interactive steps. The assistant proposes a concrete next step; the human executes and confirms (or reports errors) before proceeding. This document is updated only at significant milestones, not after every micro-step, so that work can resume in a fresh chat session without losing context.

Repository: [recordweb/rwrrn](https://github.com/recordweb/rwrrn) — holds the planning documents; will also hold network configuration, scripts, and (likely) a GitHub Actions deployment workflow, following the pattern already used by `recordweb/root-resolver-testnet`, which deploys to `vps.recordweb.dev`.

---

## Stage Numbering (current, authoritative)

Renumbered per 2026-09-02 decision — supersedes any earlier stage numbering in `RootResolver-Network.md`:

1. **Stage 1 — TWS only**: TWS stands up its own Fabric CA, 2 orderers, 2 peers. Single-org test network.
2. **Stage 2 — + Association bootstrap/discovery node**: the RecordWeb Trust Association stands up its own minimal organisation (1 CA + 1 non-endorsing peer, `peer.recordweb.org`) as the network's stable anchor peer.
3. **Stage 3 — + MC, + NB**: Melvin Carvalho's and Nicolas Bürkler's organisations join, each with the same node layout as TWS (1 CA, 2 orderers, 2 peers).
4. **Stage 4 — + Authorities**: real governmental / government-delegated organisations join.
5. **Stage 5 — − TWS, − MC, − NB**: pilot organisations withdraw once no non-governmental organisation remains; test phase ends; production channel unlocks.

`RootResolver-Network.md` Section 7 should be renumbered to match at the next significant update of that document.

---

## Reference: Existing `root-resolver-testnet` Setup (reviewed 2026-09-02)

The existing `recordweb/root-resolver-testnet` repository (Fabric 2.5 LTS, confirmed running on `vps.recordweb.dev`) uses:

- **2 organisations**: `RecordWebOrg` (MSP: `RecordWebOrgMSP`, domain `recordweb.org`) and `SwissGovOrg` (MSP: `SwissGovOrgMSP`, domain `swissgov.recordweb.dev`), each with exactly **1 peer** (`peer0.<org-domain>`).
- **1 single-node Raft orderer**: `orderer.orderer.recordweb.dev`, MSP `OrdererMSP`, ports 7050 (general) / 7053 (admin) / 9443 (operations/metrics).
- Peer ports: `peer0.recordweb.org` on 7051 (peer)/7052 (chaincode)/9444 (operations); `peer0.swissgov.recordweb.dev` on 9051/9052/9445.
- State database: not yet confirmed from the compose file alone (no CouchDB service present in the reviewed file — consistent with the LevelDB decision already adopted for RWRRN).
- A `cli` container (fabric-tools) plus two application-layer services (`admin-app`, `recordfinder`) connecting via the Fabric Gateway SDK to `peer0.recordweb.org`.
- All services attach to a shared `fabric_net` Docker bridge network; the app-layer services additionally join an external `poc_network` for integration with other POC infrastructure on the same VPS.

This is the baseline the Stage 1 TWS setup adapts: same general docker-compose structure and environment-variable patterns, extended from 1 orderer/1 peer to **2 orderers + 2 peers**, single organisation (TWS), with hostnames matching the `rwrrn.recordweb.dev` DNS scheme instead of the testnet's `recordweb.org`/`swissgov.recordweb.dev` domains.

---

## Stage 1 — TWS Only

### Goal

Stand up a single-organisation Fabric test network for TWS: 1 CA, 2 orderers, 2 peers, reachable under the `tws.rwrrn.recordweb.dev` hostnames, as a foundation to validate chaincode logic and operational scripts end-to-end before any other organisation joins.

### Step 1.1 — DNS Records for TWS Nodes (DONE — 2026-09-02, revised same day)

**Status: COMPLETE AND VERIFIED.**

DNS `A` records were created in Cloudflare for the `recordweb.dev` zone, all set to **DNS only** (grey cloud, not proxied) — required because Fabric nodes communicate via gRPC/mTLS directly between each other, which does not work through Cloudflare's HTTP(S) reverse proxy. IPv6 (`AAAA`) records were deliberately deferred (IPv4-only for now).

**Naming/numbering decision (finalised 2026-09-02)**: both orderers and both peers use **0-based indexing** for consistency — `orderer0`/`orderer1` and `peer0`/`peer1` — rather than mixing a 1-based orderer numbering with 0-based peer numbering. This aligns with Fabric's own common reference-network convention (`orderer0.example.com`, `orderer1.example.com`, etc.) and was applied retroactively: the DNS records were first created as `orderer1`/`orderer2` and have since been **corrected to `orderer0`/`orderer1`** in Cloudflare.

**Current, correct DNS state:**

| Type | Hostname | Value | Proxy status |
|------|----------|-------|---------------|
| A | `ca.tws.rwrrn.recordweb.dev` | `83.228.219.30` | DNS only |
| A | `orderer0.tws.rwrrn.recordweb.dev` | `83.228.219.30` | DNS only |
| A | `orderer1.tws.rwrrn.recordweb.dev` | `83.228.219.30` | DNS only |
| A | `peer0.tws.rwrrn.recordweb.dev` | `83.228.219.30` | DNS only |
| A | `peer1.tws.rwrrn.recordweb.dev` | `83.228.219.30` | DNS only |

The pre-existing `ssh.recordweb.dev` and `vps.recordweb.dev` Cloudflare Tunnel records (proxied, tunnel `poc-vps`) remain untouched and unrelated.

**How-to (reusable for Stage 2/3):**

1. Cloudflare dashboard → relevant zone → **DNS > Records** → **Add record**.
2. Type `A`, Name = desired hostname, IPv4 = server's public IP, Proxy status = **DNS only** (grey cloud), TTL Auto.
3. Repeat per node hostname (CA, each orderer, each peer), always using 0-based indices for multi-instance node types (`orderer0`, `orderer1`, `peer0`, `peer1`, ...).
4. Verify with `dig <hostname> +short` — should resolve straight to the origin IP, not a Cloudflare IP range.

### Step 1.2 — Port Scheme for TWS's 2-Orderer/2-Peer Layout (DECIDED — 2026-09-02)

Since all 5 nodes share one VPS/public IP, each node type's second instance needs distinct ports. Decision, extending the pattern already used for peers in `root-resolver-testnet` (which offsets its second org's peer by +2000, i.e. 7051→9051):

| Node | Hostname | Peer/General port | Chaincode/Admin port | Operations port |
|------|----------|--------------------|------------------------|-------------------|
| CA | `ca.tws.rwrrn.recordweb.dev` | 7054 (default Fabric CA port) | — | — |
| Orderer 0 | `orderer0.tws.rwrrn.recordweb.dev` | 7050 (general) | 7053 (admin) | 9443 |
| Orderer 1 | `orderer1.tws.rwrrn.recordweb.dev` | 8050 (general) | 8053 (admin) | 9446 |
| Peer 0 | `peer0.tws.rwrrn.recordweb.dev` | 7051 (peer) | 7052 (chaincode) | 9444 |
| Peer 1 | `peer1.tws.rwrrn.recordweb.dev` | 8051 (peer) | 8052 (chaincode) | 9445 |

Rationale: reuses the existing testnet's port layout for `orderer0`/`peer0` unchanged (7050/7053/9443 and 7051/7052/9444 respectively, matching `orderer.orderer.recordweb.dev` and `peer0.recordweb.org` in the reviewed `root-resolver-testnet` compose file), then offsets the second instance of each node type by +1000 on the primary ports (8050/8051) and keeps the secondary ports adjacent (8053, 8052), with operations ports assigned sequentially in the free 9443–9446 range to avoid collisions with the testnet's own operations ports (9443, 9444, 9445 are already used by the existing testnet if it runs on the same host — **to confirm this is not a conflict, see Open Items**).

**Open item flagged**: if the existing `root-resolver-testnet` is running on the *same* VPS at the same time as the new TWS Stage 1 network, the operations ports 9443/9444/9445 would collide. This needs to be confirmed/resolved before both networks run simultaneously (see Open Items table below).

### Step 1.3 — Firewall / Open Ports on TWS VPS (NEXT STEP — not yet done)

Based on the port scheme above, the following inbound ports need to be open on the Infomaniak VPS Lite firewall (and any OS-level firewall, e.g. `ufw`) for Stage 1: **7050, 7051, 7052, 7053, 7054, 8050, 8051, 8052, 8053**, plus operations ports if external monitoring access is desired (otherwise these can remain internal-only). Not yet started — this is the next concrete step.

### Step 1.4 — Adapt `root-resolver-testnet` Config for TWS's Layout (NOT STARTED)

Plan: use the reviewed `network/docker-compose.yml` (Section "Reference" above) as the direct template, adapted for:
- 1 organisation (`TWSOrg` or similar — exact org/MSP name TBD) instead of the testnet's 2 (`RecordWebOrg`, `SwissGovOrg`)
- 2 orderers (`orderer0`, `orderer1`) instead of 1, with the port scheme from Step 1.2
- 2 peers (`peer0`, `peer1`) instead of 1 per org, with the port scheme from Step 1.2
- Hostnames matching Step 1.1's DNS records (`ca.tws.rwrrn.recordweb.dev`, etc.) instead of `recordweb.org`/`swissgov.recordweb.dev`
- A Fabric CA service (`ca.tws.rwrrn.recordweb.dev`, port 7054) — not present in the reviewed testnet compose file (which appears to use `cryptogen` instead of a running CA server, based on the `./crypto-config` volume mounts); needs to be added since Stage 1 explicitly requires a running Fabric CA for identity issuance (see `RootResolver-Network.md` Section 4.6).

Not yet started — blocked on Step 1.3 (firewall) and confirming the CA-vs-cryptogen approach question above.

---

## Stage 2 — Association Bootstrap/Discovery Node (NOT STARTED)

Planned scope (see `RootResolver-Network.md` Section 3.6): 1 Fabric CA + 1 non-endorsing peer for the RecordWeb Trust Association, hostname `peer.recordweb.org`, joined to channels purely for gossip-based discovery, never as a required endorser, no orderer.

Note: the existing `root-resolver-testnet` already uses the domain `recordweb.org` for its `RecordWebOrg` peer organisation (`peer0.recordweb.org`) — this is a **different, pre-existing use of `recordweb.org`** from the same project family, and will need to be reconciled with the plan to register `recordweb.org` as the *association's* institutional domain (see Open Items).

Not yet started.

---

## Stage 3 — MC, NB Join (NOT STARTED)

Blocked on: MC and NB infrastructure clarification (parked per `RootResolver-Network.md` Section 8).

---

## Open Items Carried Forward

| # | Item | Status |
|---|------|--------|
| 1 | Confirm whether `root-resolver-testnet` and the new Stage 1 TWS network will run simultaneously on the same VPS, and if so, resolve the operations-port collision risk (9443/9444/9445 used by both) | Open |
| 2 | Decide CA approach for Stage 1: run a live Fabric CA server (`ca.tws.rwrrn.recordweb.dev`), vs. reuse the testnet's apparent `cryptogen`-based approach — Stage 1 plan currently assumes a live CA per `RootResolver-Network.md` Section 4.6 | Open |
| 3 | Reconcile `recordweb.org` already being used by the existing testnet's `RecordWebOrg` peer org vs. the plan to register `recordweb.org` for the association (Stage 2) | Open |
| 4 | Open firewall ports 7050-7054, 8050-8053 on TWS VPS | Open — next concrete step |
| 5 | Exact org/MSP name for TWS (e.g. `TWSOrg`/`TWSMSP`) | Open |
| 6 | IPv6 (AAAA) records for TWS nodes | Deferred, not urgent |
| 7 | MC / NB infrastructure | Parked |

---

## Changelog

- 2026-09-02: Document created. Stages renumbered (Stage 1 = TWS only, Stage 2 = Association bootstrap node, Stage 3 = +MC/NB, Stage 4 = +Authorities, Stage 5 = −TWS/MC/NB). Repository confirmed as `recordweb/rwrrn`. Step 1.1 (DNS records) completed with initial 1-based orderer numbering (`orderer1`/`orderer2`).
- 2026-09-02: Reviewed existing `root-resolver-testnet` docker-compose.yml in detail (2 orgs, 1 single-node Raft orderer, 1 peer/org, ports 7050-7053/9443 for orderer, 7051-7052/9444 and 9051-9052/9445 for the two peers). Used this as the baseline reference for Stage 1. Finalised node-numbering convention as 0-based for both orderers and peers (`orderer0`/`orderer1`, `peer0`/`peer1`), superseding the initial 1-based orderer numbering; DNS records corrected accordingly by the project lead and reverified. Defined the full Stage 1 port scheme (Step 1.2): orderer0 on 7050/7053, orderer1 on 8050/8053, peer0 on 7051/7052, peer1 on 8051/8052, with sequential operations ports 9443-9446. Flagged open items: potential operations-port collision with the still-running testnet if co-located on the same VPS; CA-server-vs-cryptogen approach to be decided; `recordweb.org` domain-reuse conflict between the existing testnet's `RecordWebOrg` org and the planned association domain, to be reconciled before Stage 2. Identified firewall port-opening as the immediate next step.
