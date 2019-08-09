# Store [![Swift](https://img.shields.io/badge/swift-5.1-orange.svg?style=flat)](#)
<img src="https://raw.githubusercontent.com/alexdrone/Dispatch/master/docs/dispatch_logo_small.png" width=150 alt="Dispatch" align=right />

Unidirectional, transactional, operation based, multi-store for **SwiftUI**.

## Overview

Store eschews MVC in favour of a unidirectional data flow. When a user interacts with a view, the view propagates an action through a central dispatcher, to the various stores that hold the application's data and business logic, which updates all of the views that are affected.

This works especially well with *SwiftUI*'s declarative programming style, which allows the store to send updates without specifying how to transition views between states.

- **Stores**: Holds the state of your application. You can have multiple stores for multiple domains of your app.
- **Actions**: You can only perform state changes through actions. Actions are small pieces of data (typically enums) that describe a state change. By drastically limiting the way state can be mutated, your app becomes easier to understand and it gets easier to work with many collaborators.
- **Transaction**:  An excution of a given action.
- **Views**: A simple function of your state. This works especially well with *SwiftUI*'s declarative programming style.

### Store

Stores contain the application state and logic. Their role is somewhat similar to a model in a traditional MVC, but they manage the state of many objects — they do not represent a single record of data like ORM models do. More than simply managing a collection of ORM-style objects, stores manage the application state for a particular domain within the application.

This allows an action to result in an update to the state of the store, via the dispatcher. After the stores are updated, they notify the observers that their state has changed, so the views may query the new state and update themselves.

### Action

An action represent an operation on the store.
Represent as a type compliant to `ActionType`. 

### Transaction

A transaction represent an excution of a given action.
The dispatcher can run transaction in four different modes: `async`, `sync`, and `mainThread`.
Additionally the trailing closure of the `run` method can be used to run a completion closure for the actions that have had run.

# Getting started

TL;DR

```swift
import SwiftUI
import Store

struct Counter: ModelType {
  var count = 0
}

enum CounterAction: ActionType {
  case increase(ammount: Int)
  case decrease(ammount: Int)

  var identifier: String {
    switch self {
    case .increase(_): return "INCREASE"
    case .decrease(_): return "DECREASE"
    }
  }

  func perform(context: TransactionContext<Store<Counter>, Self>) {
    switch self {
    case .increase(let ammount):
      context.store.updateModel { $0.count += ammount }
    case .decrease(let ammount):
      context.store.updateModel { $0.count -= ammount }
    }
    context.operation.finish()
  }
}

// MARK: - UI

struct ContentView : View {
  @EnvironmentObject var store: Store<Counter>
  var body: some View {
    Text("counter \(store.model.count)").tapAction {
      Transaction(CounterAction.increase(ammount: 1), in: store).run()
    }
  }
}

// MARK: - Preview

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(DispatchStore.default.counterStore)
    }
}
#endif
```

# Actions

TODO

### Middleware

TODO

# Advanced use

Dispatch takes advantage of *Operations* and *OperationQueues* and you can define complex dependencies between the operations that are going to be run on your store.

Also middleware support is available allowing you to quickly add some aspect-oriented feature to your design.

### Chaining actions

```swift
[Transaction(CounterAction.increase(ammount: 1), in: store),
 Transaction(CounterAction.increase(ammount: 1), in: store),
 Transaction(CounterAction.increase(ammount: 1), in: store)].run { context in
 // Will be executed after all of the transactions are completed.
}
```
Actions can also be executed in a synchronous fashion.

```swift
Transaction(CounterAction.increase(ammount: 1), in: store).on(.sync)
Transaction(CounterAction.increase(ammount: 1), in: store).on(.mainThread)
```

### Custom queues

TODO

### Tracking transaction state

TODO

### Dealing with errors

TODO

