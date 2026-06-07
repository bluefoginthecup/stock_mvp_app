# RevenueCat Setup

Chalstock uses RevenueCat for paid subscriptions and keeps app/cloud trials in
Firestore.

## Products

Create these auto-renewing subscriptions in App Store Connect and Google Play,
then import/connect them in RevenueCat.

| Product ID | Plan | Entitlement |
| --- | --- | --- |
| `chalstock_pro_6m` | Pro 6 months | `pro` |
| `chalstock_pro_1y` | Pro 12 months | `pro` |
| `chalstock_cloud_backup_1y` | Cloud Backup 12 months | `cloud_backup` |

## Entitlements

Create two RevenueCat entitlements:

| Entitlement ID | Products |
| --- | --- |
| `pro` | `chalstock_pro_6m`, `chalstock_pro_1y` |
| `cloud_backup` | `chalstock_cloud_backup_1y` |

## Offering

Create a default/current Offering that includes all three packages:

| Package | Product |
| --- | --- |
| Six month | `chalstock_pro_6m` |
| Annual | `chalstock_pro_1y` |
| Annual or custom | `chalstock_cloud_backup_1y` |

The app filters packages by product ID, so the RevenueCat package identifier can
be RevenueCat's predefined period identifier or a custom identifier.

## App Runtime Keys

Run iOS with:

```bash
flutter run \
  --dart-define=REVENUECAT_IOS_API_KEY=<ios_public_sdk_key> \
  -d 00008030-001E553C3AEA802E
```

Run Android with:

```bash
flutter run \
  --dart-define=REVENUECAT_ANDROID_API_KEY=<android_public_sdk_key>
```

For local testing, `REVENUECAT_TEST_API_KEY` overrides platform-specific keys.

## Expected App Flow

- Signed-in free user sees `7일 무료체험 시작`, `Pro 구독`, and disabled paid buttons
  when no RevenueCat key is provided.
- With a RevenueCat key, `Pro 구독` opens a product selector for Pro 6 months
  and Pro 12 months.
- Pro users can open the Cloud Backup selector for the Cloud Backup yearly
  product.
- Purchase restore refreshes RevenueCat entitlements and updates app state.
