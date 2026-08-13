---
title: Examples
---

# Examples

Three complete, runnable apps, each building on the last. They live in the
[eventium-hs/examples](https://github.com/eventium-hs/examples) repository.

| Example | Store | Concepts |
|---|---|---|
| **[Counter CLI](/examples/counter-cli.html)** | in-memory | events, projection, command handler — the four primitives, ~100 lines |
| **[Café](/examples/cafe.html)** | SQLite | single aggregate with a real lifecycle, typed errors, a polling read model across processes |
| **[Bank](/examples/bank.html)** | SQLite | full CQRS — multiple aggregates, a process manager with compensation, dual read models, event publishing |

A natural progression: start with **Counter** for the core primitives, move to
**Café** for persistence and subscriptions, then **Bank** for multi-aggregate
CQRS.

## Running them

The examples use Nix (with flakes) and direnv. Entering the directory
auto-loads the dev shell via `.envrc` (which runs `hpack` to generate the
`.cabal` files), so you get a fully pinned toolchain with no global installs.

```
git clone https://github.com/eventium-hs/examples
cd examples          # direnv loads the dev shell

cabal run counter-cli   # the counter REPL
```

Common `just` targets in the repo:

```
just build-local   # build against a sibling checkout of the library
just test          # run the test suites
just format        # ormolu
just lint          # hlint
```

The repo ships two project files: `cabal.project.dev` builds against a local
`../eventium` checkout (the day-to-day workflow), and `cabal.project` is the
self-contained git-based build.

## Reading them alongside the docs

Each walkthrough links back to the concept it demonstrates, so you can read the
guide and the code side by side:

- Counter → **[Projections](/docs/projections.html)**, **[Command Handlers](/docs/command-handlers.html)**
- Café → **[Read Models](/docs/read-models.html)**
- Bank → **[Process Managers](/docs/process-managers.html)**, **[Design & Internals](/docs/internals.html)**
