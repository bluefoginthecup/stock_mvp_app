# App Store Release Checklist

Last updated: 2026-05-05

## Current Status

- App code: mostly ready, but release QA remains.
- iOS project: builds from a Flutter iOS project and has Firebase configuration.
- Privacy manifest: added at `ios/Runner/PrivacyInfo.xcprivacy`.
- App display name: set to `재고관리`.
- Blocking item: replace the placeholder bundle id `com.example.stockMvpApp` with the App Store Connect bundle id.

## 1. Apple Developer / App Store Connect

- [ ] Confirm Apple Developer Program membership.
- [ ] Create or confirm App ID.
- [ ] Register final Bundle ID.
- [ ] Replace `PRODUCT_BUNDLE_IDENTIFIER = com.example.stockMvpApp`.
- [ ] Update Firebase iOS app bundle id to match the final Bundle ID.
- [ ] Download and replace `ios/Runner/GoogleService-Info.plist` if Firebase bundle id changes.
- [ ] Confirm signing team `HMXLF59C3U` is correct.

## 2. iOS Build Settings

- [x] iOS deployment target is set to 16.6 for Runner target.
- [x] Podfile forces pods to iOS 16.0.
- [x] App icon assets are present.
- [x] Launch screen exists.
- [x] Camera, photo library, and contacts permission strings are present.
- [x] Privacy manifest is included in the Runner resources build phase.
- [ ] Archive from Xcode using Release configuration.
- [ ] Upload first build to App Store Connect.

## 3. Privacy / Data Collection

- [ ] Publish a privacy policy URL.
- [ ] Fill App Store Connect privacy answers.
- [ ] Confirm Firebase Auth, Firestore, and Storage data handling.
- [ ] Confirm whether cloud backup is optional and encrypted by default.
- [ ] Confirm whether support contact or analytics is used.

Expected app-collected data:

- Account identifiers from Firebase/Google sign-in.
- User-entered inventory, supplier, customer, order, purchase, quote, and memo data.
- Optional receipt, document, and fabric images.
- Optional contacts selected by the user for supplier entry.
- Optional encrypted backup files and backup metadata in Firebase.

## 4. QA Before TestFlight

- [ ] Fresh install and first login.
- [ ] Existing login.
- [ ] Create, edit, delete, and restore inventory item.
- [ ] Create supplier manually.
- [ ] Import supplier from contacts.
- [ ] Create order.
- [ ] Create purchase order and generate A4/mobile purchase document.
- [ ] Create quote and generate A4/mobile quote document.
- [ ] Attach camera/gallery/file receipt to purchase.
- [ ] Run stock in/out flow.
- [ ] Run work start/complete flow.
- [ ] Manual full backup.
- [ ] Manual full restore.
- [ ] Encrypted cloud backup upload.
- [ ] Cloud backup restore.
- [ ] Permission denial cases for camera/photos/contacts.
- [ ] Dark mode.
- [ ] Small iPhone screen.
- [ ] iPad layout if iPad is supported.

## 5. Store Listing Assets

- [ ] App name.
- [ ] Subtitle.
- [ ] Description.
- [ ] Keywords.
- [ ] Support URL.
- [ ] Privacy policy URL.
- [ ] Screenshots for required iPhone sizes.
- [ ] iPad screenshots if iPad distribution remains enabled.
- [ ] Review notes.
- [ ] Demo reviewer account.

## 6. Review Notes Draft

Suggested reviewer path:

1. Sign in with the provided test account.
2. Open Dashboard.
3. Open Inventory and create a sample item.
4. Open Suppliers and create a sample supplier.
5. Open Quotes, create a quote, add an item, and open A4/mobile quote preview.
6. Open Purchases, create a purchase order, add an item, and open A4/mobile purchase preview.
7. Open Settings to review backup options.

Mention that cloud backup is optional and stores encrypted backup data when enabled.
