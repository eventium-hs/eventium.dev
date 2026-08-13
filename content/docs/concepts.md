---
title: Event Sourcing & CQRS
---

# Event Sourcing & CQRS

The core idea is deceptively simple: instead of storing the current state of
something, you store the sequence of things that happened to it. Current state
is never saved — it's always derived by replaying those events from the
beginning.

That derivation is called a **projection**, and it's just a fold: start with an
initial state, apply each event in order, and arrive at where you are now. If
you want a different view of the same data, you write a different fold.

## Commands and events

**Commands** are the other half. Before anything gets persisted, a **command
handler** validates the intent against the current projected state and decides
whether to accept or reject it. If it's valid, the handler produces new events —
it doesn't mutate anything directly.

This separation matters: **commands can fail, events cannot.** Once an event is
in the log, it happened. A command like `Withdraw 100` might be rejected for
insufficient funds; the event `Withdrawn 100` is a statement of fact.

## CQRS: splitting reads from writes

CQRS (Command Query Responsibility Segregation) builds on this by separating the
write and read sides entirely.

- The **write side** lives in *aggregates* — units of consistency that process
  commands and emit events. Each aggregate is a single event stream with its own
  consistency boundary.
- The **read side** is a set of *read models* (projections tuned for the queries
  you actually need). They're rebuilt from the event log and can evolve
  independently of the write side.

Because read models are derived, you can add a new one at any time and populate
it by replaying history — no migration of "current state" required.

## Process managers

For workflows that span multiple aggregates — "open an account, then fund it,
then notify another service" — there are **process managers**. They listen to
events from one aggregate and issue commands to others, coordinating multi-step
flows without coupling the aggregates directly. When a step can fail, they carry
their own compensation logic.

## How Eventium models these

Each concept is a small, first-class value:

| Concept | In Eventium | One-liner |
|---|---|---|
| Projection | `Projection state event` | a seed + an event handler (a fold) |
| Command handling | `CommandHandler state event command err` | a pure `decide` + a projection |
| Workflow | `ProcessManager state event command` | a pure `react` returning effects |
| Query view | `ReadModel m event` | initialize / handle / checkpoint / reset |
| Storage | `EventStoreReader` / `EventStoreWriter` | records of functions, swappable |

Two properties fall out of this design and recur everywhere:

- **Domain logic is pure.** `decide` and `react` are ordinary functions —
  state and input in, values out. You can unit-test your entire domain by
  passing in a list of events and asserting on the result. No database, no
  mocking.
- **Everything composes as data.** Stores, codecs, dispatchers, and projections
  are values you pass around, not typeclass instances resolved by the compiler.

## Where to go next

- **[Projections](/docs/projections.html)** — reconstruct state from events.
- **[Command Handlers](/docs/command-handlers.html)** — validate intent and emit events.
- **[Process Managers](/docs/process-managers.html)** — coordinate across aggregates.
- **[Read Models](/docs/read-models.html)** — build queryable views.
