# App Store Privacy Answers Draft

Last updated: 2026-05-05

This draft is for App Store Connect privacy labels and the public privacy policy. Confirm every item before submission.

## Tracking

- Does the app track users across apps or websites owned by other companies? **No**
- Uses third-party advertising? **No**
- Uses data brokers? **No**

## Data Linked to the User

### Contact Info

- Name: used for user account, supplier, customer, buyer/seller profile, quotes, purchases, and documents.
- Email address: used for Firebase/Google sign-in.
- Phone number: used when the user enters supplier/customer/profile contact details or imports selected contacts.

Purpose: App Functionality.

### User Content

- Photos or videos: optional receipt, transaction document, and fabric images selected or captured by the user.
- Other user content: inventory data, supplier/customer data, orders, purchase orders, quotes, memos, backup files, and generated business documents.

Purpose: App Functionality.

### Identifiers

- User ID: Firebase authenticated user id for account and optional cloud backup ownership.

Purpose: App Functionality.

## Data Not Used for Tracking

Current implementation does not intentionally use collected data for tracking, third-party advertising, or advertising measurement.

## Third-Party Services

- Firebase Authentication: sign-in and account identity.
- Google Sign-In: Google account authentication.
- Cloud Firestore: optional cloud backup metadata.
- Firebase Storage: optional encrypted backup file storage.

## Device Permissions

- Camera: attach work documents, receipts, and fabric photos.
- Photo Library: select existing work documents, receipts, and fabric photos.
- Contacts: import a user-selected contact into supplier/customer fields.

## Required Notes Before Submission

- Confirm Firebase console data retention and deletion policy.
- Confirm if crash reporting, analytics, or remote logging is added later. If added, update this document and App Store Connect answers.
- Confirm the final support contact and privacy policy URL.
