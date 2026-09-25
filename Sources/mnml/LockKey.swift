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
// The password is read only after Touch ID (or the Mac's password), as the
// passwords mnml keeps itself are. Settings › Passwords forgets it.

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
        guard extensions.contains(extensionID) else { return }
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
                            guard !tried, let kept = read() else { return }
                            tried = true
                            Vault.prove("unlock 1Password") { ok in
                                guard ok else { return }
                                filledAt = Date()
                                web.evaluateJavaScript(fill(kept))
                            }
                        } else if let typed = state["typed"] as? String, !typed.isEmpty, typed != read() {
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
        guard !declined, read() == nil else { return }
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

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: Store.testing ? "mnml 1Password unlock (test)" : "mnml 1Password unlock",
         kSecAttrAccount as String: "1Password"]
    }

    static var kept: Bool { read() != nil }

    private static func read() -> String? {
        var asked = query
        asked[kSecReturnData as String] = true
        var found: AnyObject?
        guard SecItemCopyMatching(asked as CFDictionary, &found) == errSecSuccess,
              let data = found as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func keep(_ password: String) {
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = Data(password.utf8)
        item[kSecAttrLabel as String] = "mnml — 1Password unlock"
        SecItemAdd(item as CFDictionary, nil)
    }

    static func forget() {
        SecItemDelete(query as CFDictionary)
    }
}
