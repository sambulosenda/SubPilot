# Cancel-by + FinanceKit — scope

Scoped 2026-11-22. Thesis: verdict, not ledger. Every sub shows the last day to
cancel; the app finds subs with no bank login; a tally proves it paid for itself.

## A. Cancel-by — no Apple approval needed

### Already built
| Piece | Where |
|---|---|
| `NoticePeriod`, `CancelDeadline`, `cancelDeadline()` + tests | `Models/NoticePeriod.swift`, `AttentionRadarTests` |
| Home "needs attention" item, 14-day window | `Renewals/AttentionRadar.swift` |
| Two notifications (lead + last day) | `NotificationManager.swift:157` |
| Detail row | `SubscriptionDetailView.swift:216` |
| Notice picker (under Reminders) | `SubscriptionFormView.swift:232` |
| "You've cut £X a year" pill + list | `CutSummary`, `HomeDashboard.swift:110`, `CutListView` |
| Cancel helper, 56/243 curated cancel URLs | `CancelGuide.swift`, `catalogue.json` |

### Gaps
1. **Deadline only exists if user picked a notice period.** Default is nil, so
   Netflix etc. never get a cancel-by. Nobody finds the picker.
2. **Only 4 fixed periods** (2w / 1mo / 6w / 3mo). No custom, no fixed-term
   contract end (phone, broadband, gym — the UK/DE cases that matter most).
3. **Catalogue has no notice defaults.** Keys today: brand, cycle, domain, cancelURL.
4. **Every surface leads with "Renews".** Row (`SubscriptionRow.swift:68`),
   calendar, widget (`Event` has `date` + `isTrialEnd` only), Siri intents,
   Live Activity (trial only).
5. **Tally is static** — yearly cost of cancelled subs. `cancelledAt` exists but
   no accrued "saved so far". (Review prompt on cancel already exists:
   `SubscriptionDetailView.requestReviewAfterSaving`, commit 309cbf5 — unshipped.)
6. **Cancel URL coverage 23%.**

### Phases
**A1 — BUILT 2026-11-22, uncommitted. 180/180 unit tests pass; checked on iPhone 18 Pro sim.**
- Universal deadline: no notice period → cancel-by = day before renewal
  (`CancelDeadline.needsNotice`). Trials without notice keep their end date.
- Attention rule: notice-period subs always; cancel-any-time only when the
  cycle is a year or more. Deadline notifications stay notice-only.
- Row: "Cancel by" only when the sub needs notice; cancel-any-time rows keep
  "Renews". Universal "Cancel by" was tried and reverted: the longer label
  widens the price column and truncates long names (worse in es/it/pt/fr).
  Every sub's cancel-by date is on the detail screen. Universal row copy needs
  the row relaid as two lines (name/price, category/date) — A2.
- Accrued tally = charges that never happened since `cancelledAt`
  (`Subscription.chargesAvoided`, `CutSummary.savedSoFar`). Home pill shows
  "£X saved · £Y a year"; cut list adds "Saved £X so far".
- 3 new strings, translated in all 7 languages.
- Review prompt on cancel: nothing to do, already built.

**A2 — medium, ~1 week, schema change**
- Custom notice days + `contractEndDate` (optional fields; CloudKit promote to
  production before release, same as `PriceChange`).
- Catalogue notice defaults + Apple-billed hint; prefill on add.
- Calendar deadline markers; widget `Event.kind` (needs fallback decode);
  Siri "What should I cancel?"; Live Activity for last-day deadline.
- Cancel URLs to top ~150.

**A3 — later, legal check first**
- UK cooling-off window after annual renewal (DMCC regime, early 2027).
- DE Kündigungsbutton deep links.

## B. FinanceKit — gated on Apple

### Verified (Apple's FinanceKit page + iOS 27.3 SDK interface)
- Eligibility: Finance category (we are), US or UK App Store (we are), "financial
  management tools — spending trends, budgeting" (Insights). Account Holder
  submits a request form; granted per bundle ID.
- UK (iOS 18.4+, open banking via Wallet): Barclays, Barclaycard, First Direct,
  Halifax, HSBC, Lloyds, M&S, MBNA, Monzo, Nationwide, NatWest, RBS, Santander.
- US: Apple Card, Apple Cash, Savings only. No Germany. **This is a UK feature.**
- API: `FinanceStore.shared`, `isDataAvailable`, `requestAuthorization()`,
  `transactions(query:)`, `transactionHistory(forAccountID:since:isMonitoring:)`
  with Codable `HistoryToken`. iOS 26: `enableBackgroundDelivery` +
  `BackgroundDeliveryExtension` (new extension target).
- `Transaction`: `merchantName`, `merchantCategoryCode`, `creditDebitIndicator`,
  `status`, `transactionDate`, `transactionType` (incl. `.directDebit`,
  `.standingOrder`).
- No simulator data; needs a device with a bank connected in Wallet.

### Unverified
- **Organization account required?** Apple's page doesn't say. A DTS forum
  answer says yes. Outflow ships FinanceKit under an individual-looking seller
  name. The request form settles it.

### Fit
Pipeline is already source-agnostic:
`BankTransaction` → `RecurringChargeDetector` → `SubscriptionDeduplicator` →
`PriceUpdateDetector` → `ImportReviewView`. FinanceKit is one more source.

### Phases
**B0 — today, ~1 hour, yours:** submit the entitlement request. Blocks all of B;
lead time unknown.

**B1 — medium, ~1 week after approval**
- `FinanceKitSource`: debit + booked only; description = `merchantName ??
  transactionDescription` → `BankTransaction`.
- Entitlement + `NSFinancialDataUsageDescription`.
- "Find from Wallet" in `BankImportView` + onboarding, gated on `isDataAvailable`.
- Detector: add quarterly bucket (85–95 days). `.directDebit` → ask for notice
  period (feeds A).

**B2 — medium**
- Persist `HistoryToken` per account; sync on foreground.
- Auto price-rise detection, "charged today" confirmation, missed charge →
  "did you cancel?" → tally.
- Background delivery extension → "Netflix went up £2" notification.

### Risks
- Entitlement refused → statement import stays as the fallback.
- User must have connected a bank in Wallet first; few have. Needs onboarding copy.
- Starling, Revolut, Amex not on Apple's UK list.
- Never sync raw transactions to CloudKit — derived subs only.

## Sequence
B0 today → A1 → ship 2.0 → A2 → B1 when approved.

## Unresolved questions
1. Apple Developer account: individual or organization?
2. Is a UK bank connected in Wallet on your iPhone (for testing)?
3. Universal default "cancel by = day before renewal" for every sub — OK?
4. FinanceKit: detection free and adding >5 is Pro, or all Pro like statement import?
5. A1 inside 2.0, or ship the 19 existing commits first?
6. `contractEndDate` schema change now (A2) or defer?
