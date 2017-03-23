#if os(iOS)
import UIKit

open class CollectionViewDiffAdapter<ElementType: Equatable>:
    NSObject, AdapterType, UICollectionViewDataSource {

  public typealias `Type` = ElementType
  public typealias ViewType = UICollectionView

  open fileprivate(set) var buffer: Buffer<ElementType>

  open fileprivate(set) weak var view: ViewType?

  /** Right now this only works on a single section of a collectionView.
   *  If your collectionView has multiple sections, though, you can just use multiple
   *  CollectionViewDiffAdapter, one per section, and set this value appropriately on each one.
   */
  open var sectionIndex: Int = 0

  public required init(buffer: BufferType, view: ViewType) {
    guard let buffer = buffer as? Buffer<ElementType> else {
      fatalError()
    }
    self.buffer = buffer
    self.view = view
    super.init()
    self.buffer.delegate = self
  }

  public required init(initialElements: [ElementType], view: ViewType) {
    self.buffer = Buffer(initialArray: initialElements)
    self.view = view
    super.init()
    self.buffer.delegate = self
  }

  fileprivate var indexPaths: (insertion: [IndexPath], deletion: [IndexPath]) = ([], [])

  fileprivate var cellForItemAtIndexPath: ((UICollectionView, ElementType, IndexPath)
    -> UICollectionViewCell)? = nil

  /** Returns the element currently on the front buffer at the given index path. */
  open func displayedElement(at index: Int) -> ElementType {
    return self.buffer.currentElements[index]
  }

  /** The total number of elements currently displayed. */
  open func countDisplayedElements() -> Int {
    return self.buffer.currentElements.count
  }

  /** Replace the elements buffer and compute the diffs.
   *  - parameter newValues: The new values.
   *  - parameter synchronous: Wether the filter, sorting and diff should be executed
   *  synchronously or not.
   *  - parameter completion: Code that will be executed once the buffer is updated.
   */
  open func update(with newValues: [ElementType]? = nil,
                   synchronous: Bool = false,
                   completion: ((Void) -> Void)? = nil) {
    self.buffer.update(with: newValues, synchronous: synchronous, completion: completion)
  }

  /** Configure the TableView to use this adapter as its DataSource.
   *  - parameter automaticDimension: If you wish to use 'UITableViewAutomaticDimension'
   *  as 'rowHeight'.
   *  - parameter estimatedHeight: The estimated average height for the cells.
   *  - parameter cellForRowAtIndexPath: The closure that returns a cell for the given
   *  index path.
   */
  open func useAsDataSource(_ cellForItemAtIndexPath:
    @escaping (UICollectionView, ElementType, IndexPath) -> UICollectionViewCell) {
    self.view?.dataSource = self
    self.cellForItemAtIndexPath = cellForItemAtIndexPath
  }

  /** Tells the data source to return the number of rows in a given section of a table view. */
  open func collectionView(_ collectionView: UICollectionView,
                             numberOfItemsInSection section: Int) -> Int {
    return self.buffer.currentElements.count
  }

  /** Asks the data source for a cell to insert in a particular location of the table view. */
  open func collectionView(_ collectionView: UICollectionView,
                           cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    return self.cellForItemAtIndexPath!(
        collectionView, self.buffer.currentElements[(indexPath as NSIndexPath).row], indexPath)
  }
}

extension CollectionViewDiffAdapter: BufferDelegate {

  /** Notifies the receiver that the content is about to change. */
  public func buffer(willChangeContent buffer: BufferType) {
    self.indexPaths = ([], [])
  }

  /** Notifies the receiver that rows were deleted. */
  public func buffer(didDeleteElementAtIndices buffer: BufferType, indices: [UInt]) {
    self.indexPaths.deletion = indices.map({
      IndexPath(row: Int($0), section: self.sectionIndex)
    })
  }

  /** Notifies the receiver that rows were inserted. */
  public func buffer(didInsertElementsAtIndices buffer: BufferType, indices: [UInt]) {
    self.indexPaths.insertion = indices.map({
      IndexPath(row: Int($0), section: self.sectionIndex)
    })
  }

  /** Notifies the receiver that the content updates has ended. */
  public func buffer(didChangeContent buffer: BufferType) {
    self.view?.performBatchUpdates({
      self.view?.insertItems(at: self.indexPaths.insertion)
      self.view?.deleteItems(at: self.indexPaths.deletion)
      }, completion: nil)
  }

  /** Called when one of the observed properties for this object changed. */
  public func buffer(didChangeElementAtIndex buffer: BufferType, index: UInt) {
    self.view?.reloadItems(
      at: [IndexPath(row: Int(index), section: self.sectionIndex)])
  }

  /** Notifies the receiver that the content updates has ended and the whole array changed. */
  public func buffer(didChangeAllContent buffer: BufferType) {
    self.view?.reloadData()
  }
}

#endif
