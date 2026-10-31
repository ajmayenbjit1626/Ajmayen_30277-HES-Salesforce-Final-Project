# Test evidence

Result: **Pass**, **Fail**, **Open** (issue being fixed), **To do** (not run yet) or **Pending 7-x** (needs the scheduling engine).
Screenshots: `docs/evidence/<requirement>/<test id>.png`.
Results marked **Pass** were confirmed during the build sessions; re-run every test once before submission and attach the screenshot.
Persona note: personas other than Sales Rep and Field Engineer are tested with Sam Rep temporarily holding the persona's permission set and role (see persona-mapping.md).

## Security (module 3)

| ID | Test | Expected | Result | Evidence |
|---|---|---|---|---|
| ACC-01-1 | Sam (Sales Rep) logs in | Lightning, App Launcher, only sales objects | Pass | |
| ACC-02-1 | Engineer (Eric) case list | Only cases he owns | Pass (after Account rule fix, 6-02) | |
| ACC-02-2 | Dispatcher (Sam swap) | Every open case visible | To do | |
| ACC-02-3 | Finance (Sam swap) | Admin-owned opportunities visible, read-only | Pass | |
| ACC-03-1 | Bypass test script | BLOCKED without HES Data Loader, SAVED with it | Pass | |
| ACC-04-1 | Rep opens opportunity | Discount visible, Total Cost / Margin hidden | Pass | |
| ACC-04-2 | Sales Manager opens same opportunity | Margin visible | Pass | |
| ACC-04-3 | Finance / Service Manager (Sam swap) | Margin read-only | To do (personas C and D) | |

## Sales (module 4)

| ID | Test | Expected | Result | Evidence |
|---|---|---|---|---|
| SAL-01-1 | Submit website enquiry | Lead created, Lead Source Web, acknowledgement email | Pass | |
| SAL-02-1 | Convert lead | Equipment Type, Postcode, Budget on opportunity; Region on account | Pass | |
| SAL-03-1 | Negotiation without products | Blocked | Pass | |
| SAL-03-2 | Negotiation with products | Allowed | Pass | |
| SAL-04-1 | Old open opportunity | Deal Health At Risk; report groups by Deal Health | Pass | |
| SAL-05-1 | 20 % discount submitted | Record locked, manager notified, approve unlocks and emails | To do (4-07 step 9) | |
| SAL-06-1 | Closed Won with quantity 3 | 3 Equipment records | Pass | |
| SAL-07-1 | Same deal | Draft plan CP-0004, Covered Units 3 | Pass | |
| SAL-07-2 | Edit the won deal again | No duplicates | Pass | |

## Intake (module 5)

| ID | Test | Expected | Result | Evidence |
|---|---|---|---|---|
| INT-01-1 | Email to support address | Case, Origin Email, contact matched | Pass | |
| INT-03-1 | Website service form | Case, Origin Web | Pass | |
| INT-04-1 | Email case | Acknowledgement "Case 000…" arrives | Pass | |
| INT-04-2 | Web case | Web acknowledgement arrives | **Open** – flow runs the action, email not received; check alert recipients/From and Deliverability | |
| INT-05-T1 | Email, known contact on Benelux account | Benelux Technical | Pass (case 00001051, 00001053) | INT-05/T1 |
| INT-05-T2 | Web form, known contact | Benelux Technical | Pass (case 00001052) | INT-05/T2 |
| INT-05-T3 | Web form, unknown sender | Service Triage | Pass (case 00001054) | INT-05/T3 |
| INT-05-T4 | Edit with checkbox ticked after linking account | Re-routed to Benelux Technical | To do | INT-05/T4 |
| INT-05-T5 | Edit with checkbox unticked | Owner unchanged | To do | INT-05/T5 |
| INT-05-T6 | Billing case (after 6-01) | Billing queue | To do | INT-05/T6 |
| INT-06-1 | Debug: subject "Our monthly newsletter" | Closed, Reason Junk | Pass (debug) | |
| INT-06-2 | Real newsletter email | Closed/Junk, no acknowledgement, not in a queue | To do | |

## Service handling (module 6)

| ID | Test | Expected | Result | Evidence |
|---|---|---|---|---|
| SVC-01-1 | New case picker (admin) | Technical pre-selected, Billing available | Pass | |
| SVC-01-2 | Web case | Record type Technical, Case Technical Page, Benelux Technical | Pass (case 00001061) | |
| SVC-01-3 | Billing case | Invoice Reference, no effort fields | To do | |
| SVC-02-1 | Assign Technical case without effort to Eric | Blocked with message | To do | SVC-02/1 |
| SVC-02-2 | Effort 6, assign to Eric | Saved, owner Eric | Pass (case 00001061) | SVC-02/2 |
| SVC-02-3 | Assign to a queue without effort | Allowed | To do | |
| SVC-02-4 | Bypass (HES Data Loader) | Allowed | To do | |
| SVC-03-1 | Unit without plan | Not Covered | Pass (Ac Compressor) | |
| SVC-03-2 | Active plan started today or earlier | Covered | To do (CP-0004 start date was in the future) | |
| SVC-03-3 | Plan end date last month | Expired | To do | |
| SVC-03-4 | Activate Draft plan | Current Coverage Plan set on its units | To do (check one of CP-0004's linked units) | |
| SVC-04-1 | Add Compressor and Electrical to case 00001061 | Required Skills card shows both | Pass | |
| SVC-04-2 | Add the same skill twice | Blocked with label message | To do | |
| SVC-05-1 | Close case with equipment | Last Service Date today, satisfaction email | To do | |
| SVC-05-2 | Future segments removed on close | Removed | Pending 7-06 | |
| SVC-06-1 | Reopen Technical case 00001061 | Unscheduled, Needs Replanning, dates cleared | Pass | SVC-06/1 |
| SVC-06-2 | Reopen Billing case | Needs Replanning stays false | To do | |
| SVC-06-3 | Reassign or change effort after reopen | Plan rebuilt | Pending 7-02 | |

## Scheduling (module 7)
Expected results: scheduling-examples.md (A1–A7). Rows are added in 7-08.
