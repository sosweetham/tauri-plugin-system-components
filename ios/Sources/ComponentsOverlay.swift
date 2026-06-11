//
//  ComponentsOverlay.swift
//  tauri-plugin-liquid-glass
//
//  Generic native overlay components (switch, button, slider, progress,
//  image) floated over the webview, optionally inside a glass capsule.
//  On iOS 26 glass is the real UIGlassEffect / glass button configurations;
//  earlier systems get material blur / filled buttons.
//

import UIKit
import WebKit

class ComponentPropsArgs: Decodable {
    let label: String?
    let on: Bool?
    let value: Double?
    let min: Double?
    let max: Double?
    let sfSymbol: String?
    let image: String?
    let circular: Bool?
    let glass: Bool?
    let prominent: Bool?
    let tint: String?
    let width: Double?
    let height: Double?
    /// Top-left position in CSS points, for `absolute` placement.
    let x: Double?
    let y: Double?
    /// Corner radius for `glass` panels.
    let cornerRadius: Double?
}

class CreateComponentArgs: Decodable {
    let id: String
    let kind: String
    let props: ComponentPropsArgs?
    let anchor: String?
    let dx: Double?
    let dy: Double?
    /// Insert below the (transparent) webview so DOM content renders sharp
    /// on top while the view shows through unpainted page regions.
    let below: Bool?
}

class UpdateComponentArgs: Decodable {
    let id: String
    let props: ComponentPropsArgs
}

class RemoveComponentArgs: Decodable {
    let id: String
}

/// Covers the host view but only claims touches landing on a managed
/// component — everything else falls through to the webview.
final class ComponentsPassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}

final class ComponentsOverlayController: UIViewController {
    private var components: [String: (container: UIView, control: UIView)] = [:]
    /// (id, event, on, value)
    var onEvent: ((String, String, Bool?, Double?) -> Void)?

    override func loadView() {
        let v = ComponentsPassthroughView()
        v.backgroundColor = .clear
        view = v
    }

    var isEmpty: Bool { components.isEmpty }

    // MARK: creation

    func create(_ args: CreateComponentArgs, webView: WKWebView?) {
        remove(id: args.id)
        let props = args.props
        guard let control = makeControl(kind: args.kind, id: args.id, props: props) else {
            return
        }

        var container = control
        if props?.glass ?? false {
            container = wrapInGlassCapsule(control)
        }

        let anchor = args.anchor ?? "topTrailing"
        if args.below ?? false, let webView, let parent = webView.superview {
            // Below the webview: make the webview transparent so unpainted
            // DOM regions reveal the native view (barcode-scanner pattern).
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.scrollView.backgroundColor = .clear
            parent.insertSubview(container, belowSubview: webView)
            placeByFrame(container, in: parent, anchor: anchor, props: props)
        } else if anchor == "absolute" || anchor == "fill" {
            view.addSubview(container)
            placeByFrame(container, in: view, anchor: anchor, props: props)
        } else {
            container.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(container)
            activateAnchorConstraints(
                for: container,
                anchor: anchor,
                dx: CGFloat(args.dx ?? 0),
                dy: CGFloat(args.dy ?? 0)
            )
            if let w = props?.width {
                control.widthAnchor.constraint(equalToConstant: CGFloat(w)).isActive = true
            }
            if let h = props?.height {
                control.heightAnchor.constraint(equalToConstant: CGFloat(h)).isActive = true
            }
        }
        components[args.id] = (container, control)
    }

    /// Frame-based placement (UIKit coordinates match CSS: y from the top).
    private func placeByFrame(
        _ container: UIView, in parent: UIView, anchor: String, props: ComponentPropsArgs?
    ) {
        if anchor == "fill" {
            container.frame = parent.bounds
            container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        } else {
            container.frame = CGRect(
                x: props?.x ?? 0,
                y: props?.y ?? 0,
                width: props?.width ?? 200,
                height: props?.height ?? 120
            )
        }
    }

    private func makeControl(kind: String, id: String, props: ComponentPropsArgs?) -> UIView? {
        switch kind {
        case "switch":
            let control = UISwitch()
            control.isOn = props?.on ?? false
            if let tint = props?.tint.flatMap(Self.color(fromHex:)) {
                control.onTintColor = tint
            }
            control.addAction(
                UIAction { [weak self, weak control] _ in
                    self?.onEvent?(id, "change", control?.isOn, nil)
                }, for: .valueChanged)
            return control

        case "button":
            var config: UIButton.Configuration
            if #available(iOS 26.0, *) {
                config = (props?.prominent ?? false)
                    ? UIButton.Configuration.prominentGlass()
                    : UIButton.Configuration.glass()
            } else {
                config = (props?.prominent ?? false)
                    ? UIButton.Configuration.filled()
                    : UIButton.Configuration.gray()
            }
            config.title = props?.label
            if let b64 = props?.image, let decoded = ImageUtil.decode(b64) {
                config.image = ImageUtil.icon(
                    decoded, side: 20, circular: props?.circular ?? false)
                config.imagePadding = 6
            } else if let symbol = props?.sfSymbol {
                config.image = UIImage(systemName: symbol)
                config.imagePadding = 6
            }
            if let tint = props?.tint.flatMap(Self.color(fromHex:)) {
                config.baseBackgroundColor = tint
            }
            let control = UIButton(configuration: config)
            control.addAction(
                UIAction { [weak self] _ in
                    self?.onEvent?(id, "click", nil, nil)
                }, for: .touchUpInside)
            return control

        case "slider":
            let control = UISlider()
            control.minimumValue = Float(props?.min ?? 0)
            control.maximumValue = Float(props?.max ?? 1)
            control.value = Float(props?.value ?? 0)
            if let tint = props?.tint.flatMap(Self.color(fromHex:)) {
                control.tintColor = tint
            }
            control.addAction(
                UIAction { [weak self, weak control] _ in
                    self?.onEvent?(id, "change", nil, control.map { Double($0.value) })
                }, for: .valueChanged)
            if props?.width == nil {
                // UISlider has no intrinsic width.
                control.widthAnchor.constraint(equalToConstant: 160).isActive = true
            }
            return control

        case "progress":
            let control = UIProgressView(progressViewStyle: .default)
            control.progress = Float(props?.value ?? 0)
            if let tint = props?.tint.flatMap(Self.color(fromHex:)) {
                control.progressTintColor = tint
            }
            return control

        case "image":
            let side = CGFloat(props?.width ?? props?.height ?? 48)
            let control = UIImageView()
            control.contentMode = .scaleAspectFill
            control.clipsToBounds = true
            if props?.circular ?? false {
                control.layer.cornerRadius = side / 2
            }
            if let b64 = props?.image, let decoded = ImageUtil.decode(b64) {
                control.image = decoded
            }
            return control

        case "glass":
            // A bare glass panel — real UIGlassEffect on iOS 26, material
            // blur before that. Pair with below+absolute to back DOM cards.
            let effect: UIVisualEffect
            if #available(iOS 26.0, *) {
                let glassEffect = UIGlassEffect()
                if let tint = props?.tint.flatMap(ColorUtil.from(hex:)) {
                    glassEffect.tintColor = tint
                }
                effect = glassEffect
            } else {
                effect = UIBlurEffect(style: .systemMaterial)
            }
            let control = UIVisualEffectView(effect: effect)
            control.clipsToBounds = true
            control.layer.cornerRadius = CGFloat(props?.cornerRadius ?? 18)
            return control

