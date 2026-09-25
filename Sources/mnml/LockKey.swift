import AppKit
import Security
import WebKit

// Touch ID for 1Password's popup.
//
// 1Password's own Touch ID goes through its Mac app, which trusts only
// browsers it can place by their signature — a paid Developer ID, which
// mnml doesn't have (its helper waits for an approval that never comes, and
// the popup spins). So mnml does the part it can: the first time you unlock
// 1Password by typing its password, it offers to keep that password in this
// Mac's keychain; from then on, 1Password's lock screen in the popup is met
// with Touch ID, and the password is typed in for you.
//
// The password is kept in the data protection keychain behind Touch ID (or
// the Mac's password): macOS itself asks before every read, so nothing —
// mnml included — gets it without you. That keychain needs the access group
// only a copy signed with mnml's provisioning profile has; any other copy has
// nowhere safe to keep it, and there nothing is watched, offered or kept.
// Settings › Passwords forgets it.

@MainActor
enum LockKey {
    /// 1Password's extensions: the ones its desktop app lists for Chrome
    /// and Edge — the release, the beta, and older ones.
    static let extensions: Set<String> = [
        "aeblfdkhhhdcdjpifhhbdiojplfjncoa", "khgocmkkpikpnmmkgmdnfckapcdkgfaf", "gejiddohjgogedgjnonbofjigllpkmbf",
        "hjlinigoblmkhjejkmbegnoaljkphmgo", "bkpbhnjcbehoklfkljkkbbmipaphipgl", "dppgmdbiimibapkepcbdbmkaabgiofem",
    ]

    /// Asked never to offer again.
    static var declined: Bool {
        get { Store.settings.bool(forKey: "lockKey.declined") }
        set { Store.settings.set(newValue, forKey: "lockKey.declined") }
    }

    // MARK: the popup

