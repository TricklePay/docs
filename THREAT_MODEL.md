# Threat Model

This document enumerates the assets TricklePay protects, the actors who might try
to attack it, the attack surface of each component, and the mitigations in place.
It is intended to make the security reasoning explicit so that reviewers and
contributors can challenge it.

It complements [SECURITY.md](SECURITY.md), which states the policy and the
properties; this document is the analysis behind those properties.

## Assets

The things worth protecting, in rough order of importance:

1. **Escrowed funds.** Tokens locked in the contract for the life of a stream.
   Loss or theft of these is the worst outcome.
2. **Correct accounting.** The vested, withdrawn, and refundable amounts for every
   stream. If these are wrong, funds move incorrectly even if none are outright
   stolen.
3. **Authorization integrity.** The guarantee that only the sender can create or
   cancel, and only the recipient can withdraw.
4. **User decision integrity.** The information a user sees when deciding to sign.
   Misleading a user into signing a harmful transaction is an attack even if the
   contract behaves correctly.
5. **Availability of the read path.** The backend and frontend being up and
   accurate. This is the least critical asset, because the contract can be used
   without them.

## Actors

- **Honest sender** and **honest recipient.** The normal participants. The system
  must protect each from the other without requiring them to trust each other.
- **Malicious sender.** May try to reclaim funds the recipient has already earned,
  create streams that misbehave, or grief the recipient.
- **Malicious recipient.** May try to withdraw more than has vested, withdraw
  after cancellation beyond their share, or withdraw from streams that are not
  theirs.
- **Unrelated on-chain attacker.** Any third party who can submit transactions and
  call the contract, but is neither the sender nor recipient of a target stream.
- **Malicious token contract.** A token chosen for a stream that behaves
  adversarially, for example by attempting re-entrancy during a transfer.
- **Network-level attacker.** Someone positioned between a user and the services,
  for example on a hostile network or via a compromised RPC endpoint or backend.
- **Front-end compromise.** An attacker who can alter what the web client serves,
  through a supply-chain or hosting compromise.

## Trust boundaries

```
   user device / wallet        |  trusted by the user, holds keys
   ----------------------------+------------------------------------
   frontend (served code)      |  builds txs; cannot sign
   ----------------------------+------------------------------------
   backend (indexer + API)     |  read-only mirror; no keys, no funds
   ----------------------------+------------------------------------
   Soroban RPC node            |  relays reads and submissions
   ----------------------------+------------------------------------
   stream contract (on-chain)  |  authoritative; holds funds
```

Each line is a boundary where data crosses between components at different trust
levels. The most important property of the design is that crossing a boundary
upward (toward the user) can mislead but cannot move funds, because every fund
movement is a wallet-signed transaction validated by the contract at the bottom.

## Threats and mitigations

### Contract

**A malicious recipient withdraws more than has vested.**
Mitigation: the contract computes the withdrawable amount as the linearly vested
amount minus the amount already withdrawn, clamped at zero, against the current
ledger time. It transfers exactly that amount and records it. Withdrawals are
covered by tests for partial, full, and repeated cases.
Residual risk: none identified beyond the accuracy of ledger time.

**A malicious actor withdraws from a stream that is not theirs.**
Mitigation: `withdraw` requires the recipient's authorization, and `cancel`
requires the sender's. The contract checks the authorization of the specific
account recorded on the stream. Tests assert that the correct signer is required.
Residual risk: none beyond wallet key compromise, which is out of scope.

**A malicious sender reclaims funds the recipient has already earned.**
Mitigation: cancellation refunds only the unvested remainder. The vested portion
stays in the contract and remains withdrawable by the recipient. The split is
tested to sum exactly to the escrowed total.
Residual risk: none identified.

**A malicious token re-enters during a transfer to double-withdraw.**
Mitigation: the contract follows checks-effects-interactions. It updates the
stream's withdrawn amount and persists it before calling the token's transfer.
A re-entrant call sees the already-updated state and has nothing left to take.
Residual risk: a token that violates the standard interface in other ways can
still corrupt accounting for streams denominated in it; users should stream only
trusted tokens.