        default:
            return nil
        }
    }

    // MARK: updates

    func update(id: String, props: ComponentPropsArgs) -> Bool {
        guard let (container, control) = components[id] else { return false }
        // Geometry updates (DOM scroll/resize sync).
        if props.x != nil || props.y != nil || props.width != nil || props.height != nil {
            var frame = container.frame
            if let w = props.width { frame.size.width = CGFloat(w) }
            if let h = props.height { frame.size.height = CGFloat(h) }
            if let x = props.x { frame.origin.x = CGFloat(x) }
            if let y = props.y { frame.origin.y = CGFloat(y) }
            container.frame = frame
        }
        if let toggle = control as? UISwitch, let on = props.on {
            toggle.setOn(on, animated: true)
        }
        if let slider = control as? UISlider, let value = props.value {
            slider.setValue(Float(value), animated: true)
        }
        if let progress = control as? UIProgressView, let value = props.value {
            progress.setProgress(Float(value), animated: true)
        }
        if let button = control as? UIButton {
            var config = button.configuration
            if let label = props.label {
                config?.title = label
            }
            if let b64 = props.image, let decoded = ImageUtil.decode(b64) {
                config?.image = ImageUtil.icon(
                    decoded, side: 20, circular: props.circular ?? false)
            }
            button.configuration = config
        }
        if let imageView = control as? UIImageView, let b64 = props.image,
            let decoded = ImageUtil.decode(b64)
        {
            imageView.image = decoded
        }
        return true
    }

    func remove(id: String) {
        if let (container, _) = components.removeValue(forKey: id) {
            container.removeFromSuperview()
        }
    }

    // MARK: layout helpers

    private func wrapInGlassCapsule(_ control: UIView) -> UIView {
        let effect: UIVisualEffect
        if #available(iOS 26.0, *) {
            effect = UIGlassEffect()
        } else {
            effect = UIBlurEffect(style: .systemMaterial)
        }
        let capsule = UIVisualEffectView(effect: effect)
        capsule.clipsToBounds = true
        capsule.layer.cornerRadius = 24
        control.translatesAutoresizingMaskIntoConstraints = false
        capsule.contentView.addSubview(control)
        NSLayoutConstraint.activate([
            control.leadingAnchor.constraint(equalTo: capsule.contentView.leadingAnchor, constant: 14),
            control.trailingAnchor.constraint(equalTo: capsule.contentView.trailingAnchor, constant: -14),
            control.topAnchor.constraint(equalTo: capsule.contentView.topAnchor, constant: 10),
            control.bottomAnchor.constraint(equalTo: capsule.contentView.bottomAnchor, constant: -10),
        ])
        return capsule
    }

    private func activateAnchorConstraints(
        for container: UIView, anchor: String, dx: CGFloat, dy: CGFloat
    ) {
        let guide = view.safeAreaLayoutGuide
        let margin: CGFloat = 16
        var constraints: [NSLayoutConstraint] = []
        switch anchor {
        case "topLeading":
            constraints = [
                container.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: margin + dx),
                container.topAnchor.constraint(equalTo: guide.topAnchor, constant: margin + dy),
            ]
        case "bottomLeading":
            constraints = [
                container.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: margin + dx),
                container.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -(margin + dy)),
            ]
        case "bottomTrailing":
            constraints = [
                container.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -(margin + dx)),
                container.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -(margin + dy)),
            ]
        case "center":
            constraints = [
                container.centerXAnchor.constraint(equalTo: guide.centerXAnchor, constant: dx),
                container.centerYAnchor.constraint(equalTo: guide.centerYAnchor, constant: dy),
            ]
        default:  // topTrailing
            constraints = [
                container.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -(margin + dx)),
                container.topAnchor.constraint(equalTo: guide.topAnchor, constant: margin + dy),
            ]
        }
        NSLayoutConstraint.activate(constraints)
    }

    private static func color(fromHex hex: String) -> UIColor? {
        ColorUtil.from(hex: hex)
    }
}
