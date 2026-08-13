---
title: Documentation
---

# Documentation

Eventium is a typed, composable event-sourcing and CQRS library for Haskell.
Instead of storing the current state of something, you store the sequence of
events that happened to it, and derive state by replaying them. That constraint
forces clarity — and Eventium gives you small, well-typed pieces to build on:

- A **projection** is a fold: a seed plus an event handler.
- A **command handler** is a pure function that validates intent and returns events.
- A **process manager** is a pure function that reacts to events with commands.
- A **read model** is a queryable view kept up to date from the event log.
- An **event store** is a record of functions — swap in-memory, SQLite, or PostgreSQL at the boundary.

Everything is a plain value, not a typeclass, so it composes by function
application rather than instance resolution.

## Start here

1. **[Getting Started](/docs/getting-started.html)** — install Eventium and build a runnable counter.
2. **[Event Sourcing & CQRS](/docs/concepts.html)** — the mental model the rest of the docs build on.

## Core concepts

- **[Projections](/docs/projections.html)** — reconstruct state from events.
- **[Command Handlers](/docs/command-handlers.html)** — validate commands, emit events, handle concurrency.
- **[Process Managers](/docs/process-managers.html)** — coordinate workflows across aggregates, with compensation.
- **[Read Models](/docs/read-models.html)** — build queryable views, in memory or persisted.
- **[Design & Internals](/docs/internals.html)** — how the event store works and why it's built this way.

## Learn by example

The **[examples](/examples/)** section walks through three complete apps, from a
100-line counter to a full CQRS banking system.

## Reference

Full API documentation lives on
[Hackage](https://hackage.haskell.org/package/eventium). The source is on
[GitHub](https://github.com/eventium-hs/eventium).
