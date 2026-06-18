# Architecture

This document describes how TricklePay is put together: the three components,
how data flows between them, the vesting model the whole system is built around,
and the design decisions that shaped it.

## Overview

TricklePay has three tiers. Each sits at a different trust level, and the
ordering matters: everything below a tier is authoritative for everything above
it.

```
        +-------------------------------+
        |   Frontend (Next.js client)   |   reads API, writes to chain
        +---------------+---------------+
                        |
          read path     |     write path
        (HTTP to API)   |   (RPC, wallet-signed)
                        |
   +--------------------+--------------------+
   |                                         |
   v                                         v
+-----------------------------+     +-----------------------+
|  Backend (indexer + API)    |     |   Soroban RPC node    |
|  mirrors chain into Postgres|     |                       |
+--------------+--------------+     +-----------+-----------+
               |                                |
        polls events                     submits txs
               |                                |
               v                                v
        +--------------------------------------------+
        |     Stream contract (Soroban, on-chain)    |
        |     holds funds, enforces the schedule     |
        +--------------------------------------------+
```

- The **contract** is the source of truth. It custodies tokens and enforces every
  rule. Nothing above it can move funds in a way the contract does not allow.
- The **backend** is a read-optimized mirror. It never holds keys or funds; it
  only observes the chain and answers queries. If it is wrong or offline, the
  contract is unaffected and clients can fall back to reading the chain directly.
- The **frontend** is a convenience. Reads go through the backend for speed;
  writes bypass the backend entirely and go straight to the chain, signed by the
  user's wallet.

This separation means the trust-critical surface is small. Only the contract
matters for safety; the other two tiers are about presentation and performance.

## The vesting model

Every component computes the same function, so it is worth stating precisely. A
stream has a total amount `T`, a start time `s`, an end time `e`, and a cliff
time `c`, with `s <= c <= e` and `s < e`. Times are Unix seconds. Amounts are
integers in the token's smallest unit.

The amount vested at time `t` is:

```
vested(t) =
    0                          if t < c  or  t < s
    T                          if t >= e
    T * (t - s) / (e - s)      otherwise   (integer division, rounding down)
```

The amount a recipient can withdraw is the vested amount minus what they have
already taken:

```
withdrawable(t) = max(0, vested(t) - withdrawn)
```

Two consequences worth noting:

- The cliff only gates *access*, not accrual. At the moment the cliff is reached,
  `vested` jumps to the linearly accrued amount for the time elapsed since the
  start. It does not restart the schedule.
- Integer division rounds down, so the recipient can never withdraw more than `T`
  in total, and rounding dust stays in the contract until the end, when `vested`
  becomes exactly `T`.

This same formula is implemented three times: in Rust in the contract, and in
TypeScript in both the backend and the frontend. The contract version is
authoritative; the other two exist so clients can display live figures without a
chain round-trip. Because all three use integer math with the same rounding, they
agree exactly.

## The contract

The contract is a single Soroban contract that manages a collection of streams.

### Storage

- A monotonic counter holds the id to assign to the next stream.
- Each stream is stored as a record keyed by its id, in persistent storage with
  a time-to-live that is extended on every access so active streams do not
  expire.

A stream record holds the sender, recipient, token, total amount, amount
withdrawn, start time, end time, cliff time, and a cancelled flag.

### Entry points

- `create_stream(sender, recipient, token, total, start, end, cliff) -> id`
  requires the sender's authorization, validates the parameters, pulls `total`
  tokens from the sender into the contract, stores the stream, and returns its
  id.
- `withdraw(id) -> amount` requires the recipient's authorization, computes the
  withdrawable amount, transfers it to the recipient, and records it.
- `cancel(id) -> refund` requires the sender's authorization, refunds the
  unvested remainder to the sender, and freezes the stream so the recipient can
  still withdraw the vested portion.
- Read-only views (`get_stream`, `withdrawable`, `vested`, `status`,
  `stream_count`) require no authorization and compute against the current ledger
  time.

### Cancellation

Cancellation freezes a stream rather than deleting it. The contract sets the
stream's total to the amount vested at the cancellation moment and its end time
to that moment, then marks it cancelled. After this, the vesting formula yields
the frozen amount for any later time, so the recipient can still withdraw their
accrued share through the normal `withdraw` path. The unvested remainder is
returned to the sender immediately.

