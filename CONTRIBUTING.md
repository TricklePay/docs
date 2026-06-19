# Contributing to TricklePay

Thank you for your interest in improving TricklePay. This guide explains how the
project is organized, how to set up each component, and what is expected of a
contribution before it is merged.

TricklePay is spread across four repositories. This document covers the
conventions common to all of them; each code repository also has its own README
with component-specific detail.

## Where to contribute

- **tricklepay-contracts** (Rust, Soroban): the streaming contract. Changes here
  affect funds and require the most care and the strongest tests.
- **tricklepay-backend** (TypeScript): the indexer and read API.
- **tricklepay-frontend** (TypeScript, Next.js): the web client.
- **tricklepay-docs** (Markdown): this documentation hub.

If you are not sure where a change belongs, or you are planning a large change,
open an issue first so the approach can be agreed before you invest time. Small,
focused changes are easier to review and land faster than large ones.

## Prerequisites

Depending on which component you work on, you will need:

- **Rust**, a recent stable toolchain with the `wasm32-unknown-unknown` target,
  for the contract. Install it with [rustup](https://rustup.rs). The exact
  versions are pinned in the contract repository.
- **Node.js**, version 20 or newer, for the backend and frontend.
- **Docker**, for running Postgres locally for the backend.
- **The [Freighter](https://www.freighter.app) browser extension**, for using the
  frontend.
- **The [Stellar CLI](https://developers.stellar.org/docs/tools/cli)**, for
  deploying and interacting with the contract directly.

## Setup and common commands

### Contract

```bash
git clone <tricklepay-contracts>
cd tricklepay-contracts
cargo test                      # build and run the full test suite
cargo build --release --target wasm32-unknown-unknown   # produce deployable WASM
```

Before opening a pull request, make sure all of the following pass:

```bash
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
```

### Backend

```bash
git clone <tricklepay-backend>
cd tricklepay-backend
cp .env.example .env            # then set STREAM_CONTRACT_ID
npm install
./scripts/dev.sh                # starts Postgres, syncs the schema, runs with reload
```

Before opening a pull request:

```bash
npm run typecheck
npm run build
```

### Frontend

```bash
git clone <tricklepay-frontend>
cd tricklepay-frontend
cp .env.example .env.local      # then set the API URL and contract id
npm install
npm run dev
```

Before opening a pull request:

```bash
npm run typecheck
npm run build
```

## Coding standards

### Rust (contract)

- Format with `cargo fmt` and keep `cargo clippy` clean. Resolve warnings rather
  than silencing them, unless there is a clear and documented reason.
- Every behavior change comes with a test. For a new rule or branch, add a test
  that fails before the change and passes after it.
- Keep the vesting and accounting logic in pure functions where possible, so it
  can be tested without an environment.
- Match the style of the surrounding code: short doc comments on public items,
  functions focused on one task, and descriptive names over abbreviations.

### TypeScript (backend and frontend)

- The type checker must pass with no errors, and the project must build.
- Prefer explicit, descriptive types at module boundaries. Keep amounts as
  `bigint` or precise strings; never route token amounts through a floating-point
  number.
- Keep modules focused: configuration, data access, chain interaction, and
  presentation each live in their own place, following the existing structure.

### Keeping the vesting math in agreement

The vesting formula is implemented in the contract, the backend, and the
frontend. If you change it in one place, you must change it in all three and keep
them in exact agreement, including integer rounding behavior. A change to the
formula in the contract is a consensus-level change and should be discussed before
implementation.

## Commit and pull request process

1. Create a branch from `main` for your work.
2. Keep commits focused, and write commit messages that explain why the change is
   needed, not only what changed.
3. Make sure the relevant checks for the component all pass locally before
   pushing.
4. Open a pull request that describes the change, the motivation, and how you
   verified it. Link any related issue.
5. Be responsive to review feedback. Small follow-up commits during review are
   fine; they can be squashed on merge.

For a change that touches more than one repository, for example a contract change
that the backend and frontend need to follow, describe the coordination in each
pull request and link them together so reviewers can see the whole picture.

## Reporting bugs

A good bug report includes what you did, what you expected, and what actually
happened, with enough detail to reproduce it. For the contract, a failing test or
a minimal pair of inputs is the most useful form. For the backend or frontend,
the exact request or steps and the observed output help most.

For security issues, do not open a public issue. Follow the process in
[SECURITY.md](SECURITY.md) instead.

## Code of conduct

Be respectful and constructive in all project spaces. Assume good intent, give
specific and actionable feedback, and keep discussion focused on the work. The
goal is a welcoming project for contributors of every experience level.
