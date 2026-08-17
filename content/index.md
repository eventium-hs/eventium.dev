---
title: Event sourcing for Haskell
---

# Eventium

Composable, type-safe event sourcing and CQRS for Haskell — event stores with
optimistic concurrency, pure projections, command handlers, process managers,
event subscriptions, and pluggable storage backends (in-memory, SQLite,
PostgreSQL).

```
eventium-core      -- storage-agnostic core
eventium-sqlite    -- + a backend (or -memory / -postgresql)
```

[Get started →](/docs/getting-started.html) · [Docs](/docs/) · [Examples](/examples/) · [GitHub](https://github.com/eventium-hs/eventium)

## Why Eventium

- **Everything is a plain value.** Projections, command handlers, process
  managers, stores, and codecs are records you pass around — not typeclasses
  resolved by the compiler. They compose by function application.
- **Domain logic is pure.** Command handlers and process managers are ordinary
  functions — state and input in, values out. Test your whole domain with a list
  of events and an assertion. No database, no mocking.
- **The backend is a deployment decision.** The same domain code runs against an
  in-memory STM store in tests and PostgreSQL in production. Swap it at the
  application boundary.
- **Safety is in the types.** Optimistic concurrency, domain rejections,
  compensation logic, and schema evolution are all visible in the API rather
  than hidden behind defaults.

## Start reading

- **[Getting Started](/docs/getting-started.html)** — install and build a
  runnable counter in ~40 lines.
- **[Event Sourcing & CQRS](/docs/concepts.html)** — the mental model.
- **[Examples](/examples/)** — three complete apps, from a counter to a full
  CQRS bank.
