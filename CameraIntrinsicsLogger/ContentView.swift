import SwiftUI

struct ContentView: View {
    var body: some View {
        CameraIntrinsicsViewControllerRepresentable()
            .edgesIgnoringSafeArea(.all)
    }
}

// This struct acts as a bridge between SwiftUI and UIKit.
struct CameraIntrinsicsViewControllerRepresentable: UIViewControllerRepresentable {
    
    // Creates and returns the initial instance of our view controller.
    func makeUIViewController(context: Context) -> CameraIntrinsicsViewController {
        return CameraIntrinsicsViewController()
    }
    
    // Updates the view controller. This is not needed for our simple app.
    func updateUIViewController(_ uiViewController: CameraIntrinsicsViewController, context: Context) {
        // No updates are needed for this simple app.
    }
}

