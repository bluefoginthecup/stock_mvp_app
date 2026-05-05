# TestFlight QA Plan

Last updated: 2026-05-05

## Build

- Version: 1.0.0
- Build: 1
- Bundle ID: com.bluefog.chalstock

## Smoke Test

- [ ] Fresh install opens without crash.
- [ ] Email/password sign-up works.
- [ ] Email/password sign-in works.
- [ ] Password reset email request works.
- [ ] Google/Firebase sign-in works.
- [ ] Existing login session restores correctly.
- [ ] Dashboard loads after login.
- [ ] App works after force quit and relaunch.

## Inventory

- [ ] Create an inventory item.
- [ ] Edit item name, quantity, unit, and memo.
- [ ] Run stock in flow.
- [ ] Run stock out flow.
- [ ] Confirm stock history is visible.
- [ ] Delete or archive item if supported.

## Suppliers / Customers / Profiles

- [ ] Create supplier manually.
- [ ] Import selected contact into supplier fields.
- [ ] Deny contacts permission and confirm app remains usable.
- [ ] Create or edit account profile.
- [ ] Select supplier/account profile for quote supplier info.

## Quotes

- [ ] Create quote.
- [ ] Add line item.
- [ ] Edit quantity and price.
- [ ] Confirm totals are correct.
- [ ] Open A4 preview.
- [ ] Open mobile preview.
- [ ] Share generated quote document.
- [ ] Confirm supplier information appears on quote.

## Purchases

- [ ] Create purchase order.
- [ ] Add line item.
- [ ] Confirm totals are correct.
- [ ] Open A4 preview.
- [ ] Open mobile preview.
- [ ] Share generated purchase document.
- [ ] Attach camera photo.
- [ ] Attach gallery image.
- [ ] Attach file if supported.
- [ ] Deny camera/photo permission and confirm app remains usable.

## Orders / Work

- [ ] Create order.
- [ ] Start work.
- [ ] Complete work.
- [ ] Confirm linked stock or work state updates correctly.

## Backup / Restore

- [ ] Manual full backup succeeds.
- [ ] Manual full restore succeeds on a test device or simulator.
- [ ] Cloud backup upload succeeds.
- [ ] Cloud backup restore succeeds.
- [ ] Wrong backup password or missing backup case shows recoverable error.

## UI / Device Coverage

- [ ] Small iPhone viewport.
- [ ] Large iPhone viewport.
- [ ] iPad viewport if iPad remains supported.
- [ ] Light mode.
- [ ] Dark mode.
- [ ] Korean text does not overflow buttons, cards, or previews.

## Release Blockers

- [ ] Apple Developer App ID exists for `com.bluefog.chalstock`.
- [ ] Firebase iOS app exists for `com.bluefog.chalstock`.
- [ ] Official Firebase `GoogleService-Info.plist` is downloaded and committed.
- [ ] Privacy policy URL is live.
- [ ] Support URL is live.
- [ ] Demo reviewer account is ready.
- [ ] App Store screenshots are captured.
