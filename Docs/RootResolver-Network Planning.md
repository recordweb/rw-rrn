# RootResolver Network — Planning Document

Status: DRAFT — pilot phase planning
Last updated: 2026-09-02

## 1. Purpose and Scope

This document tracks the planning and productive build-out of the global RecordWeb RootResolver network, as required by:

- RWC issue [#17 — Define governance and operating requirements for the global RootResolver network](https://github.com/recordweb/rwc/issues/17)
- RWP issue [#25 — Specify the Hyperledger Fabric profile for the global RootResolver](https://github.com/recordweb/rwp/issues/25)
- RWP issue [#26 — Define governance and operating requirements for the global RootResolver network](https://github.com/recordweb/rwp/issues/26)
- RWP issue [#23 — Define did:rwp syntax for globally resolvable and locally scoped Record DIDs](https://github.com/recordweb/rwp/issues/23)

A technology-neutral evaluation ("RecordWeb RootResolver Network Evaluation") was carried out ahead of this plan. Its conclusion: a **permissioned blockchain** is the only architecture category offering structural, multi-party tamper-proof control over shared write sovereignty, and **Hyperledger Fabric** is the best-fit platform within that category, given the globally consistent namespace state required by RWP #24. This decision is treated as settled for the purposes of this document.

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

Additional principles carried forward from the technology-neutral evaluation:

- Coordination role without data ownership (EBSI/Europeum-EDIC model; US Federal PKI Policy Authority model).
- Separation of functions inspired by the RSSAC model (Secretariat, Strategy/Policy, Accreditation/Exclusion, Performance Monitoring, Finance).
- A binding, contractually enforceable governance structure is preferable to a purely advisory one for reaching production readiness faster.

## 3. Participating Organisations (Pilot Phase)

The network starts with three pseudo-organisations, all structured identically so each can support the others operationally. Each is expected to be replaced over time by a real (e.g. governmental) organisation once authorities are ready to join operationally.

| Code | Name | Represented by | Infrastructure | Status |
|------|------|-----------------|-----------------|--------|
| TWS | TRIEBWERKSTATT | Project lead (own company) | VPS at Infomaniak (VPS Lite, tier 1 / XS, Ubuntu) | Confirmed |
| MC | Melvin Carvalho | CG Co-Chair | Unknown yet | Parked |
| NB | Nicolas Bürkler | CG member, eCH working group, Canton Lucerne | Private infrastructure | Parked |

Each pseudo-organisation is a placeholder for governance and endorsement purposes only. It does not imply legal authority or long-term production accountability (see Section 6). **TWS (the project lead's own company) acts as fallback accountable party** for the pilot if no other arrangement is in place.

### 3.1 Node Layout (identical per organisation)

Every organisation — TWS, MC, NB, and any later joiner — runs the same node set, so that all operators are structurally equal and can support each other technically:

| Component | Count per org | Notes |
|-----------|---------------|-------|
| Fabric CA | 1 | Issues the org's MSP identities (admins, peers, orderer, client apps) |
| Orderer | 2 | Contributes 2 nodes to the shared Raft ordering service — 6 orderer nodes total at pilot start (TWS+MC+NB) |
| Peer | 2 | Redundancy within the org; runs LevelDB as state database (see 4.2) |

With 2 orderer nodes per organisation, the pilot starts with 6 Raft orderer nodes in total, giving real fault tolerance (the cluster can lose multiple nodes, not just one, depending on distribution) rather than the bare minimum.

### 3.2 TWS — Infrastructure

- Host: VPS Lite, Infomaniak, **tier 1 / XS**: 1 vCPU, 2 GB RAM, 20 GB NVMe SSD, KVM virtualization, 500 Mbit/s, unlimited traffic, dedicated IPv4+IPv6.
- **Capacity — confirmed workable**: TWS already runs the complete Fabric test network (all node types) on this same VPS for testing purposes; the pilot node set (1 CA + 2 orderers + 2 peers) alongside the existing Harbor instance has been validated as viable for test/pilot use on this tier.
- OS: **Ubuntu** (confirmed).
- Container runtime: Docker (assumed, per existing prototyping stack); Harbor already deployed on this VPS from a prior Fabric project — reused as the container-image registry for this network's peer/orderer/CA images.
- Public endpoint(s): see Section 3.5 (domain and naming concept).
- Open ports required: peer (7051), peer chaincode (7052), 2x orderer (7050, +1 additional port), CA (7054)

### 3.3 MC — Infrastructure (placeholder, same structure as TWS)

- Host: TBD — to be discussed with Melvin Carvalho
- Specs: TBD (same node set: 1 CA, 2 orderers, 2 peers)
- OS: TBD
- Container runtime: TBD
- Public endpoint(s): will follow the naming concept in Section 3.5 once infrastructure is confirmed
- *(Clarification with MC deferred — infrastructure availability question parked for now.)*

### 3.4 NB — Infrastructure (placeholder, same structure as TWS)

- Host: private infrastructure (owned by Nicolas Bürkler)
- Specs: TBD (same node set: 1 CA, 2 orderers, 2 peers)
- OS: TBD
- Container runtime: TBD
- Public endpoint(s): will follow the naming concept in Section 3.5 once infrastructure is confirmed
- *(Clarification with NB deferred — infrastructure availability question parked for now.)*

### 3.5 Domain and Node Naming Concept (Pilot Organisations)

The project lead owns the domain **`recordweb.dev`**. Proposal (to be confirmed): use a dedicated subdomain for the whole network, then follow Fabric's established `<nodetype><index>.<org>.<network-subdomain>` pattern for individual nodes, consistent with common multi-organisation Fabric deployment practice.

**Network subdomain**: `rwrrn.recordweb.dev` (RecordWeb RootResolver Network), as proposed.

**Per-organisation subdomain**: each organisation gets its own subdomain under `rwrrn.recordweb.dev`, using the org code already adopted in Section 3 (lowercased):

- TWS: `tws.rwrrn.recordweb.dev`
- MC: `mc.rwrrn.recordweb.dev`
- NB: `nb.rwrrn.recordweb.dev`
- Future country/authority organisations: proposal — use the **ISO 3166-1 alpha-2 country code** (lowercased) as the org subdomain, e.g. `ch.rwrrn.recordweb.dev` for a Swiss authority organisation, `de.rwrrn.recordweb.dev` for a German one. This keeps the scheme predictable and language-neutral once real countries join (Stage 3). If a country ever needs more than one organisation (e.g. federal + a carrier organisation in parallel, though the governance rule in Section 6.2 assumes one org per admitted party), a suffix such as `ch-dvs.rwrrn.recordweb.dev` could disambiguate — flagged here only as a fallback, not adopted unless needed.

**Per-node hostnames**, following the org subdomain:

| Node | Hostname pattern | Example (TWS) |
|------|-------------------|----------------|
| Fabric CA | `ca.<org>.rwrrn.recordweb.dev` | `ca.tws.rwrrn.recordweb.dev` |
| Orderer 1 | `orderer1.<org>.rwrrn.recordweb.dev` | `orderer1.tws.rwrrn.recordweb.dev` |
| Orderer 2 | `orderer2.<org>.rwrrn.recordweb.dev` | `orderer2.tws.rwrrn.recordweb.dev` |
| Peer 0 | `peer0.<org>.rwrrn.recordweb.dev` | `peer0.tws.rwrrn.recordweb.dev` |
| Peer 1 | `peer1.<org>.rwrrn.recordweb.dev` | `peer1.tws.rwrrn.recordweb.dev` |

This matches the de-facto standard Fabric naming convention (`peer0.org1.example.com`, `orderer1.org1.example.com`) used across reference deployments, adapted to the three-level structure `<node>.<org>.<network>.recordweb.dev`. Each organisation is responsible for creating and maintaining its own DNS records (as CNAME or A records) pointing to its own infrastructure; TWS does not need to manage DNS on behalf of MC, NB, or future country organisations — only the shared `rwrrn.recordweb.dev` delegation/zone needs to be set up once under `recordweb.dev`.

**Open question**: should `rwrrn.recordweb.dev` be delegated as its own DNS zone (each org gets an NS delegation for `<org>.rwrrn.recordweb.dev` and manages its own records independently), or should all records live in one zone administered centrally (e.g. by TWS or the association) for simplicity during the pilot? Delegation is cleaner long-term (matches the "each org runs its own infrastructure" philosophy) but requires slightly more DNS setup per org; a single centrally managed zone is simpler to start with but re-creates a small central dependency. Given the pilot's small size, a centrally managed zone for now, with delegation revisited at Stage 3, may be the pragmatic choice — but this is left open for your decision.

**Country organisations are not expected to use this domain pattern**: as noted for Stage 3, a joining country will typically run its RootResolver network organisation under its own governmental domain (e.g. a hypothetical `rwrrn.admin.ch` for a Swiss federal deployment), not under `recordweb.dev`. The `rwrrn.recordweb.dev` naming scheme therefore applies primarily to TWS, MC, NB, and any other non-governmental pilot participant; country organisations register whatever `resolverEndpoint` and node hostnames fit their own domain governance, and the network's peer discovery does not depend on a single shared domain (see Section 3.6).

### 3.6 Association Domain and Bootstrap/Discovery Node

**Association domain (adopted)**: the operating association (Section 6.3) uses **`recordweb.org`** as its institutional domain, distinct from `recordweb.dev` (the project lead's personal/TWS domain used for the pilot's technical `rwrrn.recordweb.dev` subdomain). `recordweb.org` was confirmed available at the time of writing. This mirrors how comparable W3C-adjacent coordination bodies separate their institutional identity from a technical/project domain (e.g. Trust over IP Foundation uses `trustoverip.org`, not a `.dev` domain) and fits a non-profit coordination body better than `.dev`, which reads as a developer/project domain. The association's own materials (statutes, governance framework, public-facing information) are proposed to live under `recordweb.org`; the technical pilot network keeps using `rwrrn.recordweb.dev` for now.

**Association as a bootstrap/discovery organisation (adopted, technically clarified)**: yes, this is both possible and sensible, and maps cleanly onto an existing Fabric mechanism — the **anchor peer**. An anchor peer is a stable, well-known peer that other organisations' peers contact once to discover, via Fabric's gossip protocol, all other peers active on a channel; every organisation on a channel typically has at least one anchor peer for exactly this purpose. A world-known address like **`peer.recordweb.org`** run by the association would work well as a shared, memorable first point of contact — especially valuable once real countries run their networks under their own unpredictable domains (e.g. `rwrrn.admin.ch` for Switzerland) rather than under `recordweb.dev`.

**What this requires and what it does *not* mean:**

- The association becomes a **regular Fabric organisation** on the network like TWS/MC/NB — it needs its own MSP and therefore its own Fabric CA (a client cannot join a channel without an org identity backing it). This is a real, if small, technical commitment: at minimum 1 CA + 1 peer to be run reliably.
- **No orderer is needed** for this role — orderers order transactions; a discovery/bootstrap peer does not need to contribute to that function at all.
- **Endorsement participation is optional and should be declined**: the endorsement policy (Section 4.5, `OutOf(2, TWS, MC, NB)`, evolving as members change) simply never needs to reference the association's peer as a required endorser. The association's peer can join channels purely to host the ledger and serve gossip/discovery traffic, without ever being asked to endorse a transaction. This achieves exactly the "no active role in the chain, just a first point of contact" outcome you're after.
- **Important technical caveat**: Fabric does not have a true "metadata-only, no ledger data" peer role — any peer that joins a channel maintains a full copy of that channel's ledger and can answer chaincode queries on it, not just organisation/peer discovery. There is no built-in way to expose *only* "who else is on this network" without also being a normal, ledger-holding peer. For the RootResolver network this is not a real problem, since the ledger only ever contains non-sensitive namespace routing metadata (RWP #25 explicitly excludes DID Documents, Records, or access-control data from the registry) — so the association's peer holding a full ledger copy carries no confidentiality concern, only the (small) operational duty of keeping one peer running.
- Recommended minimal footprint for the association's own organisation: **1 Fabric CA + 1 peer**, hostname `peer.recordweb.org`, joined to both the `test` and `prod` channels as a non-endorsing member, primarily serving as the network's stable, universally known anchor peer for discovery.

**Consequence for governance**: since the association itself would then also operate a (minimal) network organisation, its own peer's admission and continued operation should be explicitly exempted from the "whoever runs a network org is a member, whoever stops is out" coupling rule in Section 6.3/Statuten Art. 5 — the association's own bootstrap peer is an operational function of the association itself, not a separate member. This exemption is proposed as a small addition to the statutes (see Statuten, Art. 5 Abs. 4, to be added) and should be confirmed.

## 4. Network Topology

### 4.1 Organisations and MSPs

- Each organisation (TWS, MC, NB, and later joiners) operates its own Membership Service Provider (MSP) with its own Fabric CA acting as root of trust for that org.
- Identity issuance approach (see Section 4.5 for full detail): each org's Fabric CA issues all identities for that org (admins, peer nodes, orderer nodes, client applications).
- The operating association (Section 3.6) also operates its own minimal MSP (1 CA + 1 peer, `peer.recordweb.org`), joined to channels as a non-endorsing member for discovery purposes only.

### 4.2 Peers

- 2 peers per organisation, per the layout agreed above (plus the association's single non-endorsing anchor peer, Section 3.6).
- State database: **LevelDB**, adopted for the pilot start. Simpler to operate on lightweight VPS infrastructure than CouchDB, and sufficient for the chaincode's lean data model (namespace → routing record). Can be revisited later if rich queries (e.g. filtering by `registeredBy` or `registeredAt`) become a real requirement.

### 4.3 Orderers

- Raft ordering service with **2 orderer nodes contributed by each organisation** (TWS, MC, NB) — 6 nodes total at pilot start.
- This gives headroom beyond the bare Raft fault-tolerance minimum and reflects the decentralised governance model from the start.
- The association's own organisation (Section 3.6) does **not** contribute an orderer node.

### 4.4 Channels

- **Two separate channels**: one `test` channel and one `prod` channel, both spanning the same organisation set.
- **Rule for the pilot phase**: as long as only non-governmental pseudo-organisations (TWS, MC, NB, and any further non-authority joiners) operate the network, **no entries are written to the `prod` channel** — all registrations happen on `test` only.
- This allows future real (governmental) participants to join and go live on `prod` directly, without inheriting pilot-era registrations, while the pilot organisations continue exercising the network on `test` in parallel even after `prod` goes live.
- This rule is adopted as a governance principle (see Section 6).
- The association's anchor peer (Section 3.6) is joined to both channels from the start, since its role (discovery) is independent of the test/prod distinction.

### 4.5 Endorsement Policy

- Adopted for pilot start: `OutOf(2, TWS, MC, NB)` — 2 of 3 organisations must endorse a registry mutation. Tolerates one org being temporarily offline while still preventing unilateral changes.
- **Standing rule**: the endorsement policy MUST be revisited and adjusted whenever the set of participating organisations changes (a joiner or a leaver). This is a permanent agenda item for every onboarding/offboarding procedure (see Section 6.2).
- The association's organisation (Section 3.6) is **never** included as a required endorser in this policy, by design.

### 4.6 Identity Issuance and Key Custody

Recommended approach:

- Each organisation's Fabric CA is bootstrapped with a one-time bootstrap admin identity (enroll ID + secret), used only to initialise the CA and immediately register the org's real admin identity; the bootstrap credentials are then rotated/retired.
- The org's Fabric CA then registers and enrolls all further identities for that org: node admin, peer identities, both orderer identities, and any client-application identities (e.g. for the admin app / registration tooling).
- **Key custody for CA root material and admin private keys**: each organisation MUST securely safeguard its CA root key material, admin enrollment secrets, and TLS CA material (e.g. via an access-controlled secrets manager or equivalent protection), with access restricted to that org's designated operator(s). No specific tool is mandated for the pilot phase; each organisation chooses an appropriate secure-storage mechanism and is responsible for its own key custody.
- A hardware security module (HSM via PKCS#11) is the gold-standard for production Fabric deployments, but is disproportionate for a pilot run by volunteers/small teams; it can be revisited once real authorities join and production-grade key management becomes a governance requirement.
- Node-level private keys (peer, orderer) can remain on the filesystem inside each org's infrastructure with restrictive file permissions, as is standard practice for non-HSM Fabric deployments; only the CA root and admin identities warrant the extra protection of a secrets-management mechanism.

## 5. Namespace Registry Chaincode (Requirements Recap)

- Accepts registration only for Global Namespace Identifiers (canonical UUIDv4 per RWP #23).
- State key: the Global Namespace Identifier.
- Current routing record fields: `namespace`, `resolverEndpoint`, `registeredBy`, `registeredAt`, `txId`.
- Operations: `ResolveNamespace(namespace)`, `GetNamespaceHistory(namespace)`.
- Must reject local namespace registrations.
- Must not store DID Documents, Records, Record content, or access-control decisions.
- Registrar identity derived from authenticated Fabric client identity (not client-supplied).

**Chaincode language: Go** (confirmed). The existing `recordweb/root-resolver-testnet` repository already implements the namespace-registry chaincode in Go (`chaincode/namespace-registry/main.go`, `go.mod`). **Adopted approach**: the productive chaincode carries over the existing conceptual design (data model, operations, registrar-identity handling) from this testnet implementation, but is trimmed and hardened for production use — i.e. not a from-scratch rewrite, but a productisation pass (input validation, error handling, adherence to the finalised RWP #25/#23 requirements, removal of any test-only shortcuts).

Open implementation questions:

- Testing strategy: unit tests, Fabric test network (`test-network`) before multi-org deployment; then promotion path from `test` channel to `prod` channel once eligible (see Section 4.4).
- Versioning/upgrade process for chaincode across three independently operated peers.
- Concrete productisation checklist (input validation, access-control edge cases, audit-history queries, error responses) — to be defined once the existing chaincode is reviewed in detail.

## 6. Governance

### 6.1 Pilot-Phase Governance Framework

The pilot uses pseudo-organisations, not the final operating organisation envisioned by RWC #17. This document itself is intended to **become the working governance framework** for the pilot phase: it should be extended, as the project matures, to explicitly cover the minimum content required by RWC #17 (admission/withdrawal, namespace registration/mutation, roles/authorisation, change management, incident handling, auditability, continuity) directly in dedicated sections, rather than in a separate document. A dedicated, more formal governance document can be split out later once a real operating organisation is established.

- **Decision-making rule (adopted, finalised)**:
  - **Test phase** (while any non-governmental organisation still participates): simple majority of all members, **with TWS holding a veto right**.
  - **Operating phase** (once the test phase has ended per Section 7.1): simple majority of all members — **no veto for any member**.
- **Namespace registration authority (adopted for the test phase; options for the operating phase — see below)**: see the dedicated rule below.
- Accountability: **TWS (the project lead's company) takes fallback responsibility** for the pilot's infrastructure, domain names, and data-protection aspects if no other arrangement is agreed. This is adopted as the default for the pilot phase.

#### 6.1.1 Namespace Registration Authority

**Test phase (adopted)**: a simple rule — **any participating organisation (TWS, MC, NB, and later admitted organisations) may register namespaces on the `test` channel without prior approval from the others.** Since test-channel data carries no production consequence and is explicitly excluded from `prod` promotion (Section 4.4), a low-friction self-service rule is appropriate and keeps the pilot easy to exercise.

**Operating phase — options for later decision** (not yet chosen; presented so the tradeoffs are visible when the time comes):

1. **Self-service registration by the registering organisation only** (each org registers namespaces it is itself responsible for, using its own Fabric identity as `registeredBy`) — simplest, lowest friction, mirrors how DNS registrars work today; risk: no cross-check that a namespace "belongs" to the right country/authority before it is written.
2. **Peer-reviewed registration** (a registration proposal is visible to all members for a short objection window — e.g. 5 business days — before being considered final, without requiring active approval) — balances low friction with a safety net against obvious errors or naming conflicts; no extra endorsement transaction needed, since Fabric's existing multi-org endorsement policy (Section 4.5) already prevents unilateral writes.
3. **Formal approval registration** (an explicit vote or sign-off step, beyond the technical endorsement policy, before a namespace registration is considered valid under the governance framework) — highest assurance, but adds a manual/administrative step on top of the technical safeguards already provided by Fabric endorsement; likely only warranted if namespace squatting, naming disputes, or conflicts between authorities become a real problem in practice.

**Recommendation for later**: option 2 (peer-reviewed, objection-window model) is likely the best fit once real authorities are on `prod` — it adds a governance safety net without duplicating the technical endorsement mechanism Fabric already provides, and avoids the overhead of a full approval process for what should normally be routine, non-controversial registrations.

### 6.2 Standard Admission and Withdrawal Procedure

Because organisations are expected to join and leave over the network's lifetime (pilot pseudo-orgs stepping down, new authorities joining, and — longer-term — authorities themselves potentially withdrawing), a **standard procedure must exist from the start**, not be improvised later.

**Eligible admission parties (adopted, simplified)**: an organisation may be admitted to the network either as (a) **a national government itself**, or (b) **an organisation delegated by that government** to represent it on this matter. This deliberately broadens the earlier "exclusively governmental membership" framing: a delegated organisation does not itself need to consist only of government bodies — what matters is that the relevant government has formally delegated it to act on this matter. Under this simplified rule, both **Digitale Verwaltung Schweiz (DVS)** and **Verein eCH** would qualify for Switzerland, provided the Swiss government (or the relevant cantons) formally delegates the matter to whichever body is intended to represent it — since eCH's existing Confederation/cantonal membership and its established role as the coordination forum for this very initiative make delegation to eCH plausible in practice.

**Admission procedure:**
1. Candidate organisation is proposed and reviewed against baseline eligibility criteria (ability to operate 1 CA + 2 orderers + 2 peers reliably; acceptance of the governance framework; and, from Stage 3 onward, being a government or a government-delegated organisation per the rule above).
2. Existing organisations approve admission (simple majority, subject to TWS veto during the test phase per Section 6.1).
3. Admission to the network (operating an org) and admission to the operating association (Section 6.3) happen together: **standing rule — whoever operates a network organisation is a member of the operating association; there is no network participation without association membership, and vice versa** (with the sole exception of the association's own bootstrap/discovery organisation, Section 3.6, which is an operational function of the association itself, not a separate member).
4. New org stands up its MSP (own Fabric CA), generates its node identities, and receives the channel/network configuration needed to join.
5. Network configuration (channel members, orderer set, endorsement policy) is updated via Fabric's standard channel-update process (`configtxlator` or equivalent) to include the new organisation.
6. Endorsement policy is re-evaluated and adjusted per Section 4.5.
7. New organisation starts on the `test` channel; `prod` participation follows the rule in Section 4.4 (governmental organisations may go straight to `prod`).
8. New organisation's node names follow the naming concept in Section 3.5 (country-code subdomain under `rwrrn.recordweb.dev`), or — as is expected for most real country deployments — its own governmental domain (e.g. `rwrrn.admin.ch`); either way, the association's `peer.recordweb.org` anchor peer (Section 3.6) provides a stable discovery point regardless of which domain a joining organisation uses.

**Withdrawal procedure and notice periods (adopted):**

- **Pilot/test-phase organisations (TWS, MC, NB, and any other non-governmental participant)**: minimum notice period of **1 month**.
- **Governmental organisations (and government-delegated organisations per the rule above)**: minimum notice period of **1 year**.

This differentiated approach mirrors established practice in comparable international consortia: EUROPEUM-EDIC (the EU's permissioned-DLT consortium of member states, cited as a direct reference model in the evaluation) requires governmental members to give **12 months' written notice**, with no withdrawal permitted in the first three years; shorter-lived or less formal consortium arrangements typically use notice periods in the 30-day to few-months range.

**Withdrawal steps:**
1. Withdrawing organisation gives notice per the applicable minimum lead time above.
2. Remaining organisations update channel configuration to remove the departing org's MSP, orderer nodes, and peers.
3. **The departing organisation's representative simultaneously exits the operating association** — network participation and association membership are coupled in both directions (Section 6.3).
4. Endorsement policy is re-evaluated and adjusted per Section 4.5.
5. Departing org's historical transactions remain immutably in the ledger (per RWP #25 comment); only future write/endorsement rights are removed.
6. If the departing org was a fallback accountable party (e.g. TWS, per Section 6.1), accountability is explicitly reassigned before withdrawal takes effect.

This procedure applies uniformly regardless of whether the joining/leaving party is a pilot pseudo-organisation or a real governmental authority, with notice periods differentiated as above.

### 6.3 Operating Association (Swiss Verein) — Transitional Model

**Decision (adopted)**: TWS, MC, and NB found a **"RecordWeb Trust Association"** under Swiss law (Verein), chartered explicitly as a **transitional operating organisation** for the RootResolver network, satisfying the RWC #17 requirement for a named operating organisation from the start of the pilot. Institutional domain: **`recordweb.org`** (Section 3.6). Draft statutes have been prepared separately (see companion document "Statuten RecordWeb Trust Association").

The statutes encode the following transformation path, coupling association membership directly to operating a network organisation:

- **Membership is coupled to operation**: whoever stands up and operates an organisation participating in the RecordWeb RootResolver network automatically becomes a member of the association; there is no dual state of "runs a network org but isn't a member" or "is a member but runs no network org" — **except for the association's own bootstrap/discovery organisation** (Section 3.6), which is exempt from this coupling since it is an operational function of the association itself.
- **Withdrawal is coupled to ceasing operation**: an organisation that stops operating its network node (per the withdrawal procedure, Section 6.2) simultaneously exits the association.
- **Productive (`prod`) operation gating**: production operation of the network is only authorised once **no non-governmental organisation remains a member of the association** — i.e. the association's membership has fully transitioned to governmental/government-delegated organisations (per the eligibility rule in Section 6.2). Until then, the association (and the network) operates in test mode only, per Section 4.4.
- **Effect at Stage 4 (Section 7)**: once TWS, MC, and NB withdraw as their pseudo-organisations are superseded by real authorities, they automatically leave the association as a direct consequence of the membership-coupling rule above — no separate resignation process is needed beyond the standard withdrawal procedure. The association itself, including its bootstrap/discovery peer, continues operating unaffected by this transition.

This directly resolves the earlier open strategic question: the association is founded now, coordinates the pilot, and structurally dissolves its non-governmental character as a built-in consequence of its statutes, rather than requiring a later restructuring decision.

## 7. Rollout Plan

Staged rollout, starting with TWS alone so work can begin immediately:

1. **Stage 1 — TWS only**: TWS stands up its own CA, 2 orderers, and 2 peers under the `tws.rwrrn.recordweb.dev` naming scheme; single-org test network to validate chaincode logic and operational scripts (CA bootstrap, MSP generation, channel creation, chaincode deployment) end-to-end. Association founding (Section 6.3) and the association's own bootstrap/discovery organisation (`peer.recordweb.org`, Section 3.6) can be set up in parallel or immediately after.
2. **Stage 2 — +MC, +NB**: MC and NB each stand up their identical node set (under `mc.rwrrn.recordweb.dev` / `nb.rwrrn.recordweb.dev`) and join the association per Section 6.2; network is extended to 3 organisations plus the association's anchor peer; `test` and `prod` channels are created with all three orgs as members; endorsement policy `OutOf(2, TWS, MC, NB)` is activated; multi-org endorsement is validated on `test`.
3. **Stage 3 — +Authorities**: real governmental organisations (or government-delegated organisations, e.g. DVS or eCH for Switzerland — see Section 6.2) begin onboarding via the standard admission procedure, typically under their own governmental domain (e.g. `rwrrn.admin.ch`), discoverable via the association's stable `peer.recordweb.org` anchor peer, and joining the association as they join the network; they may begin writing to `prod` immediately per the rule in Section 4.4, while TWS/MC/NB continue operating `test`.
4. **Stage 4 — −TWS, −MC, −NB**: once no non-governmental organisation remains and the association's membership has fully transitioned to governmental/government-delegated organisations, TWS, MC, and NB withdraw via the standard withdrawal procedure (1-month notice, Section 6.2), automatically exiting the association per Section 6.3. This marks the completion of the test/pilot phase (see Section 7.1) and unlocks production (`prod`) operation. The association's own bootstrap/discovery organisation continues unaffected, as it was never coupled to pilot membership.

### 7.1 Test-Phase Completion Criterion

The test phase is considered complete when both of the following hold simultaneously:

- No non-governmental organisation still participates as a network operator or as an association member (i.e. all of TWS, MC, NB — and any other non-authority pilot participants — have withdrawn per Section 6.2), and
- The operating association (per RWC #17, Section 6.3) is composed entirely of governmental/government-delegated organisations and has taken over coordination of the network.

This criterion is adopted directly from the evaluation's conclusion and governs the transition out of Stage 4, and the unlock of production operation per Section 6.3.

## 8. Open Questions Tracker

Only infrastructure-dependent items remain open; all governance and technical design questions have been resolved for now.

| # | Question | Owner | Status |
|---|----------|-------|--------|
| 1 | MC infrastructure availability and type | Melvin Carvalho | Parked (not pursued for now) |
| 2 | NB infrastructure availability and type | Nicolas Bürkler | Parked (not pursued for now) |
| 3 | Where/how will the association's `peer.recordweb.org` CA + peer actually be hosted (e.g. on the TWS VPS initially, or separately)? | TWS (lead) | Open |

## 9. Changelog

- 2026-09-02: Initial draft created, based on RWC #17, RWP #23, #25, #26.
- 2026-09-02: Added node layout, Infomaniak VPS Lite tier table, test/prod channel separation, endorsement policy 2-of-3, identity issuance and key custody recommendations, governance framework positioning, standard admission/withdrawal procedure, Swiss association open question, staged rollout plan, test-phase completion criterion.
- 2026-09-02: Confirmed TWS VPS Lite tier 1 (1 vCPU/2GB/20GB) and flagged capacity risk; adopted 2 orderers/org (6 total); adopted LevelDB for pilot; adopted decision-making rule (simple majority, TWS veto during test phase, majority-only post-transition); adopted the Swiss association as transitional operating organisation with membership coupled 1:1 to network-organisation operation, gating production operation on full governmental membership; updated admission/withdrawal procedure and rollout plan accordingly.
- 2026-09-02: Confirmed TWS capacity via existing test-network operation on the same VPS; confirmed Ubuntu as OS; parked MC/NB infrastructure questions; confirmed Go as chaincode language (matches existing `root-resolver-testnet` implementation); left key-custody tooling unspecified (secure storage required, no tool mandated); adopted differentiated withdrawal notice periods (1 month pilot orgs / 1 year governmental orgs, aligned with EUROPEUM-EDIC precedent); adopted post-test-phase decision rule as plain simple majority; defined carrier-organisation eligibility rule and validated it against DVS (qualifies) and Verein eCH (does not qualify, due to non-governmental membership).
- 2026-09-02: Simplified admission eligibility rule to "government itself, or an organisation delegated by that government" (both DVS and eCH now qualify for Switzerland, subject to formal delegation); finalised decision-making rule (test: majority + TWS veto; operating phase: plain majority); adopted chaincode approach as "carry over design, productise implementation" from the existing `root-resolver-testnet` code; added namespace-registration-authority rule for the test phase (self-service) plus three labelled options with a recommendation for the operating phase (self-service / peer-reviewed / formal approval — peer-reviewed recommended); added full domain and node naming concept under `rwrrn.recordweb.dev`, based on `recordweb.dev`, using `<node>.<org>.rwrrn.recordweb.dev` with org codes for TWS/MC/NB and ISO 3166-1 alpha-2 country codes for future authority organisations; closed all governance/technical open questions except MC and NB infrastructure (parked).
- 2026-09-02: Adopted "RecordWeb Trust Association" as the association's working name (see companion Statuten document) with institutional domain `recordweb.org`, distinct from the technical `recordweb.dev`; adopted the association operating its own minimal Fabric organisation (1 CA + 1 non-endorsing peer at `peer.recordweb.org`) as a stable, world-known anchor peer for cross-organisation discovery, exempted from the membership-coupling rule since it is an association function rather than a separate member; clarified that country organisations (Stage 3) are expected to use their own governmental domains (e.g. `rwrrn.admin.ch`) rather than `recordweb.dev`, with the association's anchor peer serving as the shared discovery point regardless of domain; flagged Fabric's technical limitation that any joining peer holds a full ledger copy (acceptable here given the registry's non-sensitive data model per RWP #25); added open question on hosting location for the association's own CA/peer.