### Events

The contract emits a typed event for each state change: `Created`, `Withdrawn`,
and `Cancelled`. Each event carries the affected parties as indexed topics so an
observer can filter by sender or recipient. These events are the backbone of the
indexer.

### Safety properties

- State is written before tokens are transferred, so a malicious token contract
  cannot re-enter and withdraw twice.
- The full stream amount is escrowed at creation, so a recipient is always
  guaranteed the funds exist for the life of the stream.
- Every privileged action checks the authorization of the specific account
  allowed to perform it.

See [SECURITY.md](SECURITY.md) and [THREAT_MODEL.md](THREAT_MODEL.md) for the
full treatment.

## The backend

The backend has two halves running in one process: an indexer that writes, and a
read API that reads.

### Indexer

The indexer polls the contract's events over Soroban RPC, starting from a saved
cursor (or a configured ledger, or the latest ledger on a fresh start). For each
event it learns which stream changed, then reads that stream's full authoritative
state with a `get_stream` simulation and upserts it into Postgres.

Reading full state rather than trusting event payloads is a deliberate choice.
The `Created` event does not carry the time fields, and the `Withdrawn` and
`Cancelled` events carry only deltas. By reading the complete stream after any
event, the mirror is always correct regardless of which event fired, and
re-processing an event is harmless. This makes the indexer idempotent: it can
crash and resume from its last saved cursor without corrupting data.

```
 RPC getEvents (from cursor)
        |
        v
 decode event -> (stream id, kind)
        |
        v
 get_stream(id) simulation -> full state
        |
        v
 upsert into Postgres
        |
        v
 save cursor
```

### Read API

The API reads only from Postgres. On every request it recomputes the vested and
withdrawable amounts with the vesting formula against the current clock, so the
figures it returns are live without a chain round-trip. It exposes a health
check, a filtered list of streams, and a single stream by id. Amounts are
returned as strings to preserve full 128-bit precision across JSON.

## The frontend

The frontend is a Next.js client with a clean split between reading and writing.

- **Read path**: stream lists and details are fetched from the backend API. A
  client-side hook recomputes the withdrawable balance every second using the
  same vesting formula, so an active stream's balance visibly climbs without
  polling.
- **Write path**: creating, withdrawing, and cancelling bypass the backend. The
  client builds the contract call, simulates and prepares it over RPC, asks the
  user's Freighter wallet to sign, submits the signed transaction, and polls
  until it is confirmed. The backend picks up the resulting event on its next
  poll and the UI re-fetches.

The frontend never holds a private key. Signing happens entirely inside the
wallet extension.

## Data flow by action

### Create

```
user fills form -> frontend builds create_stream call
   -> wallet signs -> RPC submits -> contract escrows funds, emits Created
   -> indexer reads full state -> Postgres updated
   -> frontend re-fetches -> stream appears in "outgoing"
```

### Withdraw

```
recipient clicks Withdraw -> frontend builds withdraw call
   -> wallet signs -> RPC submits -> contract transfers vested funds, emits Withdrawn
   -> indexer updates Postgres -> frontend re-fetches updated balance
```

### Cancel

```
sender clicks Cancel -> frontend builds cancel call
   -> wallet signs -> RPC submits -> contract refunds unvested, freezes stream, emits Cancelled
   -> indexer updates Postgres -> frontend re-fetches; recipient can still withdraw accrued share
```

## Design decisions

- **Escrow at creation.** The whole amount is locked when the stream is created,
  not drawn from the sender over time. This guarantees solvency: the recipient
  never depends on the sender remaining funded. The trade-off is that the sender
  must have the full amount available up front.
- **Pull-based withdrawal.** Recipients withdraw on their own initiative rather
  than being pushed funds. This keeps the contract simple, avoids unbounded loops,
  and lets recipients batch withdrawals to save fees.
- **Mirror, do not trust, the events.** The indexer treats events only as a
  signal that something changed and reads authoritative state from the chain.
  This trades a little extra RPC traffic for correctness and idempotency.
- **Three implementations of one formula.** Duplicating the vesting math in Rust
  and TypeScript is a maintenance cost, but it lets each tier compute live figures
  independently. Integer arithmetic with identical rounding keeps them in
  agreement.
- **Stateless, fundless backend.** Keeping keys and custody out of the backend
  shrinks the trust-critical surface to the contract alone.
