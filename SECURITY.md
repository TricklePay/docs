# Security Policy

This document describes the security properties TricklePay aims to provide, the
trust boundaries between its components, and how to report a vulnerability.

It is a companion to [THREAT_MODEL.md](THREAT_MODEL.md), which enumerates the
specific actors and attacks considered.

## Reporting a vulnerability

If you believe you have found a security vulnerability, please report it
privately. Do not open a public issue, post it in a discussion, or disclose it on
social media before it has been addressed.

Preferred channel:

- Use GitHub's private vulnerability reporting on the affected repository
  (the "Report a vulnerability" button under the Security tab). This opens a
  private advisory visible only to the maintainers.

When reporting, please include:

- A clear description of the issue and the component it affects (contract,
  backend, or frontend).
- The steps to reproduce it, ideally with a minimal proof of concept. For the
  contract, a failing test or a pair of inputs is the most useful form.
- The impact you believe it has: what an attacker can achieve, and under what
  conditions.

What to expect:

- An acknowledgement that the report was received, as promptly as the maintainers
  are able.
- An assessment of severity and scope, and a discussion of remediation.
- Coordinated disclosure once a fix is available. Credit will be given to
  reporters who wish to be named.

Because this is an open-source project maintained on a volunteer basis, response
times are best-effort. Reports affecting funds in the contract are treated with
the highest priority.

## Scope

The security-critical component is the **contract**. It is the only component
that holds funds or enforces rules. Vulnerabilities in the contract that could
lead to loss, theft, freezing, or incorrect accounting of funds are the most
serious and are always in scope.

The **backend** and **frontend** are in scope for issues that could mislead users
or expose them to harm, such as displaying incorrect balances that cause a user
to make a decision they otherwise would not, or a cross-site scripting flaw in
the client. Because neither component holds keys or funds, the blast radius of a
flaw in them is bounded.

Out of scope:

- Vulnerabilities in third-party dependencies should be reported to those
  projects, though we are glad to be told so we can update.
- The security of the user's own wallet, browser, operating system, and device.
- The availability or correctness of public Soroban RPC endpoints and the Stellar
  network itself.
- Denial-of-service against a self-hosted backend instance, which is the
  operator's responsibility to defend.

## Security properties

The contract is designed to provide the following properties. They are described
in plain terms here and enforced in code, with tests covering each.

### Custody and solvency

- The full amount of a stream is escrowed in the contract at creation. A
  recipient is therefore always guaranteed that the funds they are owed exist;
  they do not depend on the sender remaining funded.
- A recipient can never withdraw more than the stream's total amount. Integer
  division rounds down, so accrued amounts can never exceed the escrowed total.

### Authorization

- Only the sender can create a stream from their own balance, and creation
  requires their wallet authorization, which also authorizes the token transfer
  into the contract.
- Only the recipient can withdraw from a stream.
- Only the sender can cancel a stream.
- Read-only views require no authorization and cannot change state.

### Correct accounting

- The amount withdrawable at any time is exactly the linearly vested amount minus
  what has already been withdrawn, never negative.
- Cancellation splits funds exactly: the recipient retains everything vested up to
  the cancellation moment, and the sender is refunded the rest. The two parts sum
  to the amount that was escrowed.
- A cancelled stream cannot be cancelled again, and its already-vested portion
  remains withdrawable by the recipient.

### Resistance to re-entrancy

- The contract updates its own state before making any external token transfer.
  A malicious or buggy token contract cannot re-enter a withdrawal or
  cancellation to extract more than it should.

## Trust boundaries

- **User to contract.** The user trusts the contract's deployed bytecode. They
  can verify it by building the contract from source and comparing the resulting
  WASM hash to the deployed contract.
- **User to frontend.** The user trusts the frontend to build the transaction it
  claims to. The wallet provides a check here: Freighter shows the transaction
  details before signing, so a user can confirm the contract, function, and
  arguments.
- **Frontend and backend.** The frontend trusts the backend only for display
  data. No funds move based on backend responses; every state change is a
  wallet-signed transaction validated by the contract. A compromised or incorrect
  backend can mislead a user but cannot move their funds.
- **Backend to chain.** The backend trusts the Soroban RPC endpoint it is
  configured with for reads. It holds no keys and signs nothing.

## Assumptions

The security properties hold under the following assumptions:

- The Stellar network and the Soroban runtime behave according to their
  specifications.
- The token being streamed is a well-behaved token contract. A token that lies
  about transfers or balances can break accounting for streams denominated in it;
  users should stream only tokens they trust.
- The user's wallet and device are not compromised. TricklePay cannot protect a
  user whose signing key is in an attacker's hands.
- Ledger timestamps are approximately accurate, as the vesting schedule is a
  function of ledger time.

## Versioning

Until a tagged 1.0 release, all components should be considered pre-release.
Security fixes are applied to the main branch of each repository. Anyone running
TricklePay is encouraged to track the latest commit on main.
