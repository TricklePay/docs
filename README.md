# TricklePay

TricklePay is a token streaming protocol on [Stellar](https://stellar.org),
built on [Soroban](https://soroban.stellar.org) smart contracts. It lets a
sender lock a sum of tokens and release them to a recipient continuously over
time, rather than in a single lump sum.

This repository is the documentation hub for the project. The code lives in
three separate repositories, described below.

## Why streaming payments

Most payments are discrete: an amount moves from one party to another at a single
moment. But a great deal of real economic activity is continuous. Salaries earn
by the hour, grants pay out over a quarter, subscriptions accrue by the day, and
token allocations vest over years. Representing these as a single transfer forces
an awkward choice between paying everything up front (and trusting the recipient)
or paying at the end (and asking the recipient to extend credit).

A stream removes that trade-off. Funds are locked once, then become withdrawable
gradually as time passes. The recipient can take what has accrued at any moment;
the sender can stop the stream and reclaim only what has not yet accrued. Neither
party has to trust the other to behave, because the contract enforces the
schedule.

Common uses:

- **Payroll and contracting**: salaries that accrue by the second.
- **Vesting**: team and investor token allocations with a cliff and linear
  release.
- **Grants**: milestone or time-based funding that can be paused if work stops.
- **Subscriptions**: continuous payment for ongoing access.

## How a stream works

A stream is defined by a total amount, a start time, an end time, and an optional
cliff:

- Before the start, nothing has vested.
- Between start and end, the vested amount grows linearly with elapsed time.
- At and after the end, the full amount has vested.
- A **cliff** is a time before which nothing can be withdrawn. When the cliff is
  reached, everything accrued since the start unlocks at once, and vesting
  continues linearly from there.

The recipient withdraws whatever has vested but not yet been taken. The sender
can cancel at any time: the recipient keeps everything vested so far, and the
unvested remainder is refunded to the sender.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the precise model and the system
design.

## Repositories

| Repository | Description |
| --- | --- |
| **tricklepay-contracts** | The Soroban streaming contract, in Rust. Holds funds and enforces the vesting schedule. The source of truth. |
| **tricklepay-backend** | An indexer and read API, in TypeScript. Mirrors on-chain stream state into Postgres and serves it over HTTP with live derived figures. |
| **tricklepay-frontend** | A web client, in Next.js. Connects a wallet, shows streams with live-accruing balances, and drives the create, withdraw, and cancel actions. |
| **tricklepay-docs** | This repository: architecture, security model, threat model, and contributor guides. |

The three code repositories are independent and can be developed and deployed
separately. The contract is the only component that holds funds or enforces
rules; the backend and frontend are conveniences built around it.

## Quickstart

Each repository has its own setup instructions in its README. End to end:

1. **Deploy the contract** (tricklepay-contracts) to testnet and note its
   contract id.
2. **Run the backend** (tricklepay-backend) pointed at that contract id; it will
   index events into Postgres and serve the read API.
3. **Run the frontend** (tricklepay-frontend) pointed at the backend API and the
   contract id; connect Freighter and start streaming.

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md): system design, data flow, and the vesting
  model.
- [SECURITY.md](SECURITY.md): security properties and how to report a
  vulnerability.
- [THREAT_MODEL.md](THREAT_MODEL.md): assets, actors, attack surface, and
  mitigations.
- [CONTRIBUTING.md](CONTRIBUTING.md): how to set up, build, and contribute across
  the repositories.

## License

MIT. Each repository carries its own copy of the license.
