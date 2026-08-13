---
title: Counter CLI
---

# Counter CLI

The smallest useful Eventium program: a bounded counter (0–100) driven from an
interactive prompt, backed by an in-memory store. It's a single ~100-line file
and uses only the four core primitives — events, a projection, a command
handler, and a store. No persistence, no process managers, no read models.

It demonstrates the ideas in **[Projections](/docs/projections.html)** and
**[Command Handlers](/docs/command-handlers.html)**.

## State, events, projection

State is a single integer. Events are past-tense facts — note there's an event
for going out of bounds, rather than a rejected command:

```haskell
newtype CounterState = CounterState {unCounterState :: Int}
  deriving (Eq, Show)

data CounterEvent
  = CounterAmountAdded Int
  | CounterOutOfBounds Int
  deriving (Eq, Show)

counterProjection :: Projection CounterState CounterEvent
counterProjection = Projection (CounterState 0) handleCounterEvent

handleCounterEvent :: CounterState -> CounterEvent -> CounterState
handleCounterEvent (CounterState k) (CounterAmountAdded x) = CounterState (k + x)
handleCounterEvent state (CounterOutOfBounds _) = state
```

## Commands

The counter never *rejects* a command — an out-of-bounds request is recorded as
a `CounterOutOfBounds` event instead. So the error type is `Void`:

```haskell
data CounterCommand
  = IncrementCounter Int
  | DecrementCounter Int
  | ResetCounter
  deriving (Eq, Show, Read)

handlerCounterCommand :: CounterState -> CounterCommand -> Either Void [CounterEvent]
handlerCounterCommand (CounterState k) (IncrementCounter n) =
  Right $
    if k + n <= 100
      then [CounterAmountAdded n]
      else [CounterOutOfBounds (k + n)]
handlerCounterCommand (CounterState k) (DecrementCounter n) =
  Right $
    if k - n >= 0
      then [CounterAmountAdded (-n)]
      else [CounterOutOfBounds (k - n)]
handlerCounterCommand (CounterState k) ResetCounter = Right [CounterAmountAdded (-k)]

counterCommandHandler :: CommandHandler CounterState CounterEvent CounterCommand Void
counterCommandHandler = CommandHandler handlerCounterCommand counterProjection
```

## Wiring the store

This example works one level below `applyCommandHandler` to show the moving
parts. It creates an in-memory store, reads current state with
`getLatestStreamProjection`, calls `.decide` directly, and appends events with
`AnyPosition` (a single counter, so no concurrency to guard):

```haskell
main :: IO ()
main = do
  tvar <- eventMapTVar
  let writer = tvarEventStoreWriter tvar
      reader = tvarEventStoreReader tvar
  forever (readAndHandleCommand writer reader)

readAndHandleCommand ::
  VersionedEventStoreWriter STM CounterEvent ->
  VersionedEventStoreReader STM CounterEvent ->
  IO ()
readAndHandleCommand writer reader = do
  let uuid = nil
  latestStreamProjection <-
    atomically $ getLatestStreamProjection reader (versionedStreamProjection uuid counterProjection)
  let currentState = latestStreamProjection.state
  putStrLn $ "Current state: " ++ show currentState

  input <- getLine
  case readMay input of
    Nothing -> putStrLn "Unknown command"
    Just command ->
      case counterCommandHandler.decide currentState command of
        Right events -> do
          putStrLn $ "Events generated: " ++ show events
          void . atomically $ writer.storeEvents uuid AnyPosition events
        Left err -> absurd err
```

The store is `STM`-based, so each read and write runs inside `atomically`.
`absurd` handles the impossible `Left` — the type says this counter can't reject
a command.

## Running it

```
cabal run counter-cli
```

```
Current state: CounterState {unCounterState = 0}
Enter a command. (IncrementCounter n, DecrementCounter n, ResetCounter):
IncrementCounter 40
Events generated: [CounterAmountAdded 40]

Current state: CounterState {unCounterState = 40}
```

## Where to go next

- The **[Getting Started](/docs/getting-started.html)** guide is a variant of
  this using the higher-level `applyCommandHandler`.
- **[Café](/examples/cafe.html)** adds SQLite persistence, a typed error type,
  and a read model driven by a subscription.
