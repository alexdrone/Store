# <img src="Doc/logo.png" alt="Buffer" />

[![Swift](https://img.shields.io/badge/swift-3-orange.svg?style=flat)](#)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Platform](https://img.shields.io/badge/platform-ios|macos|tvos|watchos-lightgrey.svg?style=flat)](#)
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](https://opensource.org/licenses/MIT)

Swift μ-framework for efficient array diffs, collection observation and data source implementation.
[(Swift 2.3 branch here)](https://github.com/alexdrone/Buffer/tree/swift_2_3)

[C++11 port here](https://github.com/alexdrone/libbuffer)


## Installation
If you are using **CocoaPods**:


Add the following to your [Podfile](https://guides.cocoapods.org/using/the-podfile.html):

```ruby
pod 'Buffer', '~> 1.1'
```

If you are using **Carthage**:


To install Carthage, run (using Homebrew):

```bash
$ brew update
$ brew install carthage
```


Then add the following line to your `Cartfile`:

```
github "alexdrone/Buffer" "master"    
```


# Getting started

Buffer is designed to be very granular and has APIs with very different degrees of abstraction.

### Managing a collection with Buffer

You can initialize and use **Buffer** in the following way.

```swift

import Buffer

class MyClass: BufferDelegate {

  lazy var buffer: Buffer<Foo> = {
    // The `sort` and the `filter` closure are optional - they are a convenient way to map the src array.
    let buffer = Buffer(initialArray: self.elements, sort: { $0.bar > $1.bar }, filter: { $0.isBaz })
    buffer.delegate = self
  }()

  var elements: [Foo] = [Foo]() {
    didSet {
      // When the elements are changed the buffer object will compute the difference and trigger
      // the invocation of the delegate methods.
      // The `synchronous` and `completion` arguments are optional.
      self.buffer.update(with: newValues, synchronous: false, completion: nil)
    }
  }


  //These methods will be called when the buffer has changedd.

  public func buffer(willChangeContent buffer: BufferType) {
    //e.g. self.tableView?.beginUpdates()

  }

  public func buffer(didDeleteElementAtIndices buffer: BufferType, indices: [UInt]) {
    //e.g. Remove rows from a tableview
  }

  public func buffer(didInsertElementsAtIndices buffer: BufferType, indices: [UInt]) {
  }

  public func buffer(didChangeContent buffer: BufferType) {
  }

  public func buffer(didChangeElementAtIndex buffer: BufferType, index: UInt) {
  }

  public func buffer(didChangeAllContent buffer: BufferType) {
  }
}

```

### Tracking Keypaths

If your model is KVO-compliant, you can pass an array of keypaths to your buffer object.
When one of the observed keypath changes for one of the items managed by your buffer object, the sort and the filter closures are re-applied (on a background thread), the diff is computed and the delegate methods called.

```swift
buffer.trackKeyPaths(["foo", "bar.baz"])
```

### Built-in UITableView and UICollectionView adapter

One of the main use cases for **Buffer** is probably to apply changes to a TableView or a CollectionView.
**Buffer** provides 2 adapter classes that implement the `BufferDelegate` protocol and automatically perform the required
changes on the target tableview/collectionview when required.

```swift

import Buffer

class MyClass: UITableViewController {

  lazy var buffer: Buffer<Foo> = {
    // The `sort` and the `filter` closure are optional - they are convenient way to map the src array.
    let buffer = Buffer(initialArray: self.elements, sort: { $0.bar > $1.bar }, filter: { $0.isBaz })
    buffer.delegate = self
  }()

  var elements: [Foo] = [Foo]() {
    didSet {
      // When the elements are changed the buffer object will compute the difference and trigger
      // the invocation of the delegate methods.
      // The `synchronous` and `completion` arguments are optional.
      self.buffer.update(with: newValues, synchronous: false, completion: nil)
    }
  }

  let adapter: TableViewDiffAdapter<Foo>!

  init() {
    super.init()
    self.adapter = TableViewDiffAdapter(buffer: self.buffer, view: self.tableView)

    // Additionaly you can let the adapter be the datasource for your table view by passing a cell
    // configuration closure to the adpater.
    adapter.useAsDataSource { (tableView, object, indexPath) -> UITableViewCell in
      let cell = tableView.dequeueReusableCellWithIdentifier("MyCell")
	  			cell?.textLabel?.text = object.foo
	  			return cell
    }
  }
  
}


```

### Component-Oriented TableView

Another convenient way to use **Buffer** is through the `Buffer.TableView` class.
This abstraction allows for the tableView to reconfigure itself when its state (the elements) change.

```swift

import Buffer

class ViewController: UIViewController {

  lazy var tableView: TableView<FooModel> = {
    let tableView = TableView<FooModel>()
    return tableView
  }()

  lazy var elements: [AnyListItem<FooModel>] = {
    var elements = [AnyListItem<FooModel>]()
    for _ in 0...100 {
      // AnyListItem wraps the data and the configuration for every row in the tableview.
      let item = AnyListItem(type: UITableViewCell.self,
                             referenceView: self.tableView,
                             state: FooModel(text: "Foo"))) {
                              cell, state in
                              guard let cell = cell as? UITableViewCell else { return }
                              cell.textLabel?.text = state.text
      }
      elements.append(item)
    }
    return elements
  }()

  override func viewDidLayoutSubviews() {
    self.tableView.frame = self.view.bounds
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.addSubview(self.tableView)
    self.tableView.elements = self.elements
  }
}


```

Check the demo out to learn more about Buffer.

### Credits

- The LCS algorithm implementation is forked from [Dwifft](https://github.com/jflinter/Dwifft) by Jack Flintermann.

