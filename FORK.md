# Fork synchronization and builds

This fork keeps its own changes on `dev` and `master`. The `Sync upstream`
workflow checks `SlotSun/dart_simple_live` daily at **00:00 Asia/Shanghai**
(16:00 UTC). GitHub may delay scheduled runs.

Each branch is merged independently. No force pushes, resets of remote branches,
or upstream tag imports are used. A conflict fails that branch's job and leaves
its remote head unchanged; resolve it manually before the next synchronization.
The other branch can still succeed. If upstream temporarily removes `dev`, its
sync job fails without deleting the fork branch.

The workflow explicitly dispatches `Fork builds` after synchronization because
pushes made with `GITHUB_TOKEN` do not start push-triggered workflows. A commit
with an existing build run is skipped. If dispatch failed, the next sync retries
even when upstream has no newer commit. To rebuild a failed commit, manually run
`Fork builds` for its branch, or run `Sync upstream` with `force_build` enabled.

Artifacts are retained for 14 days and labelled with branch, platform and run
number. The selected commit is shown in the build run name.

- Android: release APKs using a cached **test** signing key. If the Actions cache
  is evicted, the regenerated key changes; uninstall an older test installation
  before installing a build signed with the new key. Production signing needs
  your own durable keystore and Secrets.
- Windows: ZIP containing the complete executable bundle.
- macOS: ZIP containing the app, without Developer ID notarization.
- iOS: unsigned IPA; sign it yourself before installing on a device.

CI preparation uses CocoaPods and disables upstream Firebase telemetry for
Android test builds, so upstream private signing/Firebase Secrets are not needed.
Preparation changes only the runner checkout and is not pushed back to branches.
The upstream dev build workflow is restricted to its original repository to avoid
running a second pipeline that expects unavailable Secrets.

Actions must be enabled in the fork. The sync workflow requests only repository
contents write and Actions write permissions; build jobs use contents read.
Organization or repository policies can still prohibit these operations.
Scheduled workflows run from the default branch (`master`). GitHub may disable
schedules after 60 days without repository activity; re-enable the workflow in
Actions if that happens. Failures are visible in Actions; configure GitHub's
workflow failure notifications for your account as desired.

Validation: `python3 .github/scripts/test_sync_upstream.py` exercises merge
preservation, unchanged runs, conflict protection, dispatch retries and rebuilds.
