---
title: Process Managers
---

# Process Managers

Command handlers act within a single aggregate — one stream, one consistency
boundary. But a bank transfer debits one account and credits another: two
aggregates, each with its own stream. They can't be touched in the same command
handler; they have to be *coordinated*. That's what a process manager does.

A process manager watches events from across the system and reacts by issuing
commands.

## The type

```haskell
data ProcessManager state event command = ProcessManager
  { projection :: Projection state (VersionedStreamEvent event),
    react :: state -> VersionedStreamEvent event -> [ProcessManagerEffect command]
  }
```

The `projection` tracks whatever state the manager needs to make decisions — in
a transfer manager, which transfers are in flight. The interesting part is
`react`: it takes the current state and a new event and returns a list of
**effects**. Like `decide`, it's a **pure function** — no IO, no database calls,
just state and event in, effects out.

## Effects, and compensation as data

```haskell
data ProcessManagerEffect command
  = IssueCommand UUID command MetadataEnricher
  | IssueCommandWithCompensation
      UUID
      command
      MetadataEnricher
      (RejectionReason -> [ProcessManagerEffect command])
```

`IssueCommand` is simple: send this command to this aggregate. The
`MetadataEnricher` lets you thread metadata (like a correlation ID) from the
triggering event into the command it produces; pass `id` when you don't need to.

`IssueCommandWithCompensation` carries a function: **if the command is rejected,
here's what to do about it.** The rollback logic is encoded right there in the
value — not in a separate compensation service you have to wire up and hope stays
in sync.

Here's the heart of a transfer manager. When it sees a transfer start, it issues
`AcceptTransfer` to the target account; if that's rejected, the compensation
fires `RejectTransfer` back on the source:

```haskell
reactTransfer manager (StreamEvent sourceAcct _ _ (AccountTransferStartedEvent evt))
  | isNothing (Map.lookup evt.transferId manager.transferData) =
      [ IssueCommandWithCompensation
          evt.targetAccount
          (AcceptTransferCommand (AcceptTransfer evt.transferId sourceAcct evt.amount))
          id
          ( \(RejectionReason reason) ->
              [ IssueCommand
                  sourceAcct
                  (RejectTransferCommand (RejectTransfer evt.transferId (T.unpack reason)))
                  id
              ]
          )
      ]
  | otherwise = []
```

The entire decision tree — including the failure branch — is one pure
expression you can unit-test by passing in a state and an event and asserting on
the returned effects.

## Running effects

`react` only *describes* what should happen. To actually execute the effects,
`runProcessManagerEffects` walks the list and dispatches each command through a
`CommandDispatcher`:

```haskell
runProcessManagerEffects ::
  (Monad m) =>
  CommandDispatcher m command ->
  [ProcessManagerEffect command] ->
  m ()
```

A `CommandDispatcher` is just a function wrapped in a newtype — how a command
gets routed to the right aggregate and run:

```haskell
newtype CommandDispatcher m command = CommandDispatcher
  { dispatchCommand :: UUID -> command -> MetadataEnricher -> m CommandDispatchResult
  }

data CommandDispatchResult
  = CommandSucceeded
  | CommandFailed RejectionReason
```

When a dispatched command fails and it was issued *with compensation*,
`runProcessManagerEffects` feeds the `RejectionReason` into the compensation
function and continues with whatever effects it returns.

## Why pure effects matter

Most event-sourcing frameworks implement sagas or process managers as effectful
state machines — you're in IO from the start, and testing means mocking most of
the system. Here:

- **`react` is data, not IO.** The whole saga is a pure function.
- **Compensation is data, not a service.** The failure handler is part of the
  value you return, so the compiler sees the whole flow — no dangling callbacks,
  no rollback handler that might be wired to the wrong failure.

## Next

Process managers drive the write side. To serve queries across aggregates, build
a **[read model](/docs/read-models.html)**.
