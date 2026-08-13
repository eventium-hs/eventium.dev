---
title: Read Models
---

# Read Models

Command handlers and projections are the write side — they reconstruct a single
aggregate's state to validate commands. But queries often cut across aggregates:
"show me all pending transfers" doesn't belong to any one account. A **read
model** is a queryable view kept up to date by consuming the global event
stream.

## The type

```haskell
data ReadModel m event = ReadModel
  { initialize :: m (),
    eventHandler :: EventHandler m (GlobalStreamEvent event),
    checkpointStore :: CheckpointStore m SequenceNumber,
    reset :: m ()
  }
```

The type is parametric over the monad `m`, so the *same* abstraction backs both
a SQL table and an in-memory `TVar`. Each field has one job:

- **`initialize`** — set up storage (run migrations, create tables).
- **`eventHandler`** — process each event from the global stream and update the view.
- **`checkpointStore`** — remember the last `SequenceNumber` processed, so a
  restart resumes instead of replaying from zero.
- **`reset`** — wipe everything, for rebuilds.

## A persisted read model

Backed by SQLite (or PostgreSQL): survives restarts, queryable from other
processes via SQL.

```haskell
transferReadModel :: ReadModel (SqlPersistT IO) BankEvent
transferReadModel =
  ReadModel
    { initialize = void (runMigrationSilent migrateTransfer),
      eventHandler = EventHandler handleTransferEvent,
      checkpointStore = sqliteCheckpointStore (CheckpointName "transfers"),
      reset = deleteWhere ([] :: [Filter TransferEntity])
    }
```

Queries are then plain SQL against the table the model maintains:

```haskell
getTransfersByStatus :: (MonadIO m) => Text -> SqlPersistT m [Entity TransferEntity]
getTransfersByStatus s = selectList [TransferEntityStatus ==. s] []
```

## An in-memory read model

For derived state that's cheap to rebuild and only consumed in-process — a
counter, a dashboard tally, an internal lookup — back it with a `TVar`.
`initialize` is a no-op, `reset` writes the initial value, and it replays from
the start of the log on boot. Same four fields, same interface; the choice is
made at construction time, not baked into the abstraction.

## Running a read model

Several operations drive read models, covering both eventually-consistent and
in-transaction styles:

```haskell
runReadModel      :: MonadIO m => GlobalEventStoreReader m event -> PollingIntervalMillis -> ReadModel m event -> m ()
catchUpReadModel  :: Monad m  => GlobalEventStoreReader m event -> ReadModel m event -> m ()
rebuildReadModel  :: Monad m  => GlobalEventStoreReader m event -> ReadModel m event -> m ()
readModelPublisher :: Monad m => ReadModel m event -> GlobalEventPublisher m event
combineReadModels :: Applicative m => [ReadModel m event] -> ReadModel m event
```

- **`runReadModel`** polls the global stream on an interval and feeds new events
  to the handler — the normal, eventually-consistent operation.
- **`catchUpReadModel`** processes everything available right now and returns —
  handy at startup or in tests.
- **`rebuildReadModel`** calls `reset`, then replays from the beginning. Use it
  after changing projection logic.
- **`readModelPublisher`** turns a read model into a publisher so it can be
  updated *synchronously, in the same transaction* as the write (see
  [event publishing](/docs/internals.html)) — for views that must never lag.
- **`combineReadModels`** fans one global-stream subscription out to many read
  models, so you subscribe once and dispatch to all of them.

## Delivery guarantees

Checkpointing is at-least-once: if the process crashes after handling events but
before saving the checkpoint, those events are reprocessed on restart. **Event
handlers must therefore be idempotent.** Eventium doesn't pretend to offer
exactly-once delivery — doing that reliably across arbitrary backends is a
distributed-systems problem that doesn't belong in a library.

## Resilient consumption

Underneath `runReadModel` is an `EventSubscription`. For production, a
temporary database error shouldn't permanently kill a read model, and naive
retry-forever can overload a recovering database. `resilientPollingSubscription`
adds exponential backoff via a `RetryConfig`:

```haskell
data RetryConfig = RetryConfig
  { initialDelayMs :: !Int,
    maxDelayMs :: !Int,
    backoffMultiplier :: !Double,
    onError :: SomeException -> IO Bool,   -- retry (True) or re-throw (False)
    onErrorCallback :: SomeException -> Int -> IO ()
  }

defaultRetryConfig :: RetryConfig  -- 1s initial, 30s cap, 2x multiplier
```

The `onError` predicate lets you separate temporary failures (retry) from fatal
ones (re-throw); `onErrorCallback` is for logging. On success the consecutive
error count resets to zero.

The tradeoff with polling is latency: a read model updates within its poll
interval. For CQRS systems that's expected — read models are eventually
consistent by design. When you need no lag, use the synchronous
`readModelPublisher` path instead.

## Next

See how the store makes total ordering, concurrency, and metadata work under
the hood: **[Design & Internals](/docs/internals.html)**.
