import Foundation

public protocol ListContainerView: class { }
public protocol ListViewCell: class { }

#if os(iOS)
  import UIKit
  extension UITableView: ListContainerView { }
  extension UICollectionView: ListContainerView { }
  extension UITableViewCell: ListViewCell { }
  extension UICollectionViewCell: ListViewCell { }
#endif

public func ==<Type>(lhs: AnyListItem<Type>, rhs: AnyListItem<Type>) -> Bool {
  return lhs.reuseIdentifier == rhs.reuseIdentifier && lhs.state == rhs.state
}

public struct AnyListItem<Type: Equatable>: Equatable {

  /** The reuse identifier for the cell passed as argument. */
  public var reuseIdentifier: String

  /** The actual item data. */
  public var state: Type

  /** The TableView, or the CollectionView that will own this element. */
  public let referenceView: ListContainerView?

  public var cellConfiguration: ((ListViewCell, Type) -> Void)?

  #if os(iOS)
  public init<V: PrototypeViewCell>(
      type: V.Type,
      referenceView: ListContainerView,
      reuseIdentifer: String = String(describing: V.self),
      state: Type,
      configurationClosure: ((ListViewCell, Type) -> Void)? = nil) {

    // registers the prototype cell if necessary.
    if !Prototypes.isPrototypeCellRegistered(reuseIdentifer) {
      let cell = V(reuseIdentifier: reuseIdentifer)
      Prototypes.registerPrototypeCell(reuseIdentifer, cell: cell)
    }

    self.reuseIdentifier = reuseIdentifer
    self.cellConfiguration = configurationClosure
    self.referenceView = referenceView
    self.state = state
    self.registerReferenceView(with: type)
  }
  #endif

  public init<V: ListViewCell>(
      type: V.Type,
      referenceView: ListContainerView? = nil,
      reuseIdentifer: String = String(describing: V.self),
      state: Type,
      configurationClosure: ((ListViewCell, Type) -> Void)? = nil) {

    self.reuseIdentifier = reuseIdentifer
    self.cellConfiguration = configurationClosure
    self.referenceView = referenceView
    self.state = state
    self.registerReferenceView(with: type)
  }

  fileprivate func registerReferenceView(with cellClass: AnyClass) {
    #if os(iOS)
      if let tableView = self.referenceView as? UITableView {
        tableView.register(cellClass,
                                forCellReuseIdentifier: self.reuseIdentifier)
      }
      if let collectionView = self.referenceView as? UICollectionView {
        collectionView.register(cellClass,
                                     forCellWithReuseIdentifier: self.reuseIdentifier)
      }
    #endif
  }
}