**Invalid or hostile parameters at creation.**
Mitigation: `create_stream` rejects a non-positive amount, a start that is not
before the end, and a cliff outside the start-to-end window, each with a specific
error, before any state is written or funds moved. Tested for each case.
Residual risk: none identified.

**Integer overflow in the vesting computation.**
Mitigation: the release build enables overflow checks, so an overflowing
computation traps rather than wrapping. Realistic token amounts and durations
stay far within the range of the 128-bit integer type used.
Residual risk: an extreme combination of a very large amount and a very long
duration could trap a computation; this would fail safe by reverting, not by
moving funds incorrectly.

**Stream data expiring from ledger state.**
Mitigation: stream records are stored with a time-to-live that is extended on
every read and write, keeping active streams alive.
Residual risk: a stream left completely untouched for a very long time could have
its state archived; it can be restored through the standard ledger restoration
mechanism.

### Backend

**A compromised or buggy backend serves incorrect balances.**
Mitigation: the backend cannot move funds; it only informs display. The frontend
recomputes balances client-side from stream parameters, and every state change is
validated by the contract regardless of what the backend reported. A user can
verify any figure against the chain.
Residual risk: a user could be misled into a decision, for example believing a
stream is larger than it is. The wallet's transaction preview is the backstop,
since the real parameters are visible at signing time.

**The indexer corrupts its mirror after a crash or a replayed event.**
Mitigation: the indexer reads full authoritative state from the contract after
any event and upserts it, which is idempotent. It persists its cursor so it
resumes exactly where it left off.
Residual risk: while the indexer is behind, the mirror is stale but not wrong;
it converges once caught up.

**A hostile RPC endpoint feeds the backend false data.**
Mitigation: the operator chooses the RPC endpoint and should use one they trust.
Reads from a hostile endpoint can only affect display, not funds.
Residual risk: an operator who points the backend at a hostile endpoint can serve
misleading data to their own users.

**Denial of service against the API.**
Mitigation: the list endpoint clamps its page size, and the API is stateless and
cheap to scale or rate-limit at the operator's edge.
Residual risk: a determined attacker can still exhaust a single unprotected
instance; defending availability is the operator's responsibility.

### Frontend

**A supply-chain or hosting compromise serves malicious client code.**
Mitigation: the wallet is the final authority. Freighter displays the contract,
function, and arguments of a transaction before the user signs, so a tampered
client cannot silently redirect funds without the change being visible at signing
time. The frontend never holds a key.
Residual risk: a user who does not read the wallet prompt could approve a
malicious transaction. User education and the wallet's preview are the
mitigations.

**Cross-site scripting or injected content in the client.**
Mitigation: the client is built with a framework that escapes rendered content by
default, and it renders only typed data from its own API.
Residual risk: a new flaw could be introduced; this is in scope for reports.

**A user connects to the wrong network.**
Mitigation: the client compares the wallet's network to its configured network
and warns on a mismatch.
Residual risk: a user can ignore the warning; the transaction would simply fail or
act on the wrong network's contract.

### Network and user environment

**Man-in-the-middle between the user and the services.**
Mitigation: services are expected to be served over TLS. Even without it, an
attacker on the path cannot forge a signature, so they cannot move funds; they can
only deny service or mislead display.
Residual risk: display-level deception, bounded by the wallet preview.

**Compromised user device or wallet.**
This is outside the system's control and outside its protection. An attacker with
the user's signing key can do anything the user can.

## Residual risk summary

The design concentrates all fund-moving authority in the contract and all signing
authority in the user's wallet. As a result, the dangerous residual risks reduce
to two categories:

1. **Trusting the wrong token.** Streams denominated in an adversarial token
   inherit that token's behavior. Users should stream only tokens they trust.
2. **Trusting the wrong transaction.** A user who approves a transaction without
   reading the wallet's preview can be harmed by a compromised client or network.
   The wallet preview is the last line of defense and should be read.

Everything else either cannot move funds (backend and frontend compromise,
network attacks) or is explicitly out of scope (wallet and device compromise).
