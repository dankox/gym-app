import SwiftUI
import UIKit

// MARK: - Sheet Dismiss Interceptor

struct SheetDismissInterceptor: UIViewRepresentable {
    var hasUnsavedChanges: Bool
    var onAttemptToDismiss: (CGPoint?) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.hasUnsavedChanges = hasUnsavedChanges
        context.coordinator.onAttemptToDismiss = onAttemptToDismiss

        DispatchQueue.main.async {
            guard let presentedVC = uiView.findPresentedViewController() else { return }

            presentedVC.isModalInPresentation = hasUnsavedChanges
            if let nav = presentedVC.navigationController {
                nav.isModalInPresentation = hasUnsavedChanges
            }

            let pc = presentedVC.navigationController?.presentationController ?? presentedVC.presentationController
            if pc?.delegate !== context.coordinator {
                pc?.delegate = context.coordinator
            }

            context.coordinator.attachPanGestureIfNeeded(to: presentedVC.view)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(hasUnsavedChanges: hasUnsavedChanges, onAttemptToDismiss: onAttemptToDismiss)
    }

    class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate, UIGestureRecognizerDelegate {
        var hasUnsavedChanges: Bool
        var onAttemptToDismiss: (CGPoint?) -> Void
        var lastTouchLocation: CGPoint?
        private weak var attachedView: UIView?

        init(hasUnsavedChanges: Bool, onAttemptToDismiss: @escaping (CGPoint?) -> Void) {
            self.hasUnsavedChanges = hasUnsavedChanges
            self.onAttemptToDismiss = onAttemptToDismiss
        }

        func attachPanGestureIfNeeded(to view: UIView) {
            guard attachedView !== view else { return }
            attachedView = view

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.delegate = self
            pan.cancelsTouchesInView = false
            view.addGestureRecognizer(pan)
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            if let view = gesture.view {
                lastTouchLocation = gesture.location(in: view)
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }

        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            return !hasUnsavedChanges
        }

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            if hasUnsavedChanges {
                let location = lastTouchLocation
                onAttemptToDismiss(location)
            }
        }
    }
}

private extension UIView {
    func findPresentedViewController() -> UIViewController? {
        var parentResponder: UIResponder? = self
        while let responder = parentResponder {
            if let vc = responder as? UIViewController {
                var current: UIViewController = vc
                while let parent = current.parent {
                    current = parent
                }
                return current
            }
            parentResponder = responder.next
        }
        return nil
    }
}

// MARK: - Unsaved Changes Dialog View Modifier

struct UnsavedChangesOverlayModifier: ViewModifier {
    @Binding var isPresented: Bool
    var location: CGPoint?
    var canSave: Bool = true
    var onSave: () -> Void
    var onDiscard: () -> Void

    @Environment(ThemeManager.self) private var themeManager

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                GeometryReader { geometry in
                    let cardY: CGFloat = {
                        if let location {
                            return min(max(location.y, 220), geometry.size.height - 200)
                        } else {
                            return geometry.size.height - 220
                        }
                    }()

                    ZStack {
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isPresented = false
                                }
                            }

                        VStack(spacing: 16) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.title3)
                                Text("Unsaved Changes")
                                    .font(.headline)
                            }

                            Text("You have unsaved changes. Would you like to save them or discard them?")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 4)

                            VStack(spacing: 10) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isPresented = false
                                    }
                                    onSave()
                                } label: {
                                    Text("Save")
                                        .font(.body.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(canSave ? themeManager.accentColor : Color.gray)
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isPresented = false
                                    }
                                    onDiscard()
                                } label: {
                                    Text("Discard Changes")
                                        .font(.body.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.red.opacity(0.12))
                                        .foregroundStyle(.red)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isPresented = false
                                    }
                                } label: {
                                    Text("Keep Editing")
                                        .font(.body.weight(.medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
                        .padding(.horizontal, 28)
                        .position(x: geometry.size.width / 2, y: cardY)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
            }
        }
    }
}

extension View {
    func unsavedChangesOverlay(
        isPresented: Binding<Bool>,
        location: CGPoint?,
        canSave: Bool = true,
        onSave: @escaping () -> Void,
        onDiscard: @escaping () -> Void
    ) -> some View {
        self.modifier(
            UnsavedChangesOverlayModifier(
                isPresented: isPresented,
                location: location,
                canSave: canSave,
                onSave: onSave,
                onDiscard: onDiscard
            )
        )
    }
}
