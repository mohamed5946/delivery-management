# Delivery Management

Manager-only companion app to **DeliveryFlow**. Same Firebase project
(`deliveryflow-fbe9f`), same Firestore data — no new backend, no data
migration, no sync between apps. Both apps read and write the same
collections.

## What it is

- **Dashboard** — KPI cards, week chart, needs-attention list, shimmer
  skeleton while loading. Entry motion: KPI numbers count up from 0,
  chart bars rise from the baseline, staggered.
- **الأجور الأسبوعية (weekly payroll)** — driver names for the selected
  week; tap a name for payout detail (method / number / wallet name,
  weekly net with visible bonus and deduction lines, day-by-day
  Sun–Sat breakdown with per-day adjustment lines). Blocked drivers
  are excluded. Row and detail nets always agree (same computation).
- **Application** — the manager's own account area: profile, sign-in
  state, change password, theme, diagnostics log, Help & Support, and
  the prominent **فريق العمل** entry opening the standalone team
  screen (searchable list of all people; tap a person for full
  detail: phone, email, payout prefs, day selector, day totals and
  salary components, week totals, adjustments with reasons, day
  orders list, full order detail exactly as the driver sees it, role
  promote/demote, block/unblock).
- **Block** — blocked users list, detail, Unblock restoring full
  access with data intact.

## Login

Manager accounts only, via **username or phone + password** (resolved
through the same lookup docs as DeliveryFlow). No sign-up screen in
v1 (accounts are created in DeliveryFlow and promoted to manager
there), no invite gate, no Google sign-in in v1, and never any
shared, default, or hardcoded credential. Closing the app never logs
out; sign-out is explicit and confirmed.

## Live sync (this app only)

While the app is running it syncs **automatically** via Firestore
snapshot listeners on users, day summaries, orders, adjustments and
profile docs — a driver adding an order, a day total changing, a
bonus/deduction, a block/unblock, or a payout-prefs change lands on
the dashboard, payroll, team, driver detail and order lists instantly,
with no manual refresh. A refresh button re-attaches the listeners as
a fallback, and listener errors show a plain-language message with a
reconnect button (never a silent stale screen). Listeners are
cancelled on screen dispose and on sign-out. Closed-app push
notifications (FCM) are NOT in v1 scope — on reopening, the app
fetches the latest data immediately. DeliveryFlow's own pull-based
design is untouched.

## Console steps (one time, by the project owner)

1. Firebase console → project **deliveryflow-fbe9f** → Project
   settings → "Your apps" → Add app → Android, package name
   `com.valor.deliverymanagement`. No SHA-1 needed for v1
   (email/password Auth only, no Google sign-in).
2. Download that app's `google-services.json` and copy its values
   into `lib/data/firebase_options.dart`, replacing the `PASTE_…`
   placeholders (`apiKey`, `appId`, `messagingSenderId`). Until then
   the app shows a clear "Firebase not configured" message on the
   login screen and cannot sign in — it never fails silently.
3. Rebuild + reinstall after pasting real Firebase options.
4. No `firestore.rules` change is needed (current rules already
   grant manager accounts read/write over the same collections).

## v1 limitations (honest)

- **Per-order detail gap:** today's cloud order docs carry only
  counts/totals; the full order-detail UI is built and tested, but
  real per-order data appears only after a DeliveryFlow change to
  upload order entries in its order records (separate follow-up,
  not in this repo).
- **Debug-signed APK:** v1 release signs with debug keys (default
  template); a future release-key build would require uninstall +
  reinstall.
- **mustChangePassword:** flagged accounts are told to complete the
  forced change in DeliveryFlow first; the in-app change-password
  form serves unflagged managers (and uses the Auth user's own
  email for re-auth, avoiding DeliveryFlow's empty-email bug class).
- **No map view in v1:** order detail shows every data field
  (including route/road point counts) but no map visualization, and
  no tracking actions (a manager app never starts tracking).
- **No day-delete in v1:** manager powers shipped are edit day,
  adjustments (+delete), promote/demote, block/unblock.
- Payout-edit prevention is app-level, not rules-level (same as
  DeliveryFlow v27.35). Blocked Auth records remain (console/backend
  only) but the gate blocks sign-in.
