import SwiftUI

@main
struct ExamplesApp: App {
    var body: some Scene {
        WindowGroup {
          NavigationView {
            Sidebar()
          }
        }
    }
}

// MARK: - Shared Design elements.

struct AccentButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.subheadline)
      .padding()
      .background(Color.accentColor)
      .foregroundColor(.white)
      .clipShape(Capsule())
  }
}

struct DestructiveButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.subheadline)
      .padding()
      .background(Color.red)
      .foregroundColor(.white)
      .clipShape(Capsule())
  }
}
