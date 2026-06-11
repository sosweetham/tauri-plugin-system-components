//
//  LiquidGlassPlugin.swift
//  tauri-plugin-liquid-glass
//
//  Mounts a native UITabBar (Liquid Glass on iOS 26) over the Tauri webview
//  and forwards tab selection to JS via the plugin event channel
//  (`addPluginListener('liquid-glass', 'tabSelected', …)`).
//
//  Commands arrive on Tauri's ipc queue; all UIKit work hops to the main
//  queue (same pattern as the official plugins).
//

import Foundation
import Tauri
import UIKit
import WebKit

class TabItemArgs: Decodable {
    let id: String
    let title: String
    let sfSymbol: String?
    /// Bitmap icon as base64 (raw or data: URL) — e.g. a user avatar.
    /// Takes precedence over sfSymbol.
    let image: String?
    /// Clip the bitmap to a circle (avatar style).
    let circular: Bool?
    let badge: String?
}

class ConfigureTabBarArgs: Decodable {
    let items: [TabItemArgs]
    let selectedId: String?
    /// Hex accent color — applied as UITabBar.tintColor (selected item).
    let tint: String?
}

class SelectTabArgs: Decodable {
    let id: String
}

class SetBadgeArgs: Decodable {
    let id: String
    let value: String?
}

class LiquidGlassPlugin: Plugin {
    private var overlay: TabBarOverlayController?
    private var componentsOverlay: ComponentsOverlayController?
    private var webView: WKWebView?

    @objc public override func load(webview: WKWebView) {
        self.webView = webview
    }

    @objc public func configureTabBar(_ invoke: Invoke) throws {
        let args = try invoke.parseArgs(ConfigureTabBarArgs.self)
        guard !args.items.isEmpty else {
            invoke.reject("configureTabBar requires at least one item")
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let host = self.manager.viewController else {
                invoke.reject("host view controller unavailable")
                return
            }
            // Idempotent: reconfiguring updates the mounted bar in place.
            let overlay = self.overlay ?? self.mount(on: host)
            overlay.apply(items: args.items, selectedId: args.selectedId)
            overlay.tabBar.tintColor = args.tint.flatMap(ColorUtil.from(hex:))
            invoke.resolve()
        }
    }

    @objc public func removeTabBar(_ invoke: Invoke) {
        DispatchQueue.main.async { [weak self] in
            if let overlay = self?.overlay {
                overlay.willMove(toParent: nil)
                overlay.view.removeFromSuperview()
                overlay.removeFromParent()
                self?.overlay = nil
            }
            invoke.resolve()
        }
    }

    @objc public func showTabBar(_ invoke: Invoke) {
        setHidden(false, invoke)
    }

    @objc public func hideTabBar(_ invoke: Invoke) {
        setHidden(true, invoke)
    }

    @objc public func selectTab(_ invoke: Invoke) throws {
        let args = try invoke.parseArgs(SelectTabArgs.self)
        DispatchQueue.main.async { [weak self] in
            guard let overlay = self?.overlay else {
                invoke.reject("tab bar is not configured")
                return
            }
            if overlay.select(id: args.id) {
                invoke.resolve()
            } else {
                invoke.reject("unknown tab id: \(args.id)")
            }
        }
    }

    @objc public func setBadge(_ invoke: Invoke) throws {
        let args = try invoke.parseArgs(SetBadgeArgs.self)
        DispatchQueue.main.async { [weak self] in
            guard let overlay = self?.overlay else {
                invoke.reject("tab bar is not configured")
                return
            }
            if overlay.setBadge(id: args.id, value: args.value) {
                invoke.resolve()
            } else {
                invoke.reject("unknown tab id: \(args.id)")
            }
        }
    }

