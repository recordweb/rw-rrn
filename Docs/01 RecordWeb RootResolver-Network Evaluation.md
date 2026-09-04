## RecordWeb RootResolver-Networt (RWRRN) - Evaluationreport

## Management Summary

This report evaluates the fundamental solution options for the production-ready, global RecordWeb RootResolver network. It refers to the two functionally and technologically neutral requirements documents, [RWC #17](https://github.com/recordweb/rwc/issues/17) (Governance role of the operating organisation) and [RWP #24](https://github.com/recordweb/rwp/issues/24) (Namespace resolution model). The outcome of the evaluation: A **permissioned blockchain architecture** proves to be the most viable fundamental solution, as it is the only category to offer a structural, multi-party tamper-proof model for internationally shared write sovereignty. Within the permissioned blockchain category, a comparison of variants (Hyperledger Fabric, Hyperledger Indy, R3 Corda, permissioned Ethereum/Quorum-Besu) shows that **Hyperledger Fabric** offers the best fit for the global, consistent namespace state described in RWP #24. A concluding chapter evaluates the existing testnet `root-resolver-testnet` against this technology-neutral target vision.

## 1. Starting point: Technology-neutral requirements

### 1.1 RWC #17 – Governance role, independent of technology

[RWC #17](https://github.com/recordweb/rwc/issues/17) calls for a designated operating organisation for the shared RootResolver network, which is **not** the owner of all namespaces or the operator of all DID resolvers, but which coordinates the integrity, availability and interoperability of the shared infrastructure. The legal form is expressly dependent on implementation and jurisdiction; a non-profit association is mentioned only as one possible model, not as a requirement. The governance framework must, at a minimum, regulate the admission and withdrawal of participants, namespace registration and modification, role and authorisation management, change management, incident handling, auditability and continuity. None of these requirements presupposes a specific technology.

### 1.2 RWP #24 – Functional resolution model, independent of technology

[RWP #24](https://github.com/recordweb/rwp/issues/24) describes the RootResolver purely in functional terms as a distributed namespace directory: for a `did:rwp` namespace, it provides only routing information to the relevant DID resolver, but does not store any DID documents, records, record contents, access decisions or organisational directory data. A client must classify the namespace (global vs. local) and must not transmit local namespaces to the global network. A response must identify the namespace and provide the currently valid resolver endpoint; successful namespace resolution does not constitute proof of the DID’s existence or accessibility. This model is also technology-agnostic: it defines input/output and semantics, but not an implementation platform.

### 1.3 Derivation of the core requirements for the evaluation

Four technology-neutral core requirements can be derived from #17 and #24, which serve as an evaluation framework for all levels of this report:

- **Federated, shared write control**: Several independent organisations (potentially public authorities from different countries) must be able to jointly maintain namespace routing entries, without a central controlling authority, and without any single party being able to unilaterally alter the register.
- **Globally consistent read response**: Every requesting party must receive the same routing response for the same namespace at the same time.
- **Minimal data scope**: Only routing metadata (namespace, resolver endpoint); no content or access decisions.
- **Auditability and continuity**: The history of changes must be traceable; the network must be operable in the long term and capable of handling incidents.

In addition, the following framework conditions apply: international sponsorship by public authorities from several countries; national sovereignty regarding data protection and data security despite data exchange; no vendor lock-in; and federation as a central architectural principle.

## Level A: Policy decision on solution architecture

### 2.1 Option A1 – Custom development

A fully custom developed distributed registry (with its own consensus protocol and API layer) would remain a viable option if only the requirements from #17/#24 were used as the benchmark.

| SWOT | Custom development (category) |
|---|---|
| Strengths | Precisely tailored to the lean data model from RWP #24 (namespace only → resolver endpoint); no legacy issues from third-party platforms |
| Weaknesses | Multi-party consensus, protection against manipulation and audit history must be developed from scratch and hardened over several years, even though this is the core of the requirement in #17 |
| Opportunities | Conceivable as a very lean solution if the number of participants remains small in the long term |
| Risks | Lack of trust on the part of sovereign states in untested custom development; dependence on a single development team contradicts the requirement for vendor independence; security risk associated with custom consensus logic in critical infrastructure |

A bespoke solution would, in essence, have to replicate a tamper-proof, multi-party auditable transaction protocol anyway. For an international register critical to sovereignty, reinventing these mechanisms is neither time-efficient nor risk-efficient.


### 2.2 Option A2 – Existing software, not blockchain-based

These include established federated trust models outside the blockchain world: federated PKI models (cross-certification/mesh PKI, bridge CAs such as the US Federal Bridge Certification Authority), classic DNS-like delegation hierarchies, and decentralised naming systems such as the GNU Name System (GNS, RFC 9498).

**Federated PKI models (cross-certification, bridge CA)**: In the mesh model, independent root CAs cross-certify one another, thereby transferring trust between, for example, sovereign national PKIs without the need for a common root authority. The Bridge CA model (based on the US Federal Bridge Certification Authority) reduces the coordination effort by having a non-hierarchical ‘bridge’ cross-certify all participating CAs with one another, without itself being a root CA. A Policy Authority (analogous to FPKIPA) manages the accreditation criteria and checks the comparability of members’ policies.

**DNS-like delegation hierarchies**: Traditional hierarchical name resolution with a root zone and delegated second-level zones is technically simple and extremely well-established, but is conceptually based on a central root authority.

**GNU Name System (GNS)**: A fully decentralised, censorship-resistant naming system without a central root zone, which resolves names cryptographically via a ‘petname’ system rather than through a global authority. GNS deliberately eliminates any central authority over names, but in doing so addresses a different trust issue (individual, user-centred naming) than a registry with institutionally authorised entries.

| SWOT | Existing non-blockchain software (PKI federation / DNS delegation / GNS) |
|---|---|
| Strengths | Federated PKI models (Mesh/Bridge) have been tried and tested for decades in the public sector (Federal PKI) and are explicitly designed for sovereign, independent organisations; lower operational complexity than blockchain |
| Weaknesses | PKI federation governs the transfer of trust between certification authorities, but there is no built-in multi-party consensus or endorsement model for the actual routing data entries; DNS delegation is based on a root authority, whilst GNS, in turn, does not provide for institutional authorisation of entries |
| Opportunities | The PKI mesh model could serve as a complement (identity and trust layer) alongside a registry solution, but not as a replacement for it |
| Risks | None of the three models, in its own right, provides a mechanism to prevent a single participating party from unauthorisedly modifying a routing entry – the key governance requirement from RWC #17; the DNS hierarchy contradicts the federation requirement of no single point of control |

### 2.3 Option A3 – Blockchain, non-permissioned (public/permissionless)

Public-chain approaches (Ethereum Mainnet, other permissionless networks) were also explored.

| SWOT | Public/permissionless blockchain (category) |
|---|---|
| Strengths | Maximum decentralisation; no operating organisation required for basic operations; high resistance to censorship |
| Weaknesses | No control over validators; unpredictable transaction costs; all registry changes publicly visible |
| Opportunities | High interoperability with the existing Web3 tooling landscape |
| Risks | Public visibility of all changes (including resolver endpoints of individual states) conflicts with national sovereignty and security requirements; no contractually identifiable operating party, no legally enforceable chain of liability – incompatible with the designated, accountable operating organisation required by RWC #17 |

For critical national infrastructure, a public, permissionless chain is virtually out of the question: there would be no way to contractually regulate eligibility to participate, data sovereignty or liability, which would contradict the sovereignty requirements of the mandate.

### 2.4 Option A4 – Permissioned blockchain

Permissioned DLT (Distributed Ledger Technology) platforms (Hyperledger Fabric, R3 Corda, permissioned Ethereum variants) are designed for consortia comprising known, contractually bound organisations.

| SWOT | Permissioned blockchain (category) |
|---|---|
| Strengths | Participants are known and contractually authorised; multi-party endorsement/consensus prevents unilateral changes and thus fulfils the core requirement from RWC #17 structurally rather than organisationally; an immutable transaction history directly fulfils the audit requirement; a globally consistent ledger state aligns exactly with the resolution model from RWP #24 (every party sees the same response) |
| Weaknesses | Higher operational overhead than pure directory services (CA infrastructure, consensus node clusters, onboarding processes) |
| Opportunities | A real, tried-and-tested model for consortia of states already exists (the EU’s EBSI/Europeum-EDIC, a permissioned DLT consortium with decentralised node responsibility among member states and a coordinating EU legal entity that does not own the data) – a direct structural model for the operator role described in RWC #17 |
| Risks | Coordination efforts increase with the number of participants; governance must be clearly defined at an early stage, otherwise there is a risk of deadlock in majority decisions |

### 2.5 Decision Level A

A comparison with the purely functional requirements from #17 and #24 paints a clear picture: developing a bespoke solution would amount to unnecessarily reinventing the wheel for problems that have already been solved; Non-blockchain federation models (PKI mesh, DNS, GNS) solve related but distinct trust issues and offer no built-in protection against unilateral registry alterations; public blockchains contradict the requirements for sovereignty and accountability.

**Decision Level A: Permissioned blockchain.** This decision follows from the functional requirements of #17/#24.

## 3. Level B: Decision on variants within the permissioned blockchain

### 3.1 Hyperledger Fabric

| SWOT | Hyperledger Fabric |
|---|---|
| Strengths | Apache 2.0 open source; modular channel architecture with Private Data Collections enables national data sovereignty whilst maintaining a globally consistent namespace state; highest privacy flexibility compared to other platforms; globally visible, consistent ledger state aligns directly with the resolution model from RWP #24 (each party receives the same routing response) |
| Weaknesses | Requires specialised operational expertise (CA, MSP, Orderer cluster, channel configuration) |
| Opportunities | EBSI serves as a direct real-world model for consortia of states using permissioned DLT |
| Risks | Without disciplined governance (endorsement majorities, node distribution), there is a concentration risk in the early stages |

### 3.2 Hyperledger Indy

Hyperledger Indy is a permissioned ledger platform developed specifically for decentralised identity, originally driven by the Sovrin Foundation, with write access restricted to authorised ‘endorsers’ under a network-specific governance framework.

| SWOT | Hyperledger Indy |
|---|---|
| Strengths | Designed from the ground up for DID/identity use cases, not adapted retrospectively; a publicly readable but write-protected ledger fits conceptually with the ‘publicly readable routing information, but authorised-write registry’ logic from RWP #24; an established pattern for “governed permissioned consortia” with clearly documented endorser authority rather than open participation |
| Weaknesses | Smaller active ecosystem and less general-purpose tooling than Fabric; originally tailored to credential/schema data models, less so to generic namespace routing; RBFT consensus is less widely tested in multi-sector registration scenarios than Fabric’s Raft/Kafka options |
| Opportunities | The governance model “network is governed by its own consortium under a published framework” aligns almost verbatim with the requirement from RWC #17 |
| Risks | Each independent network is operated by its own governance body (historically, e.g., the Sovrin Foundation) – the ‘principal capture surface’ (control risk posed by the governance body itself) is explicitly identified as a design risk in technical analyses |

### 3.3 R3 Corda

| SWOT | R3 Corda |
|---|---|
| Strengths | Very robust privacy model: transactions are visible only to the parties directly involved; no global state for all |
| Weaknesses | The lack of a globally uniform state is architecturally unfavourable for a namespace registry where all parties are expected to receive the same response to the same query (RWP #24); smaller ecosystem in the public sector registration context; lower practitioner rating in a direct platform comparison |
| Opportunities | Useful should confidential bilateral transactions between individual states become necessary in the future |
| Risks | Peer-to-peer visibility logic complicates simple ‘namespace → resolver endpoint’ resolution for all participants simultaneously |

### 3.4 Permissioned Ethereum (Quorum/Besu)

| SWOT | Permissioned Ethereum (Quorum/Besu) |
|---|---|
| Strengths | Large EVM developer ecosystem, compatible tooling |
| Weaknesses | Privacy features rated lower in a direct comparison than Fabric; role model (node authorisation, governance roles) less granular than Fabric’s MSP/channel concept |
| Opportunities | Of interest for future interoperability requirements with existing EVM-based identity/VC infrastructures |
| Risks | No established reference model for a consortium of states on this scale; EBSI itself does not use the Quorum/Besu core architecture as a key model |

### 3.5 Decision Level B

Corda is ruled out because its transaction-based, non-globally consistent state model conflicts with the requirement in RWP #24 that ‘all parties see the same routing response’. Permissioned Ethereum offers no demonstrable advantage over Fabric for this use case and has fewer relevant reference projects in the public sector. Indy is the closest alternative to Fabric in terms of functionality, as its governance model (“network under a published framework, authorised endorsers”) corresponds almost verbatim to the requirement in RWC #17; however, its weaker generic tooling ecosystem and data modelling, which is primarily tailored to credential/schema data, argue against selecting it for a pure namespace routing register.

**Decision Level B: Hyperledger Fabric**, with Hyperledger Indy as a documented alternative candidate that is very similar in terms of governance.

## 4. Level C: Basic governance structure (derived in a technology-neutral manner)

Irrespective of the specific platform, the following basic principles for the operating organisation can be derived from #17 and the reference models examined:

- **Coordination role without data ownership**: Analogous to the European Commission in the EBSI model, which expressly does not hold its own copy of the ledger and acts solely as a facilitator/funding body, and analogous to the US Federal PKI Policy Authority, which manages accreditation criteria but does not itself issue end-user certificates.
- **Separation of functions**: The RSSAC model for the DNS root server system distinguishes between five functions (Secretariat, Strategy/Policy, Accreditation/Exclusion, Performance Monitoring, Finance) – a technology-neutral modular framework that can be adopted independently of Fabric, Indy or any other platform.
- **Binding vs. advisory structure**: For years, the RSSAC model remained primarily advisory and was implemented only slowly; the EBSI/EDIC model, with its clearly binding membership structure, was adopted more quickly in operational practice. A binding, contractually enforceable structure is preferable for productive operation.

## 5. Summary: a technology-neutral decision-making cascade

| Level | Question | Decision | Justification based exclusively on #17/#24 |
|---|---|---|---|
| A | Custom development / Non-blockchain / Permissioned blockchain / Permissionless blockchain? | **Blockchain, permissioned** | The only category with built-in protection against unilateral manipulation in the case of federated write sovereignty (#17) and globally consistent read responses (#24) |
| B | Fabric / Indy / Corda / permissioned Ethereum? | **Hyperledger Fabric** (Indy as the closest alternative) | Globally consistent state best aligns with the resolution model from #24; governance flexibility (channels/private data) meets #17 requirements |
| C | Basic governance structure | Co-ordination organisation without data ownership, RSSAC-inspired separation of functions, binding membership based on the EBSI model | Directly derived from the role of the operator organisation described in #17 |

## 6. Evaluation of the existing testnet against the technology-neutral target vision

The `recordweb/root-resolver-testnet` repository implements Hyperledger Fabric 2.5 with a dedicated namespace registry chaincode and is explicitly declared as a learning environment, not for production use. The structure comprises network configuration (`configtx`, `docker-compose`), setup scripts for cryptographic material, channels and network startup, a chaincode folder containing the namespace registry implementation, as well as an admin app and a Recordfinder client. Two test organisations are defined – `RecordWebOrg` and `SwissGovOrg` – alongside a separate `OrdererOrg`.

Measured against the target architecture (Levels A–C) derived in a technology-neutral manner in this report, the test network already **correctly fulfils the fundamental architectural decision**: it is a permissioned blockchain with a multi-party structure, not a centralised database or a public chain, and the chaincode semantics (namespace as state key, resolver endpoint as value) corresponds exactly to the resolution model described in purely functional terms in RWP #24.

However, there are significant gaps compared with the fundamental governance principles derived in Level C, which are already identified in the testnet document `production-track-b.md`:

| Fundamental principle from Level C | Status in the test network | Gap |
|---|---|---|
| Federated write sovereignty without unilateral control | Only 2 organisations, simple endorsement policy | `MAJORITY` policy only envisaged “as soon as more than two organisations participate”; no genuine multi-state federation yet |
| Co-ordinating organisation without data ownership | Not implemented; testnet is purely technical, no accompanying governance body documented | Governance document (`docs/governance.md`) is only mentioned in the testnet as a future step, but does not yet exist |
| Binding accession process for new participants | Not formalised | The accession process (MSP material, channel update via `configtxlator`, majority signature) is outlined but not documented as a binding procedure |
| Auditability/continuity (from #17) | Test certificates via `cryptogen`; no monitoring; no backup strategy documented | For production operation, a genuine CA infrastructure, a distributed Raft orderer (≥3 nodes), monitoring (Prometheus/Grafana/Explorer) and disaster recovery procedures are missing |
| Data minimisation (from #24) | The chaincode contract appears to be limited to routing metadata (as can be inferred from the repository structure) | No visible deviation from the required data minimisation is apparent; this should be explicitly verified against #24 during the chaincode review |

**Conclusion on the test network**: The basic technological direction and the data model are already consistent with the target architecture derived independently here. The remaining path to production readiness is predominantly a **governance and operational hardening task** (genuine multi-party federation, formalised operator organisation, security and continuity measures), not a change in technology. The checklist documented within the test network itself (`production-track-b.md`) already provides a useful working basis for this.

---

