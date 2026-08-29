# Today widget

**Status: fully wired.** The `vikunja-widgets` app-extension target exists,
embeds `VikunjaWidgetKit`, is embedded into the `vikunja` app, and both share
the App Group and keychain group. `xcodebuild -scheme vikunja build` produces
`vikunja.app/PlugIns/vikunja-widgets.appex`.

## Identifiers (kept in sync with `VikunjaWidgetKit/Config/VikunjaWidgetConfig.swift`)

| Thing | Value |
|---|---|
| App Group | `group.dev.sergiosuarez.vikunja` |
| Keychain group | `$(AppIdentifierPrefix)dev.sergiosuarez.vikunja.shared` |
| Widget bundle id | `dev.sergiosuarez.vikunja.widgets` / `.dev.widgets` (Debug) |
| Widget `kind` | `TodayWidget` |

Entitlements: `vikunja/vikunja.entitlements` and
`vikunja-widgets/vikunja-widgets.entitlements`. Both list, in this order:

1. `$(AppIdentifierPrefix)$(CFBundleIdentifier)` — the target's own private
   group. **Must be first** so Keychain queries with no explicit group keep
   defaulting to it (otherwise the pre-widget account becomes invisible and
   `migrateToAccessGroup()` can't find it).
2. `$(AppIdentifierPrefix)dev.sergiosuarez.vikunja.shared` — the shared group
   the app writes and the widget reads.

Plus the App Group `group.dev.sergiosuarez.vikunja`. `CODE_SIGN_ENTITLEMENTS`
is set on both targets.

`KeychainAccountStore` probes the shared group once on first use and silently
falls back to the private keychain if it isn't usable (app built without the
capability provisioned, or a simulator that doesn't honor it) — so the app
never breaks; only the widget goes dark until provisioning is fixed. Open the
project in Xcode once with automatic signing so it registers the App Group and
Keychain Sharing with the portal.

## How it was added to the project

`project.pbxproj` was edited with the `xcodeproj` Ruby gem (script:
`scratchpad/add_widget_target.rb` from that session):

1. `XCLocalSwiftPackageReference "Packages/VikunjaWidgetKit"`.
2. `vikunja-widgets` target (`com.apple.product-type.app-extension`), iOS 26.2,
   backed by a `PBXFileSystemSynchronizedRootGroup` on `vikunja-widgets/` with
   membership exceptions for `Info.plist` / `*.entitlements` / `*.md` (they're
   referenced via build settings, not bundled — otherwise `ProcessInfoPlistFile`
   collides).
3. `VikunjaWidgetKit` linked into both the widget target and the app (the app
   needs `VikunjaWidgetConfig`).
4. "Embed Foundation Extensions" copy-files phase on the app + a target
   dependency.
5. `CODE_SIGN_ENTITLEMENTS` on both targets.

If you ever regenerate the project, re-run that script.

## Verify

```sh
xcodebuild -project vikunja.xcodeproj -scheme vikunja \
  -destination 'generic/platform=iOS Simulator' build
# → BUILD SUCCEEDED, and vikunja.app/PlugIns/vikunja-widgets.appex exists
```

Run the app once (writes the account into the shared keychain group / app
group), then long-press the home screen ▸ add the **Today** widget. It
refreshes ~every 30 min, on app-backgrounding, and after the toggle intent.

## Follow-ups (Phase 2/3 from the plan)

- Replace the blanket `scenePhase` reload with a `WidgetReloading` protocol in
  `VikunjaCore` (same shape as `ToastPresenting`), implemented in the app with
  `WidgetCenter`, injected into `TodayViewModel` / `TaskDetailViewModel` /
  `QuickAddTaskViewModel` / `ProjectOverviewViewModel`.
- `vikunja://task/<id>` deep links into `TaskDetailView` (register the
  `vikunja` URL scheme on the app target, handle in `RootView`/`MainTabView`).
- `.accessoryRectangular` / `.accessoryCircular` lock-screen widgets.
- `AppIntentConfiguration` for a filter (All / Overdue / Today) and, with
  multi-account, an account picker.
