# Roadmap

This document describes where TricklePay is today and the direction it is headed.
It is a living document: priorities will shift as the project matures and as
contributors pick up work. Items are grouped by horizon rather than tied to firm
dates.

For concrete, ready-to-pick-up tasks, see the issues in each repository. This
roadmap is the higher-level picture those issues fit into.

## Current state

TricklePay has a working end-to-end MVP on testnet:

- A Soroban streaming contract that escrows funds and releases them linearly,
  with cliff support, full and partial withdrawal, cancellation, and a complete
  test suite.
- An indexer and read API that mirrors on-chain state into Postgres and serves it
  with live derived figures.
- A web client that connects a wallet, shows streams with balances that accrue in
  real time, and drives the create, withdraw, and cancel actions.
- Documentation covering the architecture, security policy, and threat model.

The project is pre-1.0 and unaudited. See [SECURITY.md](SECURITY.md) for the
audit status.

## Near term

Hardening and filling in the obvious gaps in the MVP.

- **Contract**
  - Property-based tests for the vesting and accounting logic.
- **Backend**
  - A stream history endpoint that returns the sequence of events for a stream.
  - Backoff and richer health reporting in the indexer.
- **Frontend**
  - Display token symbols and correct decimals instead of raw contract ids.
  - Clearer staged feedback during transaction signing, submission, and
    confirmation.
- **Project**
  - A deployment guide covering contract deployment and service configuration end
    to end.

## Medium term

Expanding what a stream can express and making the system easier to run.

- **Contract**
  - Additional release curves beyond linear, such as stepped or exponential
    vesting.
  - Topping up or extending an existing stream.
  - Transferring the right to receive a stream to a new recipient.
- **Backend**
  - Indexing more than one contract instance from a single service.
  - A push channel (for example websockets or server-sent events) so clients see
    updates without polling.
- **Frontend**
  - Search and richer filtering across streams.
  - Notifications when a stream becomes withdrawable or is cancelled.

## Longer term

The work required before TricklePay can responsibly custody real value at scale.

- **Security**
  - A formal third-party audit of the contract, with the report published and
    linked from the security policy.
  - A bug bounty program.
- **Mainnet**
  - A considered mainnet deployment with documented operational practices.
- **Ecosystem**
  - A small client library so other applications can integrate streams without
    reimplementing the transaction building and decoding.
  - Templates for common use cases such as payroll and vesting schedules.

## How priorities are set

Safety comes first. Work that reduces the risk to escrowed funds, or that is a
prerequisite for an audit, takes precedence over new features. Within that
constraint, the project favors changes that make the system easier to understand,
test, and run, since those compound over time. Community input through issues and
discussions shapes the ordering.
