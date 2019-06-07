# DispatchStore [![Swift](https://img.shields.io/badge/swift-5.1-orange.svg?style=flat)](#)
<img src="https://raw.githubusercontent.com/alexdrone/Dispatch/master/docs/dispatch_logo_small.png" width=150 alt="Dispatch" align=right />

Swift package that implements an operation based, multi-store for **SwiftUI**.

## Overview

**Dispatch** is a [Flux](https://facebook.github.io/flux/docs/overview.html)-like implementation of the unidirectional data flow architecture in Swift.
Flux applications have three major parts: the dispatcher, the stores, and the views.

These should not be confused with Model-View-Controller. Controllers do exist in a Dispatch/Flux application, but they are controller-views — views often found at the top of the hierarchy that retrieve data from the stores and pass this data down to their children (views).

Dispatch eschews MVC in favour of a unidirectional data flow. When a user interacts with a view, the view propagates an action through a central dispatcher, to the various stores that hold the application's data and business logic, which updates all of the views that are affected.

This works especially well with *SwiftUI*'s declarative programming style, which allows the store to send updates without specifying how to transition views between states.


- **Stores**: Holds the state of your application. You can have multiple stores for multiple domains of your app.
- **Actions**: You can only perform state changes through actions. Actions are small pieces of data (typically enums) that describe a state change. By drastically limiting the way state can be mutated, your app becomes easier to understand and it gets easier to work with many collaborators.
- **Dispatcher**: Dispatches an action to the stores that respond to it.
- **Views**: A simple function of your state. This works especially well with *SwiftUI*'s declarative programming style.

<img src="https://raw.githubusercontent.com/alexdrone/Dispatch/master/docs/new_diag.png" width="640" alt="Diagram" />

### Single Dispatcher

The dispatcher is the central hub that manages all data flow in your application. It is essentially a registry of callbacks into the stores and has no real intelligence of its own — it is a simple mechanism for distributing the actions to the stores. Each store registers itself and provides a callback. When an action creator provides the dispatcher with a new action, all stores in the application receive the action via the callbacks in the registry - and redirect the action to their reducer.

As an application grows, the dispatcher becomes more vital, as it can be used to manage dependencies between the stores by invoking the registered callbacks in a specific order. Stores can declaratively wait for other stores to finish updating, and then update themselves accordingly.

The dispatcher can run actions in four different modes: `async`, `sync`, `serial` and `mainThread`.

Additionally the trailing closure of the `dispatch` method can be used to chain some actions sequentially.


### Stores

Stores contain the application state and logic. Their role is somewhat similar to a model in a traditional MVC, but they manage the state of many objects — they do not represent a single record of data like ORM models do. More than simply managing a collection of ORM-style objects, stores manage the application state for a particular domain within the application.

As mentioned above, a store registers itself with the dispatcher. The store has a `Reducer` that typically has a switch statement based on the action's type —
the reducer is the only *open* class provided from the framework, and the user of this library are expected to subclass it to return an operation for every action handled by the store.

This allows an action to result in an update to the state of the store, via the dispatcher. After the stores are updated, they notify the observers that their state has changed, so the views may query the new state and update themselves.

### Redux Implementation

*Redux* can be seen as a special *DispatchStore* use-case.
You can recreate a Redux configuration by having a single store registered to the Dispatcher and by ensuring state immutability in your store.

# Getting started

TL;DR

```swift
import SwiftUI
import DispatchStore

// MARK: - Store

struct Counter: ModelType {
  enum Action: ActionType {
    case increase
    case decrease
  }
  var count: Int = 0
}

class CounterReducer: Reducer<Counter, Counter.Action> {
  override func operation(for action: Counter.Action, in store: Store<Counter, Counter.Action>) -> ActionOperation<Counter, Counter.Action> {
    switch action {
    case .increase:
      return ActionOperation(action: action, store: store) { operation, _, store in
        store.updateModel { $0.count += 1 }
        operation.finish()
      }
    case .decrease:
      return ActionOperation(action: action, store: store) { operation, _, store in
      store.updateModel { $0.count -= 1 }
      operation.finish()
      }
    }
  }
}

extension DispatchStore {
  var counterStore: Store<Counter, Counter.Action> {
    let key = "counter"
    if let store = self.store(with: key) as? Store<Counter, Counter.Action> {
      return store
    }
    let store = Store<Counter, Counter.Action>(identifier: key, reducer: CounterReducer())
    register(store: store)
    return store
  }
}

// MARK: - UI

struct ContentView : View {
  @EnvironmentObject var store: Store<Counter, Counter.Action>
  var body: some View {
    Text("counter \(store.model.count)").tapAction {
      DispatchStore.dispatch(action: Counter.Action.increase)
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

# Advanced use

Dispatch takes advantage of *Operations* and *OperationQueues* and you can define complex dependencies between the operations that are going to be run on your store.

Also middleware support is available allowing you to quickly add some aspect-oriented feature to your design.

### Middleware

Any object that conforms to the `Middleware` protocol can register to `ActionDispatch`.
This provides a third-party extension point between dispatching an action, and the moment it reaches the reducer. You could use middleware for logging, crash reporting, talking to an asynchronous API, routing, and more.

```swift

protocol Middleware {
  func willDispatch(transaction: String, action: AnyAction, in store: AnyStore)
  func didDispatch(transaction: String, action: AnyAction, in store: AnyStore)
}

class Logger: Middleware { ... }

```
Register your middleware by calling `register(middleware:)`.

```swift
DispatchStore.default.register(middleware: LoggerMiddleware())
```

### Chaining actions

You can make sure that an action will be dispatched right after another one by using the `dispatch` method trailing closure.

```swift
dispatch(action: Action.foo) {
  dispatch(action: Action.bar)
}
```

Similarly you can achieve the same result by dispatching the two actions serially.

```swift
dispatch(action: Action.foo, mode: .serial)
dispatch(action: Action.bar, mode: .serial)
```

Also calling dispatch with `.sync` would have the same effect but it would block the thread that is currently dispatching the action until the operation is done - so make sure you dispatch your actions in `.sync` mode only if you are off the main thread.
