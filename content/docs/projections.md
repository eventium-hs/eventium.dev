---
title: Projections
---

# Projections

A projection reconstructs state from a sequence of events. It's the central
abstraction for turning "what happened" back into "where we are now."

## The type

```haskell
data Projection state event = Projection
  { seed :: state,
    eventHandler :: state -> event -> state
  }
```

`seed` is the initial state, before any events. `eventHandler` takes the current
state and one event and returns the next state. That's the whole thing — a
`Projection` is a fold specification packaged as a first-class value.

Here's a bank account projection:

```haskell
data Account = Account
  { balance :: Double,
    owner :: Maybe UUID
  }

accountProjection :: Projection Account AccountEvent
accountProjection = Projection (Account 0 Nothing) apply
  where
    apply acc (AccountOpened o funding) = acc {owner = Just o, balance = funding}
    apply acc (AccountCredited amt) = acc {balance = acc.balance + amt}
    apply acc (AccountDebited amt) = acc {balance = acc.balance - amt}
```

Each case is a direct translation of "what does this event mean for the state."

## Running a projection

To fold a projection over any `Foldable` of events — a list, a `Seq`, whatever
you have — use `latestProjection`:

```haskell
latestProjection :: (Foldable t) => Projection state event -> t event -> state
```

```haskell
-- Rebuild state from a list of events, purely.
currentBalance :: [AccountEvent] -> Double
currentBalance events = (latestProjection accountProjection events).balance
```

No IO, no database round-trip — just a fold. This is what makes projections so
easy to test: you can unit-test your entire state-reconstruction logic by
passing in a list of events and checking the result. No test database, no
mocking, no setup.

## Projecting from a store

When the events live in an event store, `getLatestStreamProjection` reads a
single aggregate's stream and folds it into a `StreamProjection`, which carries
both the reconstructed `state` and the stream's current `position`:

```haskell
getLatestStreamProjection ::
  (Monad m, Num position) =>
  EventStoreReader key position m (StreamEvent key position event) ->
  StreamProjection key position state event ->
  m (StreamProjection key position state event)
```

`versionedStreamProjection` builds the `StreamProjection` for one aggregate
(keyed by `UUID`):

```haskell
sp <- getLatestStreamProjection reader (versionedStreamProjection accountId accountProjection)
print sp.state      -- the reconstructed Account
print sp.position   -- its current version, used for optimistic concurrency
```

That `position` is exactly what a [command handler](/docs/command-handlers.html)
asserts against when it writes.

## Crossing boundaries

Two adapters let a projection work with types other than its own:

- **`codecProjection`** / **`lenientCodecProjection`** adapt a projection over
  domain events to run over an *encoded* representation (e.g. JSON from the
  store). The lenient variant skips events it can't decode instead of failing —
  useful for forward compatibility when new event types appear in a stream that
  an older consumer doesn't understand yet.

  ```haskell
  codecProjection       :: Codec event encoded -> Projection state event -> Projection state encoded
  lenientCodecProjection :: Codec event encoded -> Projection state event -> Projection state encoded
  ```

- **`embeddedProjection`** lifts an aggregate-level projection to run over an
  application-wide sum type via a [`TypeEmbedding`](/docs/internals.html), so a
  projection written for `AccountEvent` can consume a stream of `BankEvent`:

  ```haskell
  accountBankProjection :: Projection Account BankEvent
  accountBankProjection = embeddedProjection accountEventEmbedding accountProjection
  ```

## Next

Projections reconstruct state; **[command handlers](/docs/command-handlers.html)**
use that state to validate commands and decide which events to append.
