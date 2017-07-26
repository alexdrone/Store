# Dispatch [![Swift](https://img.shields.io/badge/swift-3.1-orange.svg?style=flat)](#) [![Platform](https://img.shields.io/badge/platform-ios|macos|tvos|watchos-lightgrey.svg?style=flat)](#)
 [![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](https://opensource.org/licenses/MIT)

<img src="https://raw.githubusercontent.com/alexdrone/Dispatch/master/docs/dispatch_logo_small.png" width=150 alt="Dispatch" align=right />

Dispatch is a lightweight, operation based, multi-store Flux implementation in Swift.

### Installation

If you are using **CocoaPods**:


Add the following to your [Podfile](https://guides.cocoapods.org/using/the-podfile.html):

```ruby
pod 'DispatchStore', '~> 0.3'
```

If you are using **Carthage**:


To install Carthage, run (using Homebrew):

```bash
$ brew update
$ brew install carthage
```

Then add the following line to your `Cartfile`:

```
github "alexdrone/Dispatch" "master"    
```

## Overview

**Dispatch** is a [Flux](https://facebook.github.io/flux/docs/overview.html)-like implementation of the unidirectional data flow architecture in Swift.
Flux applications have three major parts: the dispatcher, the stores, and the views.

These should not be confused with Model-View-Controller. Controllers do exist in a Dispatch/Flux application, but they are controller-views — views often found at the top of the hierarchy that retrieve data from the stores and pass this data down to their children (views). 

Dispatch eschews MVC in favour of a unidirectional data flow. When a user interacts with a view, the view propagates an action through a central dispatcher, to the various stores that hold the application's data and business logic, which updates all of the views that are affected. 

This works especially well with [Render](https://github.com/alexdrone/Render)'s declarative programming style, which allows the store to send updates without specifying how to transition views between states.


- **Stores**: Holds the state of your application. You can have multiple stores for multiple domains of your app.
- **Actions**: You can only perform state changes through actions. Actions are small pieces of data (typically enums) that describe a state change. By drastically limiting the way state can be mutated, your app becomes easier to understand and it gets easier to work with many collaborators.
- **Dispatcher**: Dispatches an action to the stores that respond to it.
- **Views**: A simple function of your state. This works especially well with [Render](https://github.com/alexdrone/Render)'s declarative programming style.

<img src="https://raw.githubusercontent.com/alexdrone/Dispatch/master/docs/diag.png" width="640" alt="Diagram" />

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


### Y NO Redux Implementation?

*Redux* can be seen as a special *Dispatch* use-case.
You can recreate a Redux configuration by having a single store registered to the Dispatcher and by ensuring state immutability in your store.

# Getting started

Let's implement a counter application in **Dispatch**.

First we need a `Counter` state and some actions associated to it.


```swift

struct Counter: StateType {

  let count: Int

  init() {
    self.count = 0
  }

  init(count: Int) {
    self.count = count
  }
  
  // In this example we are implementing Counter as an immutable state, but Dispatch is
  // not opinionated about state immutability.
  // We could have 'count' as a var and simply change its value in the reducer.
  func byAdding(value: Int) -> Counter {
    return Counter(count: self.count + value)
  }

  enum Action: ActionType {
    case increase
    case decrease
    case add(amount: Int)
    case remove(amount: Int)
  }
}

```

Now we need a `Reducer` that implements the business logic for the actions defined in `Counter.Action`.
The reducer will have to change the state (that is owned by the  `Store`) and to do that in a synchronised fashion we use the `updateState(closure:)` function.


```swift
class CounterReducer: Reducer<Counter, Counter.Action> {

  override func operation(for action: Counter.Action, 
                          in store: Store<Counter, Counter.Action>) -> ActionOperation<Counter, Counter.Action> {

    switch action {

    case .increase:
      return ActionOperation(action: action, store: store) { operation, _, store in
        store.updateState { state in
          // In this example we are implementing our state as an immutable state (a la Redux) - but 
          // 'Dispatch' is not opinionated about it.
          // We could simply mutate our state by simply doing 'state.count += 1'. 
          // State immutability is a trade-off left to the user of this library.
          state = state.byAdding(value: 1)
        }
        operation.finish()
      }

    case .decrease:
      return ActionOperation(action: action, store: store) { operation, _, store in
        store.updateState { state in state = state.byAdding(value: -1) }
        operation.finish()
      }

      ...
    }
  }
}
```

Now let's see how to instantiate a `Store` with our newly defined `Reducer` and how to register it to the default `Dispatcher`.


```swift
let store = Store<Counter, Counter.Action>(identifier: "counter", reducer: CounterReducer())
Dispatcher.default.register(store: store)
```

Dispatching an action is as easy as calling:

```swift
Dispatcher.default.dispatch(Counter.Action.increase)
```

Any object can register themselves as a observer for a given store by calling `register(observer:callback:)`.

```swift
store.register(observer: self) { state, _ in
  print(state)
}
```

A convenient way to have type-safe references to all of your stores is to expose them as a synthesised getter in your `Dispatcher`.
That way you have a centralised unique entry-point to access all of your stores.

```swift

extension Dispatcher {
  var counterStore: Store<Counter, Counter.Action> {
    return self.store(with: "counter") as? Store<Counter, Counter.Action>
  }
}

```

# Advanced use

Dispatch takes advantage of *Operations* and *OperationQueues* and you can define complex dependencies between the operations that are going to be run on your store.

Also middleware support is available allowing you to quickly add some aspect-oriented feature to your design.

### Middleware

Any object that conforms to the `Middleware` protocol can register to the `Dispatcher`.
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
Dispatcher.default.register(middleware: LoggerMiddleware())
```

#### Recorder

The recorder middleware is probably one of the most interesting feature of Dispatch.

Register your recorder by calling:

```swift
Dispatcher.default.register(middleware: RecorderMiddleware())
```

Voilà, **if your states are immutable** you simply have to press `⌘+P` to navigate back through your past states and `⌘+N` to move forward again.
Try it in the **TodoApp** demo!

# <img src="https://raw.githubusercontent.com/alexdrone/Dispatch/master/docs/record.gif" width="720" alt="Recorder" />


### Chaining actions

You can make sure that an action will be dispatched right after another one by using the `dispatch` method trailing closure.

```swift
Dispatcher.default.dispatch(action: Action.foo) {
  Dispatcher.default.dispatch(action: Action.bar)
}
```

Similarly you can achieve the same result by dispatching the two actions serially.

```swift
Dispatcher.default.dispatch(action: Action.foo, mode: .serial)
Dispatcher.default.dispatch(action: Action.bar, mode: .serial)
```

Also calling dispatch with `.sync` would have the same effect but it would block the thread that is currently dispatching the action until the operation is done - so make sure you dispatch your actions in `.sync` mode only if you are off the main thread.

### Use with Render

Views in this model are simple function of your state. This works especially well with [Render](https://github.com/alexdrone/Render)'s declarative programming style.

Checkout the **TodoApp** example to see how to get the best out of **Dispatch** and **Render**.

### Credit

- [Facebook Flux](https://facebook.github.io/flux/)
- [Unbox](https://github.com/JohnSundell/Unbox) and [Wrap](https://github.com/JohnSundell/Wrap) by John Sundell are used as json decoder/encoder.

