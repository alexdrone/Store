# ＳＴＯＲＥ [![Swift](https://img.shields.io/badge/swift-5.1-orange.svg?style=flat)](#) [![Build Status](https://travis-ci.org/alexdrone/Store.svg?branch=master)](https://travis-ci.org/alexdrone/Store) [![Cov](https://img.shields.io/badge/coverage-53.9%25-blue.svg?style=flat)](#)
<img src="https://raw.githubusercontent.com/alexdrone/Dispatch/master/docs/store_logo.png" width=300 alt="Dispatch" align=right />

Unidirectional, transactional, operation-based Store implementation for Swift and SwiftUI

# Overview

Store eschews MVC in favour of a unidirectional data flow. When a user interacts with a view, the view propagates an action through a central dispatcher, to the various stores that hold the application's data and business logic, which updates all of the views that are affected.

This works especially well with *SwiftUI*'s declarative programming style, which allows the store to send updates without specifying how to transition views between states.

- **Stores**: Holds the state of your application. You can have multiple stores for multiple domains of your app.
- **Actions**: You can only perform state changes through actions. Actions are small pieces of data (typically *enums* or *structs*) that describe a state change. By drastically limiting the way state can be mutated, your app becomes easier to understand and it gets easier to work with many collaborators.
- **Transaction**:  A single execution of an action.
- **Views**: A simple function of your state. This works especially well with *SwiftUI*'s declarative programming style.

### Store

Stores contain the application state and logic. Their role is somewhat similar to a model in a traditional MVC, but they manage the state of many objects — they do not represent a single record of data like ORM models do. More than simply managing a collection of ORM-style objects, stores manage the application state for a particular domain within the application.

This allows an action to result in an update to the state of the store. After the stores are updated, they notify the observers that their state has changed, so the views may query the new state and update themselves.

```swift
struct Counter {
  var count = 0
}

let store = Store<Counter>(model: Counter())
```

### Action

An action represent an operation on the store.

It can be represented using an enum:

```swift
enum CounterAction: ActionProtocol {

  case increase
  case decrease

  var id: String {
    switch self {
    case .increase: return "INCREASE"
    case .decrease: return "DECREASE"
    }
  }

  func reduce(context: TransactionContext<Store<Counter>, Self>) {
    defer {
      // Remember to always call `fulfill` to signal the completion of this operation.
      context.fulfill()
    }
    switch self {
    case .increase(let amount):
      context.reduceModel { $0.count += 1 }
    case .decrease(let amount):
      context.reduceModel { $0.count -= 1 }
    }
  }
}
```

Or a struct:

```swift
struct IncreaseAction: ActionProtocol {
  let count: Int

  var id: String = "INCREASE"

  func reduce(context: TransactionContext<Store<Counter>, Self>) {
    defer {
      // Remember to always call `fulfill` to signal the completion of this operation.
      context.fulfill()
    }
    context.reduceModel { $0.count += 1 }
  }
}
```

### Transaction

A transaction represent an execution of a given action.
The dispatcher can run transaction in three different modes: `async`, `sync`, and `mainThread`.
Additionally the trailing closure of the `run` method can be used to run a completion closure for the actions that have had run.

# Getting started

TL;DR

```swift
import SwiftUI
import Store

struct Counter {
  var count = 0
}

enum CounterAction: ActionProtocol {

  case increase(amount: Int)
  case decrease(amount: Int)

  var id: String {
    switch self {
    case .increase(_): return "INCREASE"
    case .decrease(_): return "DECREASE"
    }
  }

  func reduce(context: TransactionContext<Store<Counter>, Self>) {
    defer {
      context.fulfill()
    }
    switch self {
    case .increase(let amount):
      context.reduceModel { $0.count += amount }
    case .decrease(let amount):
      context.reduceModel { $0.count -= amount }
    }
  }
}

// MARK: - UI

struct ContentView : View {
  @EnvironmentObject var store: Store<Counter>
  var body: some View {
    Text("counter \(store.model.count)").tapAction {
      store.run(action: CounterAction.increase(amount: 1))
    }
  }
}

// MARK: - Preview

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(Store<Counter>(model: Counter()))
    }
}
#endif
```

