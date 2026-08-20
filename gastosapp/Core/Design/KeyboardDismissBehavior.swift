import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

extension View {
    func keyboardDismissBehavior() -> some View {
        modifier(KeyboardDismissBehaviorModifier())
    }
}

private struct KeyboardDismissBehaviorModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if canImport(UIKit)
        content
            .scrollDismissesKeyboard(.interactively)
            .background(KeyboardDismissInstaller().frame(width: 0, height: 0))
        #else
        content
        #endif
    }
}

#if canImport(UIKit)
private struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeCoordinator() -> KeyboardDismissCoordinator {
        KeyboardDismissCoordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.install(from: uiView)
    }
}

private final class KeyboardDismissCoordinator: NSObject, UIGestureRecognizerDelegate {
    private weak var recognizer: UITapGestureRecognizer?
    private weak var window: UIView?

    deinit {
        removeRecognizer()
    }

    func install(from view: UIView) {
        DispatchQueue.main.async {
            guard let window = view.window, self.window !== window else { return }
            self.removeRecognizer()
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)
            self.recognizer = recognizer
            self.window = window
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let view = touch.view else { return true }
        return !view.isKeyboardInteractiveControl
    }

    @objc private func dismissKeyboard() {
        window?.endEditing(true)
    }

    private func removeRecognizer() {
        guard let recognizer else { return }
        recognizer.view?.removeGestureRecognizer(recognizer)
    }
}

private extension UIView {
    var isKeyboardInteractiveControl: Bool {
        var current: UIView? = self
        while let view = current {
            if view is UITextField || view is UITextView || view is UISearchBar || view is UIControl {
                return true
            }
            current = view.superview
        }
        return false
    }
}
#endif
