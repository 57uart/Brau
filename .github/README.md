# Brau

A small, fast web browser for the Mac, built on WebKit.

Brau is a fork of [mnml](https://github.com/farchanrifai/mnml) by farchan, itself a fork of [Search](https://github.com/driceroland/Search) by [Office Commun](https://officecommun.com). It keeps everything mnml added:

- Tab groups in the sidebar, named for you on the Mac by Apple Intelligence
- Split view: two tabs side by side
- ⌃Tab switches between tabs in the order you last used them
- Tab previews on hover, and peek for links from pinned tabs
- Custom keyboard shortcuts
- Tabs sleep when idle, and a guard for pages that use too much memory
- Close tabs above or below

On top of mnml, Brau fixes four security problems:

- **1Password's password is stored only behind Touch ID, or not at all.** mnml kept it as an ordinary keychain password that the app read without asking. Brau keeps it only where macOS asks for Touch ID or your Mac password before every read.
- **The "Brau Test" copy is a separate browser of its own, not a test run.** It keeps its own data, but it no longer skips the safeguards test runs skip: the automation socket's consent, and real passkeys.
- **Extensions write the clipboard only with Chrome's `clipboardWrite` permission.** Without it, an extension can't silently replace what you copied.
- **Only a test run can point the updater at another feed.**

## No paid developer account

Brau can be built and signed without a paid Apple Developer account: with a free or self-made certificate, and not notarized. What that means:

- **1Password Touch ID** needs somewhere macOS will guard with Touch ID, the data-protection keychain. That requires a build signed with a provisioning profile. Without one the feature stays off, and 1Password's own lock screen works as usual.
- **Passkeys** need Apple's passkey entitlement, which needs a paid account. Until then, passkeys go through password-manager extensions.
- **Opening it the first time:** macOS may warn that it can't check the app. Right-click it in Applications and choose Open.
- **Updates** are off. Build again to update.

## Build

macOS 14 or later, with the Xcode command-line tools.

```sh
./build.sh release install
```

## Feedback

[Open an issue](https://github.com/57uart/Brau/issues). To report a security problem, see [SECURITY.md](../SECURITY.md).

## Credit

Search is by Office Commun, and mnml is by farchan. Brau keeps their license; see [LICENSE](../LICENSE).