### Demo projects

* [HackerNews Client](https://github.com/alexdrone/Store/tree/master/Demo/store_hacker_news)
<img src="https://raw.githubusercontent.com/alexdrone/Dispatch/master/docs/store_hacker_news_demo.gif" width=600 alt="hacker_news_demo" align=center />



### Middleware

Middleware objects must conform to:

```swift
public protocol Middleware: class {
  /// A transaction has changed its state.
  func onTransactionStateChange(_ transaction: AnyTransaction)
}
```

And can be registered to a store by calling the `register(middleware:)` method.

```swift
store.register(middleware: MyMiddleware())
```

# Serialization and Diffing

TL;DR

```swift
struct MySerializableModel: Codable {
var count = 0
var label = "Foo"
var nullableLabel: String? = "Bar"
var nested = Nested()
var array: [Nested] = [Nested(), Nested()]
  struct Nested: Codable {
  var label = "Nested struct"
  }
}

let store = SerializableStore(model: TestModel(), diffing: .async)
store.$lastTransactionDiff.sink { diff in
  // diff is a `TransactionDiff` obj containing all of the changes that the last transaction has applied to the store's model.
}
```
A quick look at the  `TransactionDiff` interface:

```swift
public struct TransactionDiff {
  /// The set of (`path`, `value`) that has been **added**/**removed**/**changed**.
  ///
  /// e.g. ``` {
  ///   user/name: <added ⇒ "John">,
  ///   user/lastname: <removed>,
  ///   tokens/1:  <changed ⇒ "Bar">,
  /// } ```
  public let diffs: [FlatEncoding.KeyPath: PropertyDiff]
  /// The identifier of the transaction that caused this change.
  public let transactionId: String
  /// The action that caused this change.
  public let actionId: String
  /// Reference to the transaction that cause this change.
  public var transaction: AnyTransaction
  /// Returns the `diffs` map encoded as **JSON** data.
  public var json: Data
}

/// Represent a property change.
/// A change can be an **addition**, a **removal** or a **value change**.
public enum PropertyDiff {
  case added(new: Codable?)
  case changed(old: Codable?, new: Codable?)
  case removed
}
```

Using a  `SerializableModelType` improves debuggability thanks to the console output for every transaction. e.g.

```
▩ INFO (-LnpwxkPuE3t1YNCPjjD) UPDATE_LABEL [0.045134 ms]
▩ DIFF (-LnpwxkPuE3t1YNCPjjD) UPDATE_LABEL {
    · label: <changed ⇒ (old: Foo, new: Bar)>,
    · nested/label: <changed ⇒ (old: Nested struct, new: Bar)>,
    · nullableLabel: <removed>
  }
```


# Combining Stores

As your app logic grows could be convient to split store into smaller one, still using the same root model.
This can be achieved by using the `makeChildStore(keyPath:)` API.

```swift
struct App {
  struct Todo {
    var name: String = "Untitled"
    var description: String = "N/A"
    var done: Bool = false
  }
  var todos: [Todo] = []
}

// This action targets a Store<Todo>...
struct TodoActionMarkAsDone: ActionProtocol {
  func reduce(context: TransactionContext<Store<App.Todo>, Self>) {
    defer { context.fulfill() }
    context.reduceModel { $0.done = true }
  }
}

// ..While this one the whole collection Store<[Todo]>
struct TodoListActionCreateNew: ActionProtocol {
  let name: String
  let description: String
  func reduce(context: TransactionContext<Store<Array<App.Todo>>, Self>) {
    defer { context.fulfill() }
    let new = Root.Todo(name: name, description: description)
    context.reduceModel {
      $0.append(new)
    }
  }
}

let appModel = App()
let rootStore = Store(model: appModel)

let todoListStore = rootStore.makeChildStore(keyPath: \.todos)
todoListStore.run(action: TodoListActionCreateNew(name: "New", decription: "New"), mode: .sync)

let todoStore = rootStore.makeChildStore(keyPath: \.[0])
todoStore.run(action: TodoActionMarkAsDone(), mode: .sync)
```

This is a good strategy to prevent passing down the whole application store as a dependency when not needed _(e.g. maybe your datasource just need the TodoList store and your cell the single-value Todo store)._ 

# Advanced

Dispatch takes advantage of *Operations* and *OperationQueues* and you can define complex dependencies between the operations that are going to be run on your store.


### Chaining actions

```swift
store.run(actions: [
  CounterAction.increase(amount: 1),
  CounterAction.increase(amount: 1),
  CounterAction.increase(amount: 1),
]) { context in
  // Will be executed after all of the transactions are completed.
}
```
Actions can also be executed in a synchronous fashion.

```swift
store.run(action: CounterAction.increase(amount: 1), strategy: .mainThread)
store.run(action: CounterAction.increase(amount: 1), strategy: .sync)
```

### Complex Dependencies

Dependencies can be expressed using the `runGroup` DSL *(see above)*.


You can form a dependency graph by manually constructing your transactions and use the `depend(on:)` method.

```swift
let t1 = store.transaction(.addItem(cost: 125))
let t2 = store.transaction(.checkout)
let t3 = store.transaction(.showOrdern)
t2.depend(on: [t1])
t3.depend(on: [t2])
[t1, t2, t3].run()
```

### Throttling transactions

Transactions can express a throttle delay.

```swift

func calledOften() {
  store.run(.myAction, throttle: 0.5)
}

```

### Tracking a transaction state

Sometimes it's useful to track the state of a transaction (it might be useful to update the UI state to reflect that).

```swift
store.run(action: CounterAction.increase(amount: 1)).$state.sink { state in
  switch(state) {
  case .pending: ...
  case .started: ...
  case .completed: ...
  }
}
```

### Checking the diff state of a specific property after a transaction

```swift
sink = store.$lastTransactionDiff.sink { diff in
  diff.query { $0.path.to.my.property }.isChanged() // or .isRemoved(), .isAdded()
}
```

### Dealing with errors

```swift
struct IncreaseAction: ActionProtocol {
  let count: Int

  func reduce(context: TransactionContext<Store<Counter>, Self>) {
    // Remember to always call `fulfill` to signal the completion of this operation.
    defer { context.fulfill() }
    // The operation terminates here because an error has been raised in this dispatch group.
    guard !context.rejectOnPreviousError() { else return }
    // Kill the transaction and set TransactionGroupError.lastError.
    guard store.model.count != 42 { context.reject(error: Error("Max count reach") }
    // Business as usual...
    context.reduceModel { $0.count += 1 }
  }
}
```

### Cancellation

```swift
store.run(action: CounterAction.increase(amount: 1))
Dispatcher.main.cancelAllTransactions()

// or with a custom queue.
let queueId = "myCancellableQueue"
Dispatcher.main.registerQueue(id: queueId, queue: OperationQueue())
store.run(action: CounterAction.increase(amount: 1), mode: .async(queueId))
Dispatcher.main.cancelAllTransactions(id: queueId)
```

```
▩ 𝙄𝙉𝙁𝙊 (-Lo4riSWZ3m5v1AvhgOb) INCREASE [✖ canceled]
```

### Combined Stores

Support for children store (similar to Redux `combineStores`).

```swift
struct Root {
  struct Todo {
    var name: String = "Untitled"
    var done: Bool = false
  }
  struct Note {
    var text: String = ""
    var upvotes: Int = 0
  }
  var todo: Todo = Todo()
  var note: Note = Note()
}

/// A child store pointing at the todo model.
var todoStore Store(model: model.todo, combine: CombineStore(
  parent: rootStore, 
  notify: true, 
  merge: .keyPath(keyPath: \.todo)))

extension Root.Todo {
  struct Action_MarkAsDone: ActionProtocol {
    func reduce(context: TransactionContext<Store<Root.Todo>, Self>) {
      defer { context.fulfill() }
      context.reduceModel { $0.done = true }
    }
  }
}

```
