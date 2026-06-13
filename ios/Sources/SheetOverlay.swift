//
//  SheetOverlay.swift
//  tauri-plugin-liquid-glass
//
//  A native bottom sheet (UISheetPresentationController — real detents,
//  grabber, drag-to-dismiss) whose rows are rendered natively from data the
//  web app passes. On iOS 26 the sheet sits on a Liquid Glass background; on
//  older systems a material blur. Row taps report back to JS via the plugin
//  event channel so the web app drives the action (navigate, log out, …).
//

import UIKit

/// One row in a native sheet.
struct SheetRow {
    let id: String
    let label: String
    let detail: String?
    let image: UIImage?
    let sfSymbol: String?
    let badge: String?
    let destructive: Bool
    /// A non-tappable header row (e.g. the account identity), rendered larger.
    let isHeader: Bool
}

final class SheetController: UIViewController, UITableViewDataSource, UITableViewDelegate,
    UIAdaptivePresentationControllerDelegate
{
    var rows: [SheetRow] = []
    var tint: UIColor?
    /// (rowId) — a tappable row was selected.
    var onSelect: ((String) -> Void)?
    /// The sheet was dismissed by the user (swipe / tap-away).
    var onDismissed: (() -> Void)?

    private let table = UITableView(frame: .zero, style: .insetGrouped)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let effect: UIVisualEffect = {
            if #available(iOS 26.0, *) { return UIGlassEffect() }
            return UIBlurEffect(style: .systemThickMaterial)
        }()
        let glass = UIVisualEffectView(effect: effect)
        glass.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(glass)

        table.translatesAutoresizingMaskIntoConstraints = false
        table.backgroundColor = .clear
        table.dataSource = self
        table.delegate = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "row")
        if let tint { table.tintColor = tint }
        view.addSubview(table)

        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: view.topAnchor),
            glass.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            glass.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.topAnchor.constraint(equalTo: view.topAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    // MARK: UITableViewDataSource / Delegate

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = rows[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
        cell.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.4)

        var config = cell.defaultContentConfiguration()
        config.text = row.label
        config.secondaryText = row.detail
        if let image = row.image {
            config.image = image
        } else if let symbol = row.sfSymbol {
            config.image = UIImage(systemName: symbol)
        }
        config.imageProperties.maximumSize = CGSize(
            width: row.isHeader ? 40 : 24, height: row.isHeader ? 40 : 24)
        if row.destructive {
            config.textProperties.color = .systemRed
            config.imageProperties.tintColor = .systemRed
        } else {
            config.imageProperties.tintColor = row.isHeader ? .label : .secondaryLabel
        }
        if row.isHeader {
            config.textProperties.font = .preferredFont(forTextStyle: .headline)
            config.secondaryTextProperties.color = .secondaryLabel
        }
        cell.contentConfiguration = config

        if let badge = row.badge {
            let label = PaddedLabel()
            label.text = badge
            label.font = .systemFont(ofSize: 12, weight: .semibold)
            label.textColor = .white
            label.backgroundColor = tint ?? .systemBlue
            label.layer.cornerRadius = 10
            label.clipsToBounds = true
            label.sizeToFit()
            cell.accessoryView = label
        } else {
            cell.accessoryView = nil
            cell.accessoryType = row.isHeader ? .none : .disclosureIndicator
        }
        cell.selectionStyle = row.isHeader ? .none : .default
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = rows[indexPath.row]
        guard !row.isHeader else { return }
        onSelect?(row.id)
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismissed?()
    }
}

/// A small pill label for row badges (intrinsic size padded horizontally).
private final class PaddedLabel: UILabel {
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + 14, height: 20)
    }
    override func sizeThatFits(_ size: CGSize) -> CGSize { intrinsicContentSize }
}