    /// Watches a 1Password popup for its lock screen while it is up.
    static func watch(_ web: WKWebView, extensionID: String) {
        dropUnprotected()
        guard extensions.contains(extensionID), available else { return }
        var tried = false
        var filledAt: Date?
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak web] timer in
            MainActor.assumeIsolated {
                guard let web, web.window != nil || web.superview != nil else { timer.invalidate(); return }
                web.evaluateJavaScript(probe) { result, _ in
                    MainActor.assumeIsolated {
                        guard let text = result as? String,
                              let state = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
                        else { return }
                        let locked = state["locked"] as? Bool ?? false
                        if locked {
                            // Still locked long after the password went in: it
                            // was changed in 1Password. Forgotten, so the next
                            // one typed can be kept instead.
                            if let at = filledAt, Date().timeIntervalSince(at) > 10 {
                                forget()
                                filledAt = nil
                            }
                            guard !tried, kept else { return }
                            tried = true
                            // macOS asks for Touch ID as the item is read, off
                            // the main thread: the read waits for the answer.
                            Task.detached(priority: .userInitiated) {
                                guard let password = read() else { return }
                                await MainActor.run {
                                    filledAt = Date()
                                    web.evaluateJavaScript(fill(password))
                                }
                            }
                        } else if let typed = state["typed"] as? String, !typed.isEmpty, !kept {
                            // Unlocked by hand, with the password just typed.
                            timer.invalidate()
                            offer(typed)
                        } else if filledAt != nil {
                            timer.invalidate()
                        }
                    }
                }
            }
        }
    }

    /// Whether the lock screen is up, and — once it isn't — what was typed
    /// into its password field meanwhile.
    private static let probe = """
    (() => {
      const button = document.querySelector('[data-testid="lock-screen-submit-button"]');
      let scope = button && (button.closest('form') || button.parentElement);
      for (let i = 0; scope && i < 4 && !scope.querySelector('input[type=password]'); i++) scope = scope.parentElement;
      const field = scope && scope.querySelector('input[type=password]');
      if (field && !window.__mnmlLockKey) {
        window.__mnmlLockKey = true;
        document.addEventListener('input', (e) => {
          const t = e.target;
          if (t && t.type === 'password' && document.querySelector('[data-testid="lock-screen-submit-button"]')) window.__mnmlTyped = t.value;
        }, true);
      }
      const typed = field ? null : (window.__mnmlTyped || null);
      if (!field) window.__mnmlTyped = null;
      return JSON.stringify({ locked: !!field, typed });
    })()
    """

    /// The password into the lock screen's field, the way typing would put
    /// it — React reads the value through the native setter — and the
    /// form sent.
    private static func fill(_ password: String) -> String {
        let quoted = (try? String(data: JSONSerialization.data(withJSONObject: [password]), encoding: .utf8)) ?? "[\"\"]"
        return """
        ((pw) => {
          const button = document.querySelector('[data-testid="lock-screen-submit-button"]');
          let scope = button && (button.closest('form') || button.parentElement);
          for (let i = 0; scope && i < 4 && !scope.querySelector('input[type=password]'); i++) scope = scope.parentElement;
          const field = scope && scope.querySelector('input[type=password]');
          if (!field) return 'gone';
          field.focus();
          Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(field, pw);
          field.dispatchEvent(new Event('input', { bubbles: true }));
          field.dispatchEvent(new Event('change', { bubbles: true }));
          setTimeout(() => {
            const go = document.querySelector('[data-testid="lock-screen-submit-button"]');
            if (go && !go.disabled) go.click(); else if (field.form) field.form.requestSubmit();
          }, 60);
          return 'filled';
        })(\(quoted)[0])
        """
    }

    /// Once, after a password typed by hand unlocked 1Password.
    private static func offer(_ typed: String) {
        guard !declined, available, !kept else { return }
        let alert = NSAlert()
        alert.messageText = "Unlock 1Password with Touch ID?"
        alert.informativeText = "mnml keeps your 1Password password in this Mac's keychain and types it in for you after Touch ID. Settings › Passwords forgets it."
        alert.addButton(withTitle: "Use Touch ID")
        alert.addButton(withTitle: "Not Now")
        alert.addButton(withTitle: "Never")
        switch alert.runModal() {
        case .alertFirstButtonReturn: keep(typed)
        case .alertThirdButtonReturn: declined = true
        default: break
        }
    }

    // MARK: the keychain

    private nonisolated static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecUseDataProtectionKeychain as String: true,
         kSecAttrService as String: Store.testing ? "mnml 1Password unlock (test)" : "mnml 1Password unlock",
         kSecAttrAccount as String: "1Password"]
    }

    /// Whether this copy has somewhere to keep it: the data protection
    /// keychain, under mnml's own access group. Asked by writing, not by
    /// reading — without the group a read only says "not found", and it is
    /// a write that is refused — with an item made and removed at once.
    static let available: Bool = {
        let probe: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrService as String: "mnml 1Password unlock (probe)",
            kSecAttrAccount as String: "probe",
        ]
        var item = probe
        item[kSecValueData as String] = Data()
        let status = SecItemAdd(item as CFDictionary, nil)
        SecItemDelete(probe as CFDictionary)
        return status == errSecSuccess || status == errSecDuplicateItem
    }()

    /// Whether one is kept. Only its attributes are asked for, which needs
    /// no Touch ID: the password itself is never read to find out.
    static var kept: Bool {
        guard available else { return false }
        var asked = query
        asked[kSecReturnAttributes as String] = true
        return SecItemCopyMatching(asked as CFDictionary, nil) == errSecSuccess
    }

    /// The password, once macOS has had Touch ID or the Mac's password.
    /// Blocks while it asks, so never on the main thread.
    private nonisolated static func read() -> String? {
        var asked = query
        asked[kSecReturnData as String] = true
        asked[kSecUseOperationPrompt as String] = "unlock 1Password"
        var found: AnyObject?
        guard SecItemCopyMatching(asked as CFDictionary, &found) == errSecSuccess,
              let data = found as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func keep(_ password: String) {
        guard available,
              let guarded = SecAccessControlCreateWithFlags(
                nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .userPresence, nil
              )
        else { return }
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = Data(password.utf8)
        item[kSecAttrLabel as String] = "mnml — 1Password unlock"
        item[kSecAttrAccessControl as String] = guarded
        SecItemAdd(item as CFDictionary, nil)
    }

    static func forget() {
        SecItemDelete(query as CFDictionary)
        dropUnprotected()
    }

    /// What earlier builds kept in the login keychain with nothing in front
    /// of it: removed, not moved — the next unlock by hand offers again.
    private static func dropUnprotected() {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Store.testing ? "mnml 1Password unlock (test)" : "mnml 1Password unlock",
            kSecAttrAccount as String: "1Password",
        ] as CFDictionary)
    }
}
