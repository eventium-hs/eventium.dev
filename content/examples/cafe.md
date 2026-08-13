---
title: Café
---

# Café

A restaurant tab ordering system, inspired by the
[cqrs.nu](https://cqrs.nu/) tutorial. It's the middle step between the
[Counter](/examples/counter-cli.html) and the [Bank](/examples/bank.html): still
a single aggregate, but now with **SQLite persistence**, an **explicit error
type**, and a **read model driven by a polling subscription** running in a
separate process.

It's the companion to the **[Read Models](/docs/read-models.html)** guide.

## The Tab aggregate

A tab has a real lifecycle — open, order food and drinks, serve them, close and
pay — with validation at each step. State tracks what's outstanding:

```haskell
data TabState = TabState
  { isOpen :: Bool,
    outstandingDrinks :: [Maybe Drink],
    outstandingFood :: [Maybe Food],
    preparedFood :: [Maybe Food],
    servedItems :: [MenuItem]
  }
  deriving (Show, Eq)

tabProjection :: TabProjection
tabProjection = Projection tabSeed applyTabEvent
```

Commands and their typed rejections:

```haskell
data TabCommand
  = PlaceOrder [Food] [Drink]
  | MarkDrinksServed [Int]
  | MarkFoodPrepared [Int]
  | MarkFoodServed [Int]
  | CloseTab Double
  deriving (Show, Eq)

data TabCommandError
  = TabAlreadyClosed
  | CannotCancelServedItem
  | TabHasUnservedItems
  | MustPayEnough
  deriving (Show, Eq)
```

The command handler enforces the rules. Closing a tab is the richest case — you
can't close with outstanding items, and you must pay at least what was served:

```haskell
applyTabCommand :: TabState -> TabCommand -> Either TabCommandError [TabEvent]
applyTabCommand TabState {isOpen = False} _ = Left TabAlreadyClosed
applyTabCommand state (CloseTab cash)
  | amountOfNonServedItems > 0 = Left TabHasUnservedItems
  | cash < totalServedWorth = Left MustPayEnough
  | otherwise = Right [TabClosed cash]
  where
    amountOfNonServedItems =
      length (filter isJust state.outstandingDrinks)
        + length (filter isJust state.outstandingFood)
        + length (filter isJust state.preparedFood)
    totalServedWorth = foldl' (+) 0 (fmap (.price) state.servedItems)
applyTabCommand _ (PlaceOrder newFood newDrinks) =
  Right [FoodOrdered newFood, DrinksOrdered newDrinks]
```

Unlike the counter, this handler returns `Left` on invalid intent — a real
`TabCommandError` the CLI can report.

## A read model across processes

The café ships two executables that share one SQLite database: the waiter CLI
(the write side) and a **chef todo list** that shows outstanding food. The chef
process subscribes to the global event stream with `pollingSubscription`,
tracking its position in a `CheckpointStore` (here just an `IORef`) and folding
each event into an in-memory view:

```haskell
seqRef <- newIORef (0 :: SequenceNumber)
foodMapRef <- newIORef (Map.empty :: Map UUID [Maybe Food])

let checkpoint = CheckpointStore (readIORef seqRef) (writeIORef seqRef)
    globalReader = runEventStoreReaderUsing (`runSqlPool` pool) cliGloballyOrderedEventStore
    sub = pollingSubscription globalReader checkpoint 1000
    handler = EventHandler $ \globalEvent ->
      case traverse jsonStringCodec.decode globalEvent.payload of
        Nothing -> return ()
        Just tabEvent -> do
          foodMap <- readIORef foodMapRef
          let foodMap' = handleEventToMap foodMap tabEvent
          writeIORef foodMapRef foodMap'
          printFood foodMap'

sub.runSubscription handler
```

`pollingSubscription` polls every 1000 ms; `jsonStringCodec.decode` turns the
stored JSON payload back into a `TabEvent`. Because the read model is driven off
the durable event log and its own checkpoint, it can be started, stopped, and
resumed independently of the writer — the essence of the CQRS read/write split.

## Running it

The two executables point at the same SQLite file:

```
cabal run cafe             # waiter CLI (writes events)
cabal run cafe-chef-todo   # chef read model (reads the global stream)
```

## Where to go next

**[Bank](/examples/bank.html)** takes the final step to full CQRS: multiple
aggregates coordinated by a process manager, event publishing, and both
in-memory and persisted read models.
