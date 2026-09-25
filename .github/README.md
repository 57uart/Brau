# mnml

A minimal web browser for the Mac, built on WebKit.

mnml is a personal project, made for my own use. You're welcome to build it and use it yourself.

mnml is a fork of [Search](https://github.com/driceroland/Search) by [Office Commun](https://officecommun.com), kept in step with it, with a few things added:

- Tab groups in the sidebar, named for you by Apple Intelligence
- Split view: two tabs side by side
- ⌃Tab switches between tabs in the order you last used them
- Tab previews on hover, and peek for links from pinned tabs
- Custom keyboard shortcuts
- Tabs sleep when idle, and a guard for pages that use too much memory
- Touch ID for 1Password

## Build

macOS 14 or later, with the Xcode command-line tools.

```sh
./build.sh release install
```

## Feedback

[Open an issue](https://github.com/farchanrifai/mnml/issues).

## Credit

Search is by Office Commun. mnml keeps its license; see [LICENSE](../LICENSE).
