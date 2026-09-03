# How to Join the RWRRN Test Channel (`root-resolver-test`)

Audience: a new organisation (e.g. MC, NB) that wants to join the existing
SmartBFT application channel operated by TWS on the RecordWeb RootResolver
Network. This document assumes you have already read
`Config-and-Progress.md` (especially the Decision Log and Stage 1 Step 2
section) and understand the current network topology.

Status: DRAFT — first version, written immediately after TWS completed its
own Stage 1 Step 2 bootstrap (2026-09-03). Not yet exercised end-to-end by a
second organisation. Expect to refine this after the first real join.

---

## 0. Before you start: what you get vs. what you decide

If you clone `recordweb/rwrrn` and adapt `.env` + `docker-compose.yml`
exactly like TWS did, you get **your own isolated single-org test network**
— your own CA, your own orderers, your own peers, all talking only to each
other. That is NOT the same as joining TWS's existing channel. Cloning the
repo gives you the *tooling and patterns*, not membership in the network.

**To actually join the existing `root-resolver-test` channel, you need:**

1. Your own Fabric CA and your own crypto material (same bootstrap process
   as TWS — scripts 01-05), because RWRRN's principle is "every
   organisation runs its own CA and issues its own identities" (see
   Decision D1 in `Config-and-Progress.md`).
