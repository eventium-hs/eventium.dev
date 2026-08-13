---
title: Getting Started
---

# Getting Started

This guide installs Eventium and builds a tiny but complete event-sourced
counter — events, a projection, a command handler, and an in-memory store —
in about 40 lines.

## Install

Eventium is split into a storage-agnostic core plus a backend of your choice.
Add the core and one backend to your project's dependencies:

```
eventium-core
eventium-memory      -- STM in-memory store, great for tests and demos
-- or eventium-sqlite      -- single-process apps, CLIs, desktop
-- or eventium-postgresql  -- production, concurrent writers
```

The same domain code — projections, command handlers, process managers —
works against any backend. You pick the store at the application boundary.

Eventium targets GHC 9.10 and uses `OverloadedRecordDot`, so field access is
written `value.field`.

## A minimal counter

We'll model a counter that can be incremented and reset. Every piece is a
plain value.

```haskell
{-# LANGUAGE OverloadedRecordDot #-}

module Main where

import Control.Concurrent.STM (atomically)
import Data.Void (Void)
import Eventium
import Eventium.Store.Memory

-- 1. State — what we reconstruct from events.
newtype Counter = Counter {count :: Int}
  deriving (Show)

-- 2. Events — past tense; things that already happened.
data CounterEvent
  = Incremented Int
  | Reset
  deriving (Show)

-- 3. Projection — a fold: a seed plus an event handler.
counterProjection :: Projection Counter CounterEvent
counterProjection = Projection (Counter 0) apply
  where
    apply (Counter n) (Incremented k) = Counter (n + k)
    apply _ Reset = Counter 0

-- 4. Commands — intent; a pure function decides which events they produce.
data CounterCommand
  = Increment Int
  | ResetCounter
  deriving (Show)

decide :: Counter -> CounterCommand -> Either Void [CounterEvent]
decide _ (Increment k) = Right [Incremented k]
decide _ ResetCounter = Right [Reset]

counterCommandHandler :: CommandHandler Counter CounterEvent CounterCommand Void
counterCommandHandler = CommandHandler decide counterProjection

main :: IO ()
main = do
  -- An in-memory event store, lifted from STM into IO.
  tvar <- eventMapTVar
  let writer = runEventStoreWriterUsing atomically (tvarEventStoreWriter tvar)
      reader = runEventStoreReaderUsing atomically (tvarEventStoreReader tvar)
      aggregateId = nil -- a single counter, keyed by the nil UUID

  _ <- applyCommandHandler writer reader counterCommandHandler aggregateId (Increment 3)
  _ <- applyCommandHandler writer reader counterCommandHandler aggregateId (Increment 4)

  -- Rebuild the current state by replaying the stream.
  sp <- getLatestStreamProjection reader (versionedStreamProjection aggregateId counterProjection)
  print sp.state -- Counter {count = 7}
```

Running this prints:

```
Counter {count = 7}
```

## What just happened

- **`applyCommandHandler`** loaded the aggregate's current state (by replaying
  its events), called your pure `decide`, and — if it returned `Right` —
  appended the new events with an optimistic-concurrency check. Its result type
  is `Either (CommandHandlerError err) [event]`.
- **`getLatestStreamProjection`** folded the stored events back into a `Counter`.
  No database round-trips beyond reading the stream; the fold itself is pure.
- The store was **in-memory**. To persist, swap `Eventium.Store.Memory` for
  `Eventium.Store.Sqlite` or `Eventium.Store.Postgresql` — the domain code above
  doesn't change.

## Next steps

- Understand the model: **[Event Sourcing & CQRS](/docs/concepts.html)**.
- Go deeper on each piece: **[Projections](/docs/projections.html)**,
  **[Command Handlers](/docs/command-handlers.html)**.
- See it scale up: the **[Counter CLI](/examples/counter-cli.html)** example is
  this program made interactive; **[Café](/examples/cafe.html)** and
  **[Bank](/examples/bank.html)** add persistence, subscriptions, and process
  managers.
