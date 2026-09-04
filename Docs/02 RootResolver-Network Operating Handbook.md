# RootResolver Network: Operating Handbook (OHB)



## 1. Purpose and Scope

This document specifies the global RecordWeb RootResolver network, as required by:

- RWC issue [#17 — Define governance and operating requirements for the global RootResolver network](https://github.com/recordweb/rwc/issues/17)
- RWP issue [#24 — Define the global RootResolver namespace-resolution model](https://github.com/recordweb/rwp/issues/24)
- RWP issue [#25 — Specify the Hyperledger Fabric profile for the global RootResolver](https://github.com/recordweb/rwp/issues/25)
- RWP issue [#26 — Define governance and operating requirements for the global RootResolver network](https://github.com/recordweb/rwp/issues/26)
- RWP issue [#23 — Define did:rwp syntax for globally resolvable and locally scoped Record DIDs](https://github.com/recordweb/rwp/issues/23)

A technology-neutral evaluation ("RecordWeb RootResolver-Network Evaluation") was carried out ahead of this document. Its conclusion: a **permissioned blockchain** is the only architecture category offering structural, multi-party tamper-proof control over shared write sovereignty, and **Hyperledger Fabric** is the best-fit platform within that category, given the globally consistent namespace state required by RWP #24. This decision is treated as settled for the purposes of this document.

This document does not replace the normative specification. It captures the concrete build plan, the participating (pseudo-)organisations, open decisions, and the migration path toward real authority-operated organisations.



## 2. Normative Baseline (from RWC/RWP)

Summary of binding requirements this build must satisfy:

- A named operating organisation must coordinate the network and publish a governance framework (RWC #17).
- The governance framework must define admission/withdrawal, namespace registration/mutation procedures, roles and authorisation, change management, incident handling, auditability, and continuity (RWC #17, RWP #26).
- The network must use Hyperledger Fabric with a RecordWeb-conformant namespace-registry chaincode (RWP #25).
- The registry accepts only Global Namespace Identifiers (canonical UUIDv4, per RWP #23) and must not store DID Documents, Records, Record content, or access-control decisions (RWP #25).
- Each current routing record must contain at minimum: `namespace`, `resolverEndpoint`, `registeredBy`, `registeredAt`, `txId` (RWP #25).
- The registry must expose `ResolveNamespace(namespace)` and `GetNamespaceHistory(namespace)` (RWP #25).
- Registrar identity must derive from the authenticated Fabric client identity and must not be overridable via transaction arguments (RWP #25 comment).
- Registry mutations require **multi-organisation endorsement**; no single participant may unilaterally modify global routing data (RWP #25 comment).
- Transaction history must be immutable (RWP #25 comment).

Additional principles carried forward from the evaluation:

- Coordination role without data ownership (EBSI/Europeum-EDIC model; US Federal PKI Policy Authority model).
- Separation of functions inspired by the RSSAC model (Secretariat, Strategy/Policy, Accreditation/Exclusion, Performance Monitoring, Finance).
- A binding, contractually enforceable governance structure is preferable to a purely advisory one for reaching production readiness faster.



## 3. Governance

### 3.1 Pilot-Phase Governance Framework

The pilot uses pseudo-organisations, not the final operating organisation envisioned by RWC #17. This document itself is intended to **become the working governance framework** for the pilot phase: it should be extended, as the project matures, to explicitly cover the minimum content required by RWC #17 (admission/withdrawal, namespace registration/mutation, roles/authorisation, change management, incident handling, auditability, continuity) directly in dedicated sections, rather than in a separate document. A dedicated, more formal governance document can be split out later once a real operating organisation is established.

- **Decision-making rule (adopted, finalised)**:
  - **Pilot phase** (while any non-governmental organisation still participates): simple majority of all members, **with TWS holding a veto right**.
  - **Operating phase** (once the pilot phase has ended per Section 4): simple majority of all members — **no veto for any member**.
- **Namespace registration authority (adopted for the pilot phase; options for the operating phase)**: see the dedicated rule below.
- Accountability: **TWS (the RecordWeb Community Group Co-Chair's company) takes fallback responsibility** for the pilot's infrastructure, domain names, and data-protection aspects if no other arrangement is agreed. This is adopted as the default for the pilot phase.

### 3.2 Namespace Registration Authority

**Any participating organisation may register namespaces on the `root-resolver` channel without prior approval from the others.** It is using its own Fabric identity as `registeredBy`.



### 3.3 Organisation Joining the Network

#### 3.3.1 Preparation (performed by the joining organisation, on its own infrastructure)

1. Stand up its own Fabric CA.
2. Enroll the CA's bootstrap admin identity, then rotate/retire its secret once the organisation's real admin identities are established.
3. Register and enroll the organisation's own admin identities: one for the peer-org MSP, one for the orderer-org MSP (if the organisation contributes orderer nodes).
4. Register and enroll the organisation's own node identities: peers (minimum 2, for redundancy), and orderers if the organisation contributes to the shared ordering service.
5. Start all node containers and verify locally that each starts cleanly (start nodes one at a time, checking logs before starting the next).

#### 3.3.2 Governance Steps (before technical network integration)

6. The candidate organisation is proposed and reviewed against the network's admission criteria (ability to reliably operate the required infrastructure; acceptance of the governance framework; eligibility as a government or government-delegated organisation).
7. Existing member organisations approve admission per the network's decision-making rule.
8. Admission to the network and admission to the operating association happen together — there is no network participation without association membership.

#### 3.3.3 Technical Network Integration (performed by/coordinated with existing network operators)

9. The joining organisation's CA root certificate and node certificates are shared with the existing network operators, to add its MSP definitions to the channel configuration.
10. The channel configuration is updated (via a channel-update transaction) to add the joining organisation's peer-org MSP and orderer-org MSP as new channel members.
11. If the joining organisation contributes orderer nodes: the channel's `ConsenterMapping` is extended to include its orderer nodes. If the channel uses SmartBFT consensus, confirm the resulting total consenter count still satisfies (and ideally comfortably exceeds) the `3F+1` fault-tolerance requirement.
12. Anchor-peer configuration is updated so the joining organisation's peers and the existing organisations' peers can discover each other via gossip.
13. The endorsement policy is recalculated to include the joining organisation as required — this is a mandatory step on every admission, not optional.

### 1.4 Activation

14. The joining organisation's peers join the channel using the current channel configuration block.
15. Verify the new organisation can both query existing ledger state and submit a namespace registration that receives correct multi-organisation endorsement — test this on the network's test channel before any production channel involvement.
16. The joining organisation begins normal operation.

### 3.4. Organisation Withdrawing from the Network

#### 3.4.1 Notice and Preparation

1. The withdrawing organisation gives notice per the network's applicable minimum notice period for its membership category.
2. If the withdrawing organisation held any fallback accountability role (e.g. for shared infrastructure, domain names, or data-protection responsibilities), that role is explicitly reassigned to another organisation before withdrawal takes effect.

#### 3.4.2 Governance Confirmation

3. Remaining member organisations formally acknowledge the withdrawal (a voluntary withdrawal does not require an exclusion vote).

#### 3.4.3 Technical Removal from the Network

4. The channel configuration is updated to remove the withdrawing organisation's peer-org MSP and orderer-org MSP from the channel membership list.
5. The channel's `ConsenterMapping` is updated to remove the withdrawing organisation's orderer nodes, if it contributed any. Critical check: confirm the remaining consenters still satisfy the `3F+1` minimum for the consensus type in use — removing an organisation must never drop the cluster below its fault-tolerance threshold or leave it non-functional.
6. Anchor-peer entries pointing to the withdrawing organisation's peers are removed or replaced with a remaining organisation's anchor peer.
7. The endorsement policy is recalculated so the withdrawing organisation is no longer referenced as a required (or optional) endorser.

#### 3.4.4 Association and Ledger-Level Consequences

8. The withdrawing organisation's representative simultaneously exits the operating association — network participation and association membership are coupled in both directions.
9. The withdrawing organisation's historical transactions remain permanently and immutably in the ledger; only its future write/endorsement rights are removed. No historical data is deleted or altered.

#### 3.4.5 Infrastructure Decommissioning

10. Once the withdrawing organisation's removal from the channel configuration is confirmed and active, it may decommission its own node infrastructure (CA, peers, orderers) — remaining network operators are technically unaffected by this step, since the channel configuration update (Step 4) already excludes it from consensus and endorsement.

### 3.5 Operating Association

**"RecordWeb Trust Association"** under Swiss law (Verein), chartered explicitly as a **transitional operating organisation** for the RootResolver network, satisfying the RWC #17 requirement for a named operating organisation from the start of the pilot. Institutional domain: **`recordweb.org`**. Draft statutes are available (see `Statuten-RecordWeb-Trust-Association.md`).

The statutes encode the following transformation path, coupling association membership directly to operating a network organisation:

- **Membership is coupled to operation**: whoever stands up and operates an organisation participating in the RecordWeb RootResolver network automatically becomes a member of the association; there is no dual state of "runs a network org but isn't a member" or "is a member but runs no network org" — **except for the association's own bootstrap/discovery organisation**, which is exempt from this coupling since it is an operational function of the association itself.
- **Withdrawal is coupled to ceasing operation**: an organisation that stops operating its network node (per the withdrawal procedure) simultaneously exits the association.



## 4. Network Topology

### 4.1 Version

- Fabric CA version: **1.5**
- Fabric version: **3.1.x** (not 2.5 LTS), with images pinned to `hyperledger/fabric-orderer:3.1`, `hyperledger/fabric-peer:3.1`.

### 4.2 Organisations and MSPs

- Each organisation operates its own Membership Service Provider (MSP) with its own (Fabric) CA acting as root of trust for that org.
- Identity issuance approach (see Section 4.5 for full detail): each org's CA issues all identities for that org (admins, peer nodes, orderer nodes, client applications).
- The operating association also operates its own minimal MSP (1 CA + 1 peer, `peer.recordweb.org`), joined to channels as a non-endorsing member for discovery purposes only.

### 4.3 Peers

- 2 peers per organisation are recommended (plus the association's single non-endorsing anchor peer).
- State database: **LevelDB**, adopted for the start. Simpler to operate on lightweight VPS infrastructure than CouchDB, and sufficient for the chaincode's lean data model (namespace → routing record). Can be revisited later if rich queries become a real requirement.

### 4.4 Orderers

- 2 orderer per organisation are recommended.
- SmartBFT requires **at least 2 orderer nodes for the network**.
- The association's own organisation does **not** contribute an orderer node.

### 4.5 Channels

- **Test channel**: `root-resolver-test` channel (infrastructure test and chaincode test).
- **Production channel**: `root-resolver` channel.

The association's anchor peer is joined to both channels from the start, since its role (discovery) is independent of the test/prod distinction.

### 4.6 Endorsement Policy 

- **Consensus**: **SmartBFT** (Byzantine Fault Tolerant), not Raft. SmartBFT requires a minimum of 4 consenters (formula `3F+1`, F=1) to tolerate even one faulty/malicious orderer. With only 2 orderers, BFT provides zero fault tolerance.
- **Standing rule**: the endorsement policy MUST be revisited and adjusted whenever the set of participating organisations changes (a joiner or a leaver). This is a permanent agenda item for every onboarding/offboarding procedure.
- The association's organisation is **never** included as a required endorser in this policy, by design.

### 4.7 Identity Issuance and Key Custody

- The org's CA registers and enrolls all further identities for that org: node admin, peer identities, both orderer identities, and any client-application identities (e.g. for the admin app / registration tooling).
- **Key custody for CA root material and admin private keys**: each organisation MUST securely safeguard its CA root key material, admin enrollment secrets, and TLS CA material (e.g. via an access-controlled secrets manager or equivalent protection), with access restricted to that org's designated operator(s).
- Node-level private keys (peer, orderer) can remain on the filesystem inside each org's infrastructure with restrictive file permissions, as is standard practice for non-HSM Fabric deployments; only the CA root and admin identities warrant the extra protection of a secrets-management mechanism.



## 5. Namespace Registry Chaincode

- Accepts registration only for Global Namespace Identifiers (canonical UUIDv4 per RWP #23).
- State key: the Global Namespace Identifier.
- Current routing record fields: `namespace`, `resolverEndpoint`, `registeredBy`, `registeredAt`, `txId`.
- Operations: `ResolveNamespace(namespace)`, `GetNamespaceHistory(namespace)`.
- Must reject local namespace registrations.
- Must not store DID Documents, Records, Record content, or access-control decisions.
- Registrar identity derived from authenticated Fabric client identity (not client-supplied).

**Chaincode language: Go**. The existing `recordweb/root-resolver-testnet` repository already implements the namespace-registry chaincode in Go (`chaincode/namespace-registry/main.go`, `go.mod`).The productive chaincode carries over the existing conceptual design (data model, operations, registrar-identity handling) from this testnet implementation, but is trimmed and hardened for production use (input validation, error handling, adherence to the finalised RWP #25/#23 requirements, removal of any test-only shortcuts).



## 6. Rollout Plan

1. **Stage 1: Initialisation (TWS only)**: TWS stands up its own CA, 4 orderers, and 2 peers under the `tws.rwrrn.recordweb.dev` naming scheme; single-org test network to validate chaincode logic and operational scripts (CA bootstrap, MSP generation, channel creation, chaincode deployment) end-to-end. Association founding and the association's own bootstrap/discovery organisation (`peer.recordweb.org`) can be set up in parallel or immediately after.
2. **Stage 2: Pilot (additional non-Gov Orgs)**: additional orgs stand up their node set and join the association; network is extended to >3 organisations plus the association's anchor peer; `root-resolver` and `root-resolver-test` channels are created with all three orgs as members; endorsement policy is activated.
3. **Stage 3: RampUp (first Gov Orgs)**: real governmental organisations (or government-delegated organisations) begin onboarding via the standard admission procedure, typically under their own governmental domain (e.g. `rwrrn.admin.ch`), discoverable via the association's stable `peer.recordweb.org` anchor peer, and joining the association as they join the network.
4. **Stage 4: Production (no non-Gov Orgs)**: once no non-governmental organisation remains and the association's membership has fully transitioned to governmental/government-delegated organisations, all non-Govs withdraw via the standard withdrawal procedure.



## 7. Stage 1: Initialisation (TWS only)

| Code | Name | Represented by | Infrastructure | Status |
|------|------|-----------------|-----------------|--------|
| TWS | TRIEBWERKSTATT | RecordWeg CG CoChair | VPS at Infomaniak (VPS Lite, tier 1 / XS, Ubuntu) | Confirmed |

### 7.1 Infrastructure

- Host: VPS Lite, Infomaniak, **tier 1 / XS**: 1 vCPU, 2 GB RAM, 20 GB NVMe SSD, KVM virtualization, 500 Mbit/s, unlimited traffic, dedicated IPv4+IPv6.
- OS: **Ubuntu**.
- Container runtime: Docker.
- Open ports required: peer (7051), peer chaincode (7052), 4x orderer (7050, +1 additional port), CA (7054)
- Domain: `tws.rwrrn.recordweb.dev`


### 7.2 Orgs
- Peer-org MSP: `TWSOrgMSP`. 
- Orderer-org MSP: `TWSOrdererMSP`

### 7.3 Nodes
| Node | Hostname pattern |
|------|-------------------|
| Fabric CA | `ca.tws.rwrrn.recordweb.dev` |
| Orderer 0 | `orderer0.tws.rwrrn.recordweb.dev` |
| Orderer 1 | `orderer1.tws.rwrrn.recordweb.dev` |
| Orderer 2 | `orderer2.tws.rwrrn.recordweb.dev` |
| Orderer 3 | `orderer3.tws.rwrrn.recordweb.dev` |
| Peer 0 | `peer0.tws.rwrrn.recordweb.dev` |
| Peer 1 | `peer1.tws.rwrrn.recordweb.dev` |




## 4. Stage 2: Pilot (additional non-Gov Orgs)

The network adds more pseudo-organisation from the RecordWeb Community Group. Each is expected to be replaced over time by a real (governmental) organisation once authorities are ready to join operationally.

| Code | Name | Represented by | Infrastructure | Status |
|------|------|-----------------|-----------------|--------|
| TWS | TRIEBWERKSTATT | RecordWeg CG CoChair | VPS at Infomaniak (VPS Lite, tier 1 / XS, Ubuntu) | Confirmed |
| TBD | --- | --- | --- | --- |
| TBD | --- | --- | --- | --- |



## 5. Stage 3: RampUp (first Gov Orgs)

| Code | Name | Represented by | Infrastructure | Status |
|------|------|-----------------|-----------------|--------|
| TWS | TRIEBWERKSTATT | RecordWeg CG CoChair | VPS at Infomaniak (VPS Lite, tier 1 / XS, Ubuntu) | Confirmed |
| TBD | --- | --- | --- | --- |
| TBD | --- | --- | --- | --- |
| TBD | --- | --- | --- | --- |
| TBD | --- | --- | --- | --- |

Infrastructure of governmental organisation will not be tracked.


## 6. Stage 4: Production (no non-Gov Orgs)

Infrastructure no longer tracked by this document.



## 7 Operating Association Domain

### 7.1 Infrastructure

- Host: VPS Lite, Infomaniak, **tier 1 / XS**: 1 vCPU, 2 GB RAM, 20 GB NVMe SSD, KVM virtualization, 500 Mbit/s, unlimited traffic, dedicated IPv4+IPv6.
- OS: **Ubuntu**.
- Container runtime: Docker.
- Open ports required: peer (7051), peer chaincode (7052), CA (7054)
- Domain: `recordweb.org`

| Node | Hostname pattern |
|------|-------------------|
| Fabric CA | `ca.recordweb.org` |
| Peer 0 | `peer.recordweb.org` |

---
