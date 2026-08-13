---
title: Design & Internals
---

# Design & Internals

This page goes one layer below the [core concepts](/docs/concepts.html): how the
event store is structured, what guarantees it provides, and why it's built this
way. Each decision is a tradeoff made explicit in the types rather than hidden
behind a "smart" default.

## One table, two orderings

An event store serves two access patterns. Per-aggregate reads fetch one
entity's events in order (how command handlers rebuild state). Global reads
fetch every event in total order (how read models catch up).

The naive approach uses two tables — but dual-writing risks the per-aggregate
insert succeeding while the global-log insert fails. Eventium uses a **single
table** instead:

| Column | Purpose |
|---|---|
| `id` (PK, auto-increment) | global sequence number |
| `uuid` | aggregate / stream identifier |
| `version` | position within the stream |
| `payload` | serialized event (JSON) |
| `metadata` | event type, correlation/causation IDs, timestamps, custom tags |

A unique constraint on `(uuid, version)` enforces per-stream ordering; the
auto-increment key provides global ordering. Per-aggregate reads filter by
`uuid` order by `version`; global reads order by `id`. Simpler, and no
dual-write consistency problem.

## Gap-free global sequences

Auto-increment IDs don't give you safe total ordering under concurrency. If
transaction A gets id 1 and B gets id 2, but B commits first, a subscriber can
see event 2, advance its checkpoint past it, and then never see event 1 once A
commits. That's silent data loss in any checkpoint-based consumer.

Eventium closes the gap at the backend, keeping the same interface:

- **PostgreSQL** serializes inserts with an explicit lock —
  `tableLockFunc t = "LOCK " <> t <> " IN EXCLUSIVE MODE"` — so ids are always
  assigned and committed in order. The lock is held only for the insert, not
  during command processing. The cost is a write bottleneck, acceptable because
  event writes are small and fast.
- **SQLite** needs no lock — its write model is already single-writer, so
  gap-free sequences fall out naturally. The cost is no write concurrency at
  all, which is fine for single-process, development, or low-volume use.

Both expose the same `EventStoreWriter`. The guarantee is a property of the
backend, not the abstraction — you pick a backend at the application boundary
and the domain code is unchanged.

## Optimistic concurrency

Concurrency control uses versions, not locks. A command handler captures the
stream's version when it reads and asserts it hasn't changed when it writes,
via [`ExpectedPosition`](/docs/command-handlers.html#optimistic-concurrency). No
lock is held during business logic; conflicts are detected on write and returned
as a typed `ConcurrencyConflict` value. Retry strategy is left to the caller —
it's domain-specific.

## Records, not typeclasses

Most Haskell libraries reach for a typeclass to make backends pluggable.
Eventium makes the store abstractions plain records instead:

```haskell
newtype EventStoreReader key position m event =
  EventStoreReader {getEvents :: QueryRange key position -> m [event]}

newtype EventStoreWriter key position m event =
  EventStoreWriter
    {storeEvents :: key -> ExpectedPosition position -> [event]
                 -> m (Either (EventWriteError position) EventWriteResult)}
```

Because stores are *values*, you can have two of the same kind in one program
(a main table and an archive table), pass them explicitly, and never hit orphan
instances. Composition is function application at the boundary —
`runEventStoreReaderUsing` lifts a reader across monads with a natural
transformation:

```haskell
runEventStoreReaderUsing ::
  (forall a. mstore a -> m a) ->
  EventStoreReader key position mstore event ->
  EventStoreReader key position m event
```

The same reasoning applies to `Codec`, `ProjectionCache`, `CheckpointStore`,
and `CommandDispatcher` — all records, all composed as values. You see the
configuration at the call site instead of having the compiler resolve it
invisibly.

The write result carries real positions back to the caller:

```haskell
type EventWriteResult = [(EventVersion, SequenceNumber)]
```

one `(version, global sequence)` pair per event written, in order.

## Metadata as a pipeline

Domain events describe the business (`AccountOpened`); infrastructure concerns —
type name, timestamps, correlation/causation IDs — live separately on
`EventMetadata`, not on the domain event:

```haskell
data EventMetadata = EventMetadata
  { eventType :: !EventTypeName,
    correlationId :: !(Maybe UUID),
    causationId :: !(Maybe UUID),
    createdAt :: !(Maybe UTCTime),
    custom :: !(Map Text Text)
  }
```

`eventType` is derived automatically from the Haskell type via `Typeable`; the
`custom` map holds arbitrary tags you want to attach. Enrichment is a composable
function:

```haskell
type MetadataEnricher = EventMetadata -> EventMetadata
```

Compose enrichers with `.`, use `id` for none. The enricher threads through the
whole command pipeline — `CommandDispatcher` and `ProcessManagerEffect` both
carry one — so a process manager can pass a correlation ID from a triggering
event into the commands it issues.

## Snapshotting long streams

Replaying thousands of events per command is wasteful for long-lived
aggregates. `ProjectionCache` stores a snapshot of projected state at a version
and only replays events since then:

```haskell
data ProjectionCache key position encoded m = ProjectionCache
  { storeSnapshot :: key -> position -> encoded -> m (),
    loadSnapshot :: key -> m (Maybe (position, encoded))
  }
```

Because streams are append-only, a snapshot at version N is always valid —
there's no invalidation problem, only replay-forward. Wire it in with
[`applyCommandHandlerWithCache`](/docs/command-handlers.html#long-streams-caching).
Not every aggregate needs it; it pays off for high-throughput streams with long
histories, at the cost of needing a serialization instance for aggregate state.

## Event publishing

`publishingEventStoreWriter` wraps a store writer so events are dispatched to
process managers and read models *after* a successful write. Build a publisher
from an `EventHandler` with `synchronousPublisher`, and the writer handles the
rest — when a command appends events, downstream consumers see them without
manual plumbing.

## Codec vs TypeEmbedding

Two conversions look structurally identical but mean different things:

```haskell
data Codec a b        = Codec        {encode :: a -> b, decode  :: b -> Maybe a}
data TypeEmbedding a b = TypeEmbedding {embed  :: a -> b, extract :: b -> Maybe a}
```

- **`Codec`** is the wire boundary — serialize a domain event to JSON and back.
- **`TypeEmbedding`** is the type hierarchy — fit an aggregate-level
  `AccountEvent` into an application-wide `BankEvent` and back, with no
  serialization.

Keeping them distinct means the compiler catches using one where you meant the
other. Both are values (no orphan instances), and Template Haskell generates
them — `mkSumTypeCodec` for wire codecs, `mkSumTypeEmbedding` for embeddings.
`embeddingToCodec` bridges them when you genuinely need to.

## Beyond the core

Two subsystems extend the store without changing the model above:

- **Schema evolution** (`Eventium.SchemaEvolution`) — upcast events on read
  against the immutable log. Events are stored in a versioned envelope
  `{schemaVersion, payload}`; a `SchemaRegistry` of pure single-hop upcasters is
  applied on decode, built from combinators like `addFieldIfAbsent`,
  `renameField`, and `removeField`. `upcastingValueCodec` drops into any place a
  `Codec` is expected.
- **Telemetry** (`Eventium.Telemetry`) — a generic structured sink,
  `Telemetry m`, over a `Signal` sum type. The write path is the first
  instrumented subsystem: `telemetryEventStoreWriter` emits `EventsPersisted` on
  success and `WriteConflict` on an optimistic-concurrency failure.
  `silentTelemetry` is the no-op default.

## See it in practice

The **[Bank example](/examples/bank.html)** wires most of this together:
multiple aggregates, a process manager with compensation, event publishing, and
both in-memory and persisted read models.