    @objc public func createComponent(_ invoke: Invoke) throws {
        let args = try invoke.parseArgs(CreateComponentArgs.self)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let host = self.manager.viewController else {
                invoke.reject("host view controller unavailable")
                return
            }
            let overlay = self.componentsOverlay ?? self.mountComponents(on: host)
            overlay.create(args, webView: self.webView)
            invoke.resolve()
        }
    }

    @objc public func updateComponent(_ invoke: Invoke) throws {
        let args = try invoke.parseArgs(UpdateComponentArgs.self)
        DispatchQueue.main.async { [weak self] in
            guard let overlay = self?.componentsOverlay, overlay.update(id: args.id, props: args.props)
            else {
                invoke.reject("unknown component: \(args.id)")
                return
            }
            invoke.resolve()
        }
    }

    @objc public func updateComponents(_ invoke: Invoke) throws {
        let args = try invoke.parseArgs(UpdateComponentsArgs.self)
        DispatchQueue.main.async { [weak self] in
            if let overlay = self?.componentsOverlay {
                for item in args.components {
                    _ = overlay.update(id: item.id, props: item.props)
                }
            }
            invoke.resolve()
        }
    }

    @objc public func removeComponent(_ invoke: Invoke) throws {
        let args = try invoke.parseArgs(RemoveComponentArgs.self)
        DispatchQueue.main.async { [weak self] in
            self?.componentsOverlay?.remove(id: args.id)
            invoke.resolve()
        }
    }

    @objc public func getTabBarInsets(_ invoke: Invoke) {
        DispatchQueue.main.async { [weak self] in
            let bottom = self?.overlay?.bottomInset ?? 0
            invoke.resolve(["bottom": Double(bottom)])
        }
    }

    private func setHidden(_ hidden: Bool, _ invoke: Invoke) {
        DispatchQueue.main.async { [weak self] in
            guard let overlay = self?.overlay else {
                invoke.reject("tab bar is not configured")
                return
            }
            UIView.transition(
                with: overlay.view, duration: 0.25, options: .transitionCrossDissolve
            ) {
                overlay.tabBar.isHidden = hidden
            }
            invoke.resolve()
        }
    }

    /// Adds the overlay as a child VC of the webview's host VC. The overlay's
    /// root view is a touch-passthrough covering the host view, so the bar
    /// tracks rotation/safe-area while the webview stays interactive.
    private func mount(on host: UIViewController) -> TabBarOverlayController {
        let overlay = TabBarOverlayController()
        overlay.onSelect = { [weak self] id in
            self?.trigger("tabSelected", data: ["id": id])
        }
        host.addChild(overlay)
        overlay.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(overlay.view)
        NSLayoutConstraint.activate([
            overlay.view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            overlay.view.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            overlay.view.topAnchor.constraint(equalTo: host.view.topAnchor),
            overlay.view.bottomAnchor.constraint(equalTo: host.view.bottomAnchor),
        ])
        overlay.didMove(toParent: host)
        self.overlay = overlay
        return overlay
    }

    /// Adds the components overlay as a child VC of the webview's host VC,
    /// same pattern as the tab bar.
    private func mountComponents(on host: UIViewController) -> ComponentsOverlayController {
        let overlay = ComponentsOverlayController()
        overlay.onEvent = { [weak self] id, event, on, value in
            var data: JSObject = ["id": id, "event": event]
            if let on { data["on"] = on }
            if let value { data["value"] = value }
            self?.trigger("componentEvent", data: data)
        }
        host.addChild(overlay)
        overlay.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(overlay.view)
        NSLayoutConstraint.activate([
            overlay.view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            overlay.view.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            overlay.view.topAnchor.constraint(equalTo: host.view.topAnchor),
            overlay.view.bottomAnchor.constraint(equalTo: host.view.bottomAnchor),
        ])
        overlay.didMove(toParent: host)
        self.componentsOverlay = overlay
        return overlay
    }
}

@_cdecl("init_plugin_liquid_glass")
func initPlugin() -> Plugin {
    return LiquidGlassPlugin()
}
