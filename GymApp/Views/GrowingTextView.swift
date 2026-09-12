import SwiftUI
import UIKit

// MARK: - Growing Text View with Caret Auto-Scrolling

struct GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var minHeight: CGFloat = 80
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var tintColor: UIColor? = nil

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.font = font
        textView.textColor = .label
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        if let tintColor {
            textView.tintColor = tintColor
        }

        setupInputAccessoryView(for: textView, tintColor: tintColor)
        context.coordinator.setupPlaceholder(in: textView, placeholder: placeholder)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.placeholder = placeholder
        if let tintColor {
            uiView.tintColor = tintColor
            if let toolbar = uiView.inputAccessoryView as? UIToolbar {
                toolbar.tintColor = tintColor
            }
        }
        if uiView.text != text {
            uiView.text = text
            context.coordinator.updatePlaceholderVisibility(in: uiView)
            uiView.invalidateIntrinsicContentSize()
        }

        DispatchQueue.main.async {
            if let scrollView = uiView.findParentScrollView() {
                scrollView.keyboardDismissMode = .onDrag
            }
        }
    }

    private func setupInputAccessoryView(for textView: UITextView, tintColor: UIColor?) {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.barStyle = .default
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneImage = UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(weight: .semibold))
        let doneButton = UIBarButtonItem(image: doneImage, style: .plain, target: textView, action: #selector(UIView.endEditing(_:)))
        if let tintColor {
            toolbar.tintColor = tintColor
            doneButton.tintColor = tintColor
        }
        toolbar.items = [flexSpace, doneButton]
        toolbar.sizeToFit()
        textView.inputAccessoryView = toolbar
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let targetSize = CGSize(width: width, height: .greatestFavoringHeight)
        let calculatedSize = uiView.sizeThatFits(targetSize)
        let height = max(minHeight, calculatedSize.height)
        return CGSize(width: width, height: height)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, placeholder: placeholder)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        var placeholder: String
        private weak var placeholderLabel: UILabel?

        init(text: Binding<String>, placeholder: String) {
            self._text = text
            self.placeholder = placeholder
        }

        func setupPlaceholder(in textView: UITextView, placeholder: String) {
            let label = UILabel()
            label.text = placeholder
            label.font = textView.font
            label.textColor = .tertiaryLabel
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            textView.addSubview(label)

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 0),
                label.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: 0),
                label.topAnchor.constraint(equalTo: textView.topAnchor, constant: 8),
            ])
            self.placeholderLabel = label
            updatePlaceholderVisibility(in: textView)
        }

        func updatePlaceholderVisibility(in textView: UITextView) {
            placeholderLabel?.isHidden = !textView.text.isEmpty
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
            updatePlaceholderVisibility(in: textView)
            textView.invalidateIntrinsicContentSize()
            scrollCaretToVisible(in: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            scrollCaretToVisible(in: textView)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if let scrollView = textView.findParentScrollView() {
                scrollView.keyboardDismissMode = .onDrag
            }
            scrollCaretToVisible(in: textView)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.scrollCaretToVisible(in: textView)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.scrollCaretToVisible(in: textView)
            }
        }

        private func scrollCaretToVisible(in textView: UITextView) {
            guard let selectedRange = textView.selectedTextRange else { return }
            let caretRect = textView.caretRect(for: selectedRange.end)
            guard !caretRect.isNull && !caretRect.isInfinite && caretRect.height > 0 else { return }

            guard let scrollView = textView.findParentScrollView() else { return }

            let caretInScrollView = textView.convert(caretRect, to: scrollView)
            let targetRect = caretInScrollView.insetBy(dx: 0, dy: -30)

            scrollView.scrollRectToVisible(targetRect, animated: false)
        }
    }
}

// MARK: - Scroll View Keyboard Dismiss Modifier

struct ScrollViewKeyboardDismissModifier: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            if let scrollView = view.findParentScrollView() {
                scrollView.keyboardDismissMode = .onDrag
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let scrollView = uiView.findParentScrollView() {
                scrollView.keyboardDismissMode = .onDrag
            }
        }
    }
}

extension View {
    func dismissKeyboardOnScroll() -> some View {
        self.background(ScrollViewKeyboardDismissModifier())
    }
}

private extension CGFloat {
    static let greatestFavoringHeight: CGFloat = 10_000
}

private extension UIView {
    func findParentScrollView() -> UIScrollView? {
        var parent: UIView? = self.superview
        while parent != nil {
            if let scrollView = parent as? UIScrollView {
                return scrollView
            }
            parent = parent?.superview
        }
        return nil
    }
}
