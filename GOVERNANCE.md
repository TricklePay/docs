# Governance

This document describes how TricklePay is maintained: who can merge changes,
how decisions are made, how disagreements are resolved, and how deployment keys
are held. The last point is security-relevant for a project that custodies funds
and belongs beside the threat model.

## Roles

### Maintainer

Maintainers have write access to the repositories and are the only people who
can merge pull requests to `main`. They are collectively identified by the
GitHub team `@TricklePay/maintainers`, which is listed as the owner of every
file in every repository.

Current responsibilities:

- Review and merge pull requests.
- Triage issues and set priorities.
- Hold and rotate deployment keys (see [Deployment keys](#deployment-keys)).
- Make releases and coordinate cross-repository changes.
- Respond to security reports (see [SECURITY.md](SECURITY.md)).

### Contributor

Anyone who opens an issue or pull request is a contributor. Contributors do not
have write access to any repository. The process for becoming a maintainer is
described below.

## Decision-making

Day-to-day decisions — merging a pull request, closing an issue, choosing between
two implementation approaches — are made by any maintainer acting alone, subject
to the merge rules below.

Decisions with broader impact require discussion and rough consensus among all
active maintainers before action is taken:

- Adding or removing a maintainer.
- Changing the deployment key custody arrangement.
- Any change to the on-chain contract that alters the vesting formula, the
  authorization rules, or the token transfer logic. These are consensus-level
  changes because they affect funds already locked in existing streams or the
  guarantees users rely on.
- Deprecating or archiving a repository.
- Changing this document.

For these decisions, the proposer opens an issue, describes the change and its
rationale, and waits for all active maintainers to respond. Silence for seven
days from a maintainer who has been notified counts as no objection. If there is
an objection that cannot be resolved by discussion, the decision is deferred
until consensus is reached or the objection is withdrawn.

There is no voting mechanism. The goal is consensus. If genuine consensus is
impossible, the project founder has a tie-breaking voice.

## Merge rules

- Every pull request to `main` must be reviewed and approved by at least one
  maintainer other than the author before it is merged.
- A maintainer may not merge their own pull request, even if they have approval
  from another maintainer, unless no other maintainer is available after a
  reasonable wait (seven days for non-urgent changes) and the change is clearly
  low-risk.
- Changes to the contract — any file under `tricklepay-contracts` — require
  approval from at least two maintainers. Contract changes affect funds and
  deserve extra scrutiny.
- CI must pass before any pull request is merged. No exceptions for "obvious"
  fixes; the checks are there precisely because obvious fixes sometimes are not.
- Force-pushes to `main` are not permitted. History on `main` is append-only.

## Becoming a maintainer

Maintainership is extended to contributors who have demonstrated consistent,
high-quality contributions over time and who are trusted to act in the interest
of the project and its users.

There is no formal quota or timeline. The typical path is:

1. Make several well-reviewed contributions across a meaningful period of time.
2. Show familiarity with the whole system, not just one component.
3. Be responsive and constructive during code review, both giving and receiving.
4. A current maintainer nominates you by opening an issue proposing the addition.
5. All active maintainers discuss and reach consensus. If consensus is reached,
   GitHub access is granted and the maintainer list is updated.

Maintainership can also be revoked by consensus of the remaining maintainers if
someone is consistently inactive, acts against the project's interests, or
requests to step down. A former maintainer's key access is removed promptly.

## Deployment keys

Deployment keys are the most security-sensitive operational detail in this
project because the contract custodies user funds. This section states what
exists, who holds it, and what controls are in place.

### What exists

- **Contract admin key.** A Stellar account that was used to deploy the Soroban
  contract to mainnet. On Soroban, a deployed contract does not have a privileged
  admin account in the protocol sense — the contract itself enforces all rules
  and no special account can bypass them. The deployer account is only relevant
  for the initial deployment transaction; it has no ongoing authority over
  existing streams or funds once the contract is live.
- **Testnet deployment key.** A separate key used for testnet deployments. Testnet
  funds have no real value; compromise of this key does not affect mainnet users.
- **Backend service credentials.** The backend requires a Soroban RPC endpoint
  URL and a Postgres connection string. These are operator-held configuration
  values, not keys that can move funds. The backend holds no Stellar signing key.

### Who holds keys

Deployment keys are held by the maintainer team. No single individual is the
sole holder of any key used in a mainnet context. At least two maintainers must
have access to each key so the project is not hostage to one person's
availability.

The current key holders are known to all active maintainers. That list is not
published here, because publishing it would be a targeting aid rather than a
security control. If you are a maintainer and do not know who holds a key, open
a private discussion with the team.

### Key hygiene

- Mainnet keys are stored in a password manager or hardware security module
  accessible only to maintainers.
- Keys are never committed to any repository, never embedded in CI configuration
  as plaintext, and never shared over unencrypted channels.
- Testnet keys are treated with the same hygiene even though their compromise
  carries no financial risk, because good habits should not depend on the
  stakes.
- If a key is believed to be compromised, the incident is treated as a security
  event. The response follows the same process as a vulnerability report: the
  team is notified privately, the key is rotated immediately, and the contract
  is redeployed if necessary. See [SECURITY.md](SECURITY.md) for the reporting
  channel.

### Key rotation

Keys should be rotated when a maintainer with key access leaves the team, or on
a regular schedule determined by the team. After rotation, any former maintainer
who held the old key is confirmed to no longer have access.

### Relationship to the threat model

The contract does not have a privileged operator account that can move funds
unilaterally. All fund movements require authorization from the sender or
recipient of each individual stream, as enforced by the contract's authorization
checks. A compromise of the deployer key after deployment therefore does not give
an attacker access to escrowed funds. This is described in detail in
[THREAT_MODEL.md](THREAT_MODEL.md).

The deployment key section here complements that analysis by stating the
operational controls: who holds keys, how they are stored, and what happens when
they need to change.

## Amendments

Changes to this document follow the same broad-impact decision process described
above: open an issue, allow time for all maintainers to respond, and reach
consensus before merging. The change must be reviewed by at least two
maintainers.
