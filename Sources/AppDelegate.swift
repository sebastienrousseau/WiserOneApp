// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//  AppDelegate.swift
//  The Wiser One
//
//  Created by Sebastien Rousseau on 27/01/2024.
//

import Cocoa

// Enum for error descriptions
enum AppError: Error {
    case statusBarItemButtonNotAvailable
    case popoverSetupFailed(message: String)
    case contentUpdateFailed(message: String)
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try setupStatusBarItem()
            setupPopover()
        } catch {
            handleError(error)
        }
    }

    private func createCircularAttributedString(for string: String) -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: 10)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.textColor
        ]

        let attributedString = NSAttributedString(string: string, attributes: attributes)
        let textSize = attributedString.size()
        let diameter = textSize.height + 10

        let circleSize = CGSize(width: diameter, height: diameter)

        let circleImage = NSImage(size: circleSize)
        circleImage.lockFocus()

        let borderColor = NSColor.labelColor
        borderColor.set()
        let path = NSBezierPath(ovalIn: NSRect(origin: CGPoint.zero, size: circleSize).insetBy(dx: 1, dy: 1))
        path.lineWidth = 1.0
        path.stroke()

        let textRect = CGRect(x: (diameter - textSize.width) / 2, y: (diameter - textSize.height) / 2, width: textSize.width, height: textSize.height)
        attributedString.draw(in: textRect)

        circleImage.unlockFocus()

        let attachment = NSTextAttachment()
        attachment.image = circleImage

        let attachmentString = NSMutableAttributedString(attributedString: NSAttributedString(attachment: attachment))

        let offset = (font.capHeight - diameter) / 2.0
        attachmentString.addAttribute(.baselineOffset, value: offset, range: NSRange(location: 0, length: attachmentString.length))

        return attachmentString
    }

    private func setupStatusBarItem() throws {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusBarItem?.button else {
            throw AppError.statusBarItemButtonNotAvailable
        }

        let day = "\(Calendar.current.component(.day, from: Date()))"
        let attributedTitle = createCircularAttributedString(for: day)
        button.attributedTitle = attributedTitle
        button.action = #selector(togglePopover(_:))
    }

    private func setupPopover() {
        popover = NSPopover()
        updatePopoverContent(with: QuoteViewController())
    }

    private func updatePopoverContent(with viewController: NSViewController) {
        popover?.contentViewController = viewController
        popover?.contentSize = viewController.view.frame.size
    }

    @objc private func togglePopover(_ sender: Any?) {
        if let button = statusBarItem?.button {
            if popover?.isShown == true {
                closePopover(sender)
            } else {
                showPopover(from: button)
            }
        }
    }

    private func showPopover(from view: NSView) {
        popover?.show(relativeTo: view.bounds, of: view, preferredEdge: NSRectEdge.minY)
        popover?.contentViewController?.view.window?.makeKey()
    }

    private func closePopover(_ sender: Any?) {
        popover?.performClose(sender)
    }

    private func handleError(_ error: Error) {
        ErrorLogger.shared.logError(error)

        switch error {
        case AppError.statusBarItemButtonNotAvailable:
            print("Status bar item button not available")
        case let AppError.popoverSetupFailed(message):
            print("Popover setup failed: \(message)")
        case let AppError.contentUpdateFailed(message):
            print("Content update failed: \(message)")
        default:
            break
        }
    }
}
