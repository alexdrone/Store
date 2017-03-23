import UIKit
import Buffer

func ==(lhs: FooModel, rhs: FooModel) -> Bool {
  return lhs.text == rhs.text
}

struct FooModel: Equatable {
  let text: String
}

class ViewController: UIViewController, UITableViewDelegate {

  lazy var tableView: TableView<FooModel> = {
    let tableView = TableView<FooModel>()
    tableView.delegate = self
    return tableView
  }()

  lazy var elements: [AnyListItem<FooModel>] = {
    var elements = [AnyListItem<FooModel>]()
    for _ in 0...100 {
      let item = AnyListItem(type: UITableViewCell.self,
                             referenceView: self.tableView,
                             state: FooModel(text: (Lorem.sentences(1)))) { cell, state in
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

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let tableView = tableView as? TableView<FooModel> else {
      return
    }
    var newElements = tableView.elements
    newElements.remove(at: (indexPath as NSIndexPath).row)
    tableView.elements = newElements
  }
}





