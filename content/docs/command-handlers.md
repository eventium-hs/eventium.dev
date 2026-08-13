---
title: Command Handlers
---

# Command Handlers

A projection tells you how to reconstruct state. A command handler tells you
what to do with it: validate an incoming command against the current state and
either reject it or produce new events.

## The type

```haskell
data CommandHandler state event command err = CommandHandler
  { decide :: state -> command -> Either err [event],
    projection :: Projection state event
  }
```

`decide` is where all the domain logic lives — a **pure function**. Current
state and a command go in; either a typed rejection or a list of new events
comes out. The handler bundles `decide` with the `Projection` it uses to rebuild
state before making that call.

```haskell
handleAccountCommand :: Account -> AccountCommand -> Either AccountCommandError [AccountEvent]
handleAccountCommand account (OpenAccountAccountCommand cmd)
  | isJust account.owner = Left AccountAlreadyOpen
  | cmd.initialFunding < 0 = Left InvalidInitialDeposit
  | otherwise = Right [AccountOpenedAccountEvent (AccountOpened cmd.owner cmd.initialFunding)]
handleAccountCommand account (TransferToAccountAccountCommand cmd)
  | isNothing account.owner = Left AccountNotOpen
  | accountAvailableBalance account - cmd.amount < 0 =
      Left (InsufficientFunds (accountAvailableBalance account))
  | otherwise = Right [AccountTransferStartedAccountEvent (...)]

accountCommandHandler :: CommandHandler Account AccountEvent AccountCommand AccountCommandError
accountCommandHandler = CommandHandler handleAccountCommand accountProjection
```

Because `decide` is pure, the entire domain is testable with no infrastructure —
pass in a state and a command, assert on the `Either`:

```haskell
accountCommandHandler.decide stateAfterStarted (DebitAccountAccountCommand (DebitAccount 9 "rent"))
  `shouldBe` Left (InsufficientFunds 4)
```

## Running a command

`applyCommandHandler` ties a handler to a store and runs it end to end:

```haskell
applyCommandHandler ::
  (Monad m) =>
  VersionedEventStoreWriter m event ->
  VersionedEventStoreReader m event ->
  CommandHandler state event command err ->
  UUID ->
  command ->
  m (Either (CommandHandlerError err) [event])
```

It runs three phases:

1. **Read** — replay the aggregate's events into current state, capturing the
   stream's version.
2. **Decide** — call your pure `decide` with that state and the command.
3. **Write** — if `decide` returned `Right`, append the new events, asserting
   the stream is still at the version we read.

No lock is held during the decide phase.

## Optimistic concurrency

Two handlers could read the same aggregate at version 5, both run their logic,
and both try to write. Allowing both would corrupt the stream — the events were
validated against the same state, not against each other.

Eventium prevents this optimistically. When writing, the handler asserts the
stream's expected position via `ExpectedPosition`:

```haskell
data ExpectedPosition position
  = AnyPosition            -- don't care where the stream is
  | NoStream               -- the stream shouldn't exist yet
  | StreamExists           -- the stream should already exist
  | ExactPosition position -- the stream must be exactly here
```

`applyCommandHandler` uses `ExactPosition` with the version it read. If another
writer landed in between, the version check fails and the write is rejected — no
lock was ever held during business logic.

## Two kinds of failure

The result type keeps domain rejection and infrastructure conflict distinct:

```haskell
data CommandHandlerError err
  = CommandRejected err                              -- your domain said no
  | ConcurrencyConflict (EventWriteError EventVersion) -- someone else wrote first
```

`InsufficientFunds` and `AccountNotOpen` live in your `err` type; a version
mismatch is a `ConcurrencyConflict`. The compiler makes you handle each
appropriately. No retries are built in — retry strategy depends on the domain
(some commands are safe to replay, others aren't), so that decision is left to
the caller.

## Long streams: caching

Replaying every event on every command is fine for short streams but costs more
as history grows. `applyCommandHandlerWithCache` takes a
[`ProjectionCache`](/docs/internals.html) and only replays events *since* the
last snapshot:

```haskell
applyCommandHandlerWithCache ::
  (Monad m) =>
  VersionedEventStoreWriter m event ->
  VersionedEventStoreReader m event ->
  VersionedProjectionCache state m ->
  CommandHandler state event command err ->
  UUID ->
  command ->
  m (Either (CommandHandlerError err) [event])
```

Because streams are append-only, a cached state at version N is always valid —
there's no cache-invalidation problem, only replay-forward.

## Next

Command handlers act within a single aggregate.
**[Process managers](/docs/process-managers.html)** coordinate workflows *across*
aggregates.
