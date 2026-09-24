# Roadmap

Every idea and every report about Search, in one place: what is being built
right now, what goes out with the next version, what comes after, and what
is not on the list — each with where it came from. GitHub issues, pull
requests, the emails that reach hello@officecommun.com and the replies on X
all land here.

**The live version is [officecommun.com/search/roadmap](https://officecommun.com/search/roadmap)**:
it changes the moment the work does. This file is a copy of the same list,
written by `./ideas md`. What has shipped is in [CHANGELOG.md](CHANGELOG.md).

Want something that isn't here? [Open an issue](https://github.com/driceroland/Search/issues).
Want to build something that is? Say so on its issue first, so two people
don't build it twice.

## Keeping it whole

The list is only worth something if nothing is missing from it and nothing
in it is stale. Whoever works on Search keeps it that way, with `./ideas`
(`./ideas help` for everything it does):

- **Every new idea or report gets its line the day it arrives**, whatever the
  source: an issue, a pull request, an email, a reply on X, a message.
  `./ideas find` first: if it is already there, `./ideas from ID SOURCE` adds
  the new voice instead of a second line.
- **Say what you're building as you start**: `./ideas start ID "who"`, and
  `./ideas done ID` when it's on main, in the same breath as its line in
  CHANGELOG.md. The page shows both at once.
- **`./ideas check`** compares the list with GitHub: every open issue and pull
  request without its idea, and every idea still to do whose issue or pull
  request is closed. Run it whenever you pick up where someone else left off.
- **`./ideas md`** writes this file again; commit it with the work.
- **Public.** Emails are marked *(email)*, never with a name or an address. A
  security report sent privately never comes here, not even in outline: it
  is fixed, it ships, and only then is it credited in CHANGELOG.md.

## Done, in the next version

- [x] **A certificate is taken on trust only for this Mac itself** On main already; the pull request closes, with thanks, when it ships. *([#165](https://github.com/driceroland/Search/pull/165), [#133](https://github.com/driceroland/Search/issues/133))*
- [x] **A user script's file is read from the extension's own package** On main already; the pull request closes, with thanks, when it ships. *([#198](https://github.com/driceroland/Search/pull/198))*
- [x] **Copy in Passwords asks who you are first** On main already; the pull request closes, with thanks, when it ships. *([#203](https://github.com/driceroland/Search/pull/203))*
- [x] **Links to another app ask first** On main already; the pull request closes, with thanks, when it ships. *([#206](https://github.com/driceroland/Search/pull/206))*
- [x] **Reloading an extension asks before it gets more access** On main already; [#161](https://github.com/driceroland/Search/pull/161) is to be compared with it before it closes. *([#135](https://github.com/driceroland/Search/issues/135), [#161](https://github.com/driceroland/Search/pull/161))*
- [x] **The tab bar folded away with ⌘S comes back on a ground of its own** The page no longer shows through between the tabs.

## Now — fixes for the next update

- [ ] **Bitwarden goes blank after signing in (and for one person doesn't load)** Before signing in it works — popup, WebAssembly, background. Probably fixed by 1Password's worker fix ([#126](https://github.com/driceroland/Search/pull/126)) and the extension storage fix in 1.0.2; needs a real account to confirm. Also asked: a self-hosted Vaultwarden server behind the extension. *(X, email)*
- [ ] **Bitwarden on an Intel Mac says "WebAssembly is not supported"** *([#175](https://github.com/driceroland/Search/issues/175))*
- [ ] **Google's sign-in page flashes and reloads every half second with Proton Pass signed in** Presumed fixed in 1.0.2 by [#126](https://github.com/driceroland/Search/pull/126) and the passkey changes; to confirm with the person who saw it. *(X)*
- [ ] **Vimium C doesn't start** WebKit fails to load its background (Vimium itself works). A fix is waiting in [#170](https://github.com/driceroland/Search/pull/170). *(X, email, [#170](https://github.com/driceroland/Search/pull/170))*
- [ ] **Passkeys under the sign-in field** A site's passkey button brings up the Mac's passkey sheet now; next is the suggestion Safari shows as you click into a sign-in field. *([#17](https://github.com/driceroland/Search/issues/17), X)*
- [ ] **iCloud Passwords** Pairing asks for the code twice ([#217](https://github.com/driceroland/Search/pull/217) fixes the first code); one person says it doesn't work at all, details asked. *([#17](https://github.com/driceroland/Search/issues/17), email ×2, [#217](https://github.com/driceroland/Search/pull/217))*
- [ ] **The window stutters when dragged from one screen to another** Needs a trace recorded on two screens. *(X)*
- [ ] **Search doesn't come to the front when another app (Mail) opens a link in it** *([#95](https://github.com/driceroland/Search/issues/95))*
- [ ] **Media pauses when you switch spaces** *([#74](https://github.com/driceroland/Search/issues/74))*
- [ ] **History is slow to open, stutters as it scrolls, and Escape doesn't close it** *([#67](https://github.com/driceroland/Search/issues/67))*
- [ ] **The Web Inspector open and the window resized: the page goes blank** *([#91](https://github.com/driceroland/Search/issues/91))*
- [ ] **The web process pool is made before the first window** Check whether 1.0.2's launch order already covers it. *([#157](https://github.com/driceroland/Search/issues/157))*
- [ ] **⌘F focuses the back button instead of the find field on some pages** *([#172](https://github.com/driceroland/Search/issues/172))*
- [ ] **A mouse wheel doesn't scroll a page that listens to the wheel itself** A fix is waiting in [#194](https://github.com/driceroland/Search/pull/194). *([#180](https://github.com/driceroland/Search/issues/180), [#194](https://github.com/driceroland/Search/pull/194))*
- [ ] **Wrong icon on some tabs (Meta AI shows Google's G, Swagger UI stays on a letter)** A fix is waiting in [#216](https://github.com/driceroland/Search/pull/216). *([#181](https://github.com/driceroland/Search/issues/181), [#216](https://github.com/driceroland/Search/pull/216))*
- [ ] **The window opens at its default size for an instant, then takes its saved size** A fix is waiting in [#204](https://github.com/driceroland/Search/pull/204). *([#202](https://github.com/driceroland/Search/issues/202), [#204](https://github.com/driceroland/Search/pull/204))*
- [ ] **A content script that runs at document_start can miss the page restored at a hidden launch** *([#199](https://github.com/driceroland/Search/issues/199))*
- [ ] **Address suggestions slow down with a large history** *([#200](https://github.com/driceroland/Search/issues/200))*
- [ ] **Stuttering pages** Details to gather. *([#211](https://github.com/driceroland/Search/issues/211))*
- [ ] **A video put full screen goes black** A fix is waiting in [#220](https://github.com/driceroland/Search/pull/220). *([#220](https://github.com/driceroland/Search/pull/220))*
- [ ] **The floating video misbehaves on some sites** Only part of the picture on Twitch and Netflix, sometimes the player without a picture on YouTube, only some of the time on X; Netflix subtitles disappear from it ([#190](https://github.com/driceroland/Search/pull/190)). *([#123](https://github.com/driceroland/Search/issues/123), email ×2, [#190](https://github.com/driceroland/Search/pull/190))*
- [ ] **Videos stuck muted on some video sites, with nothing to turn the sound on** *([#223](https://github.com/driceroland/Search/issues/223))*
- [ ] **The ad blocker leaves empty spaces on news sites (AS.com)** *([#159](https://github.com/driceroland/Search/issues/159))*
- [ ] **Some pages struggle or crash** grok.com and other chatbot pages; details asked. *(email)*
- [ ] **x.com reloads over and over before signing in** Not reproduced; asked whether extensions are installed. *(email)*
- [ ] **Figma blurs for a moment as you zoom in; LinkedIn's feed and profiles scroll with lag** *(email)*
- [ ] **Spaces sometimes don't switch** *(email)*
- [ ] **A hidden sidebar closes too soon while the pointer is over the extension buttons at its foot** Maybe fixed by [#115](https://github.com/driceroland/Search/pull/115) in 1.0.2; unconfirmed. *(email)*
- [ ] **A middle-click on YouTube links works only some of the time** 1.0.2 added middle-click on links; to confirm there. *(email)*
- [ ] **Extension popups and extension pages don't receive messages from the extension's background in a test run (the offscreen document does)** To check in a window on screen; would matter for popups waiting on the background.
- [ ] **Dragging a pin in the column redraws the whole column each frame, as dragging a tab did before 1.0.2**
- [ ] **The bookmarks popover closes when the hidden sidebar folds (it counts as leaving the sidebar)** A fix is waiting in [#89](https://github.com/driceroland/Search/pull/89). *([#88](https://github.com/driceroland/Search/issues/88), [#89](https://github.com/driceroland/Search/pull/89))*
- [ ] **The Settings sidebar has rounded inner corners** A fix is waiting in [#222](https://github.com/driceroland/Search/pull/222). *([#221](https://github.com/driceroland/Search/issues/221), [#222](https://github.com/driceroland/Search/pull/222))*
- [ ] **The back, forward and reload buttons sit edge to edge** A fix is waiting in [#209](https://github.com/driceroland/Search/pull/209). *([#185](https://github.com/driceroland/Search/issues/185), [#209](https://github.com/driceroland/Search/pull/209))*
- [ ] **⇧⌘C copies the address, but nothing in the app says so** A fix is waiting in [#182](https://github.com/driceroland/Search/pull/182). *([#176](https://github.com/driceroland/Search/issues/176), [#182](https://github.com/driceroland/Search/pull/182))*

## Next — small additions people asked for

- [ ] **Import bookmarks from an exported .html file, the format every browser exports** Only direct import from Chrome, Arc, Brave, Edge and Dia exists. *(email ×2)*
- [ ] **Import from Comet, alongside Chrome, Arc, Brave, Edge and Dia** *(X)*
- [ ] **Import from Helium, Firefox and Zen** Both waiting as pull requests. *([#178](https://github.com/driceroland/Search/pull/178), [#215](https://github.com/driceroland/Search/pull/215))*
- [ ] **A tab switcher with previews (⌃Tab held down)** Off until turned on; Option-Tab asked too, as in AltTab. Waiting on its author to rebase and simplify. *([#24](https://github.com/driceroland/Search/pull/24), X, email)*
- [ ] **Your own keyboard shortcuts, in Settings › Shortcuts** Waiting on its author to rebase and simplify. Editing extension shortcuts belongs with it ([#189](https://github.com/driceroland/Search/issues/189)). *([#36](https://github.com/driceroland/Search/pull/36), [#189](https://github.com/driceroland/Search/issues/189), X)*
- [ ] **⌘R reloads, ⇧⌘R reloads from the network** Waiting in [#179](https://github.com/driceroland/Search/pull/179). *([#171](https://github.com/driceroland/Search/issues/171), [#179](https://github.com/driceroland/Search/pull/179))*
- [ ] **Reduce motion for Search's own interface** Two pull requests do it ([#187](https://github.com/driceroland/Search/pull/187), [#210](https://github.com/driceroland/Search/pull/210)); one is to be picked. *([#186](https://github.com/driceroland/Search/issues/186), [#187](https://github.com/driceroland/Search/pull/187), [#210](https://github.com/driceroland/Search/pull/210))*
- [ ] **A default page zoom for every site, in Settings › General** *([#177](https://github.com/driceroland/Search/pull/177))*
- [ ] **Site search keywords (type a site's keyword, then your search)** *([#188](https://github.com/driceroland/Search/pull/188))*
- [ ] **Address bar commands** A word like "settings" reaches the app itself. *([#212](https://github.com/driceroland/Search/pull/212))*
- [ ] **Hold a back or forward swipe to pick a page from history** *([#191](https://github.com/driceroland/Search/pull/191))*
- [ ] **Tabs opened together don't all load at once** They wait until they're shown. *([#195](https://github.com/driceroland/Search/issues/195), [#196](https://github.com/driceroland/Search/pull/196))*
- [ ] **History keeps different articles and videos from the same site apart** *([#154](https://github.com/driceroland/Search/pull/154))*
- [ ] **⌘W no longer bounces between pins** A pin already put down stays down. *([#125](https://github.com/driceroland/Search/pull/125))*
- [ ] **A link opened from another app never lands among the pins** *([#219](https://github.com/driceroland/Search/issues/219))*
- [ ] **Don't reopen last time's tabs at launch, as a switch** *(email)*
- [ ] **Pins as a list, in rows instead of small squares** Also: site icons on pins without them in the tab list (one setting does both today), and Arc-style pinned rows above New Tab. *([#183](https://github.com/driceroland/Search/issues/183), email ×2)*
- [ ] **Pins shared by every space, plus each space's own, as in Arc** *(email)*
- [ ] **Box Tools** Let app.box.com reach its local helper on this Mac, as Chrome does. The person who asked offered to test a build. *(email)*
- [ ] **1Password with its desktop app** Say in the FAQ that Search is added in 1Password › Settings › Browser › Add Browser.
- [ ] **Intel Macs** One build for both kinds of Mac, only as a change to build.sh, as [#100](https://github.com/driceroland/Search/pull/100) began. *([#46](https://github.com/driceroland/Search/issues/46), X)*

## Later — bigger pieces of work

- [ ] **More of the extension APIs** The side panel, and invisible offscreen documents ([#192](https://github.com/driceroland/Search/pull/192)). *([#12](https://github.com/driceroland/Search/issues/12), X, [#192](https://github.com/driceroland/Search/pull/192))*
- [ ] **Driving Search from an agent (an MCP server over the bench), for automation and testing** An earlier pull request, [#14](https://github.com/driceroland/Search/pull/14), began one. *(X)*
- [ ] **Web push notifications, as far as WebKit lets an app other than Safari have them** *(X)*
- [ ] **Smoother scrolling with a mouse wheel** To look into. *(X)*
- [ ] **Split view** Two tabs or more side by side in one window. *([#173](https://github.com/driceroland/Search/issues/173))*
- [ ] **Faster animations, spaces especially (compared with Zen)** *(email)*
- [ ] **YouTube's ads** They come from youtube.com itself, which the blocker's lists can't tell apart. Whether to go that far is an open question. *([#218](https://github.com/driceroland/Search/issues/218), email)*
- [ ] **Extensions per space** Each space with the extensions it wants, on and off apart from the others. WebKit has one extension controller for the whole app, so this means one per space. Drice's call, 24 Sep: later. *(X)*

## Pull requests to review

- [ ] **The extension update check reads the version from the right place** *([#201](https://github.com/driceroland/Search/pull/201))*
- [ ] **Passwords asks the keychain only about Search's own items** [#205](https://github.com/driceroland/Search/pull/205) builds on it: an http page is offered only what was kept from http. *([#208](https://github.com/driceroland/Search/pull/208), [#205](https://github.com/driceroland/Search/pull/205))*
- [ ] **Pop-ups need a click** *([#207](https://github.com/driceroland/Search/pull/207))*

## Drice's call

- [ ] **A double-click below the tabs opens a new one** *([#162](https://github.com/driceroland/Search/issues/162), [#167](https://github.com/driceroland/Search/pull/167))*
- [ ] **The tab bar or title bar in the page's own colour** *([#158](https://github.com/driceroland/Search/issues/158), [#168](https://github.com/driceroland/Search/pull/168), [#25](https://github.com/driceroland/Search/pull/25))*
- [ ] **A pin goes back to the page it was pinned at when you put it down** *([#141](https://github.com/driceroland/Search/issues/141))*
- [ ] **A dark mode for the site's Search page** *([#51](https://github.com/driceroland/Search/issues/51))*
- [ ] **Detach a tab into its own window** Search has one window, like [#72](https://github.com/driceroland/Search/issues/72). *([#184](https://github.com/driceroland/Search/pull/184), [#72](https://github.com/driceroland/Search/issues/72))*
- [ ] **A home page or home button** *(email)*
- [ ] **The sidebar on the right** *(email)*
- [ ] **Back, forward and reload on the left with the tabs across the top** *(email)*
- [ ] **Autocomplete in a new tab** What exactly was asked, to find out. *(X)*

## Asked to try again on the latest version

- [ ] **Google search asks for a reCAPTCHA** 1.0.2 no longer tells pages it is a separate app and says it is Safari. *([#26](https://github.com/driceroland/Search/issues/26))*
- [ ] **NordPass doesn't work** *([#98](https://github.com/driceroland/Search/issues/98))*
- [ ] **A tab's site switches, and the tab doesn't follow** Not reproduced. *([#28](https://github.com/driceroland/Search/issues/28))*
- [ ] **Keep a page's editing shortcuts while Search's own still work** 1.0.2 gives the page the first go at its shortcuts; asked whether it's enough. *([#147](https://github.com/driceroland/Search/issues/147))*

## Not on the list, for now

- **An address bar above the page** The card behind a tab's icon — the site, whether its connection is secure, copy, print, zoom — does that part without a bar. *([#15](https://github.com/driceroland/Search/issues/15), [#56](https://github.com/driceroland/Search/pull/56))*
- **Tab groups and folders** Spaces keep sets of tabs apart, and the column stays quiet. *([#23](https://github.com/driceroland/Search/issues/23), [#68](https://github.com/driceroland/Search/issues/68), [#31](https://github.com/driceroland/Search/pull/31), [#54](https://github.com/driceroland/Search/pull/54), [#76](https://github.com/driceroland/Search/pull/76))*
- **Bookmarks in the column, above the tabs** The bookmarks bar, off unless turned on, and the Bookmarks menu are where they live. *([#58](https://github.com/driceroland/Search/issues/58), [#69](https://github.com/driceroland/Search/pull/69))*
- **A Customization page and appearance options** Settings stays short. *([#101](https://github.com/driceroland/Search/issues/101), [#105](https://github.com/driceroland/Search/pull/105), [#106](https://github.com/driceroland/Search/pull/106), [#107](https://github.com/driceroland/Search/pull/107), [#108](https://github.com/driceroland/Search/pull/108), [#143](https://github.com/driceroland/Search/pull/143))*
- **A setting for how long the hidden sidebar waits** The default is what changes instead. *([#118](https://github.com/driceroland/Search/issues/118))*
- **A floating launcher** ⌘S and a folded column already give the page the whole window. *([#18](https://github.com/driceroland/Search/issues/18))*
- **The proxy extension API** WebKit doesn't give it to extensions. *([#12](https://github.com/driceroland/Search/issues/12))*
- **Dragging a tab out into a new window** Search has one window. *([#72](https://github.com/driceroland/Search/issues/72))*
- **Snoozing tabs** For now. *([#111](https://github.com/driceroland/Search/pull/111))*
- **A Vim mode** Vimium works. *([#160](https://github.com/driceroland/Search/pull/160))*
- **Search in Brazilian Portuguese** For now. *([#113](https://github.com/driceroland/Search/pull/113))*
- **Windows and Linux** Search is made of the Mac's own WebKit and AppKit; there is nothing to carry over. *([#62](https://github.com/driceroland/Search/issues/62), [#64](https://github.com/driceroland/Search/issues/64), [#65](https://github.com/driceroland/Search/issues/65), [#197](https://github.com/driceroland/Search/pull/197))*
- **macOS before 14** The app leans on what macOS 14 added to WebKit.
- **Accounts and sync (bookmarks with Google, tabs across devices)** Search has no server and keeps everything on your Mac; importing is the way in. *([#224](https://github.com/driceroland/Search/issues/224))*