2. Your own orderer node(s) reachable from TWS's orderers over the public
   network (DNS + open firewall ports — same pattern as TWS's Step 1.1-1.3).
3. Coordination with TWS (or whoever administers the channel at the time)
   to perform a **channel configuration update** that adds your
   organisation's MSP, orderer endpoints, and consenter certificates to the
   *existing* channel config — this is a governance/coordination step, not
   something you can do unilaterally from your own repo clone.
4. At least one peer that joins the channel using the *updated* channel
   config block (not TWS's original genesis block).

**What you decide, and should discuss with TWS/the group before starting:**

- Your MSP names (`<YourOrg>OrgMSP` for peers, `<YourOrg>OrdererMSP` for
  orderers — see Decision D1's "Model B" convention).
- Your hostnames and port scheme (you may reuse TWS's flat +100-offset
  convention from Step 1.2, or pick your own internally-consistent scheme
  — it does not need to match TWS's numbers, only your own DNS/firewall
  need to agree with it).
- **How many orderers you stand up** — see Section 1 below, this is not a
  free choice without consequences for the whole channel's fault tolerance.

---

## 1. Orderer count: why "just 2" changes the channel's fault tolerance for everyone

SmartBFT's fault-tolerance formula is `f = floor((N-1)/3)`, where `N` is
the **total number of consenters in the channel's `ConsenterMapping`**,
summed across **all** organisations — not per organisation. This is
confirmed directly in Fabric's own configuration example (`bft_configuration.html`),
which shows exactly this shape: 4 consenters, 4 different orderer MSPs
(`OrdererOrg1`-`OrdererOrg4`), i.e. one orderer per organisation, not one
organisation running all 4.

Concretely, if you join with **2** orderers alongside TWS's existing 4:

| Total consenters (N) | `f` (tolerated faulty nodes) |
|---|---|
| 4 (TWS only, current state) | 1 |
| 6 (TWS's 4 + your 2) | 1 (`floor(5/3) = 1`) |
| 7 (TWS's 4 + your 3) | 2 (`floor(6/3) = 2`) |
| 8 (TWS's 4 + your 4) | 2 (`floor(7/3) = 2`) |

**Joining with 2 orderers is technically valid and does not break anything
— the channel keeps its current fault tolerance of `f=1`.** It simply does
not *improve* it. If the goal (see Decision D3/D4 in `Config-and-Progress.md`)
is to increase the network's resilience as more organisations join, 2
orderers alone won't move that needle — you'd need the *next* full jump to
7 total consenters (e.g. a 3rd orderer somewhere) before `f` increases.

This is not a blocker — 2 orderers per new org is a legitimate, lighter-weight
choice, especially for a first test join. Just go in with the same
expectation TWS had for Stage 1 (see Decision D4's rationale): don't expect
BFT fault tolerance to improve just because node count grew, unless the
total crosses one of the `3f+1` thresholds above. Confirm with the group
whether 2 is acceptable for your organisation's role, or whether 4 (matching
TWS) is preferred — this is the open item already flagged in
`Config-and-Progress.md`'s Stage 3 section.

---

## 2. Step-by-step: what your organisation actually does

### Step A — Stand up your own organisation's infrastructure (isolated, no channel yet)

This is identical in spirit to what TWS did in Stage 1 Steps 1.1-1.4, adapted
to your own hostnames/ports/org name:

1. DNS records for your CA + orderer(s) + peer(s), same "grey cloud / DNS
   only" requirement as TWS's Step 1.1 (Fabric needs direct gRPC/mTLS, not
   an HTTP(S) proxy).
2. Firewall ports open for your chosen scheme (Step 1.2/1.3 pattern).
3. Clone `recordweb/rwrrn`, adapt `docker-compose.yml` (your hostnames, your
   MSP IDs, your orderer count) and `.env` (copy from `.env.template`, fill
   in your own real secrets — never commit `.env`).
4. Run bootstrap scripts 01 → 02 → 03 → 04 → 05, in that order, exactly as
   documented in `Config-and-Progress.md`'s script reference table — this
   produces your own CA-issued crypto material, including the org-level
   `msp/cacerts/` + `msp/tlscacerts/` that Step 05 exists specifically to
   fix (see Stage 1 Step 2's "Bugs encountered" section for why both
   directories matter and what breaks if either is missing).
5. Run script 06 (bootstrap admin rotation) once your named org admins are
   confirmed working — same rationale as TWS's own rotation.
6. Verify your own orderer(s)/peer(s) start cleanly, in isolation, with
   `docker compose logs <service>` — **before** attempting to touch the
   shared channel. Any TLS/MSP problem is far easier to diagnose in
   isolation than after joining a live multi-org channel.

At the end of Step A, you have a working, isolated Fabric organisation —
but it is not yet part of `root-resolver-test`.

### Step B — Exchange the material needed for the channel config update

To be added to the channel, TWS (or whoever holds channel-admin rights at
the time) needs from you:

- Your orderer organisation's MSP definition: MSP ID, org-level
  `msp/cacerts/*.pem`, org-level `msp/tlscacerts/*.pem`, org-level
  `msp/admincerts/*.pem`, and `msp/config.yaml` (NodeOUs) — i.e. the exact
  same four artefacts TWS's own `05-provision-org-msp-cacerts.sh` +
  `04-copy-admincerts-to-nodes.sh` produce for `TWSOrdererMSP`.
- Your peer organisation's MSP definition — same four artefacts, for your
  `<YourOrg>OrgMSP`.
- For **each** orderer node you're adding: its enrollment certificate
  (`msp/signcerts/cert.pem`) and its TLS certificate (`tls/server.crt`) —
  these become the `Identity`/`ClientTLSCert`/`ServerTLSCert` values in the
  new `ConsenterMapping` entries (see `configtx.yaml`'s existing
  `ConsenterMapping` for the exact shape — yours will be appended, not
  replace TWS's four).
- Your orderer endpoints (`host:port` for each orderer) and your anchor
  peer (`host:port` for at least one peer), for the `OrdererEndpoints` /
  `AnchorPeers` fields.

This exchange happens **outside git** (secure channel, not a public repo
commit) for anything containing private keys — only the four MSP artefacts
above (all public certificates) and the endpoint list need to be shared;
never share `msp/keystore/` or `tls/server.key` from any node.

### Step C — Channel configuration update (performed by/with the existing channel admin)

This is the part that is genuinely a coordination step, not a script you
run alone. At a high level (full command sequence to be filled in once
TWS/the group performs the first real one):

1. Fetch the current channel config (`peer channel fetch config`, same
   command already used and verified in Stage 1 Step 2).
2. Decode it with `configtxlator`, edit the JSON to add: your orderer org
   to `Channel.Groups.Orderer.Groups`, your peer org to
   `Channel.Groups.Application.Groups`, and your orderer(s) to
   `Channel.Groups.Orderer.Values.ConsenterMapping`.
3. Re-encode, compute the config update delta (`configtxlator compute_update`),
   have it signed by the required signatories (per the channel's current
   `Admins` policy — currently `MAJORITY Admins`, i.e. TWS alone can sign
   today since TWS is the only org, but this may require multi-org
   signatures once MC/NB are also members), and submit it via
   `peer channel update`.
4. Wait for your new orderer(s) to onboard as "followers" (per the official
   BFT reconfiguration doc: a newly added node starts as a follower,
   replicating blocks, before being promoted to the active consenter set —
   check status via `osnadmin channel join` against your own new orderer,
   which should show `"status": "onboarding"` before flipping to `"active"`).
5. Add your new orderer(s) to the consenter set itself (a second config
   update, per the same reconfiguration doc) once onboarding is confirmed
   complete.

**This document intentionally does not script Step C.** Unlike CA bootstrap
(always the same 6 mechanical steps, safe to automate), a channel
config update is a one-time, negotiated, security-sensitive operation whose
exact JSON diff depends on who is joining, with what identity, at what
point in the channel's history. Scripting it prematurely risks encoding
assumptions (org count, specific MSP names, specific certificate paths)
that won't hold for the next org after you. Treat Step C as "read the
official BFT reconfiguration doc together with TWS, on a call or in a
shared session, at the time you actually join" rather than "run this
script."

### Step D — Your peer(s) join

Once Step C's config update is committed to the channel, your own peer(s)
join using the **updated** config block (fetched fresh after the update,
not TWS's original genesis block):

```bash
peer channel fetch newest channel-artifacts/root-resolver-test_latest.block \
  -c root-resolver-test \
  -o <a-reachable-orderer-host>:<port> \
  --tls --cafile <absolute-path-to-that-orderer-tls-ca.crt>

peer channel join -b channel-artifacts/root-resolver-test_latest.block
```

Use **absolute paths** for any `--cafile`/`--client-cert`/`--client-key`
argument if you override the `cli` container's default `CORE_PEER_*`
target (see Stage 1 Step 2's last "Bugs encountered" entry — relative paths
silently resolve against the wrong base directory for any peer other than
the `cli` container's built-in default).

---

## 3. Quick verification commands (adapt hostnames/paths to your own org)

Once you believe you've joined, these are the same checks TWS used to
verify its own join (see Stage 1 Step 2):

```bash
# Confirm your peer sees the channel and its current height
peer channel list
peer channel getinfo -c root-resolver-test

# Confirm your org's AnchorPeer is correctly reflected in the live config
peer channel fetch config channel-artifacts/root-resolver-test_config.pb \
  -c root-resolver-test \
  -o <orderer-host>:<port> \
  --tls --cafile <absolute-path-to-orderer-tls-ca.crt>
configtxlator proto_decode --input channel-artifacts/root-resolver-test_config.pb \
  --type common.Block --output channel-artifacts/root-resolver-test_config.json
grep -A15 "AnchorPeers" channel-artifacts/root-resolver-test_config.json

# Confirm your orderer(s) are visible in the consenter set and cluster-healthy
docker compose logs <your-orderer-service> --tail=30
# Look for: no "server root CA cert is nil" / "tls: bad certificate" warnings,
# subchannel connections to ALL other consenters (not just TWS's) READY.
```

---

## 4. Open questions to resolve before the first real join (carry these to the group)

- Orderer count for the joining org: 2 (lighter) vs. 4 (matches TWS,
  meaningfully improves BFT fault tolerance once combined — see Section 1
  table) — this is the same open item already tracked in
  `Config-and-Progress.md`'s Stage 3 section.
- Who exactly signs the channel config update once more than one org
  exists (today: TWS alone, per `MAJORITY Admins`; this changes once a
  second org's `Admins` policy is part of the equation).
- Whether the anchor-peer / gossip topology needs any adjustment once a
  second organisation's peers are added (currently only TWS's `peer0` is
  an anchor peer).
