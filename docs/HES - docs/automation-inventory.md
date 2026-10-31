# Automation inventory

Keep this list current: it is the source for retrieve commands and for the "one before-save and one after-save flow per object" check.

## Record-triggered flows

Confirm the exact API names once with:
```powershell
sf org list metadata --metadata-type Flow | Select-String "Save"
```
and correct the **API name** column below (several were saved with Salesforce's default `_Before_Save` / `_After_Save` spelling).

| Object | Timing | Label | API name (confirm) | Entry | What it does | WBS |
|---|---|---|---|---|---|---|
| Lead | After save | Lead After Save | `Lead_AfterSave` | New lead with email | Alert HES Lead Acknowledgement; fault → Task | 4-02 |
| Opportunity | After save | Opportunity After Save | `Opportunity_AfterSave` | Only when updated to meet Stage = Closed Won | Equipment per unit, Draft Coverage Plan, Equipment Coverage links; fault → Custom Error HES_Err_Generic | 4-08, 4-09 |
| Case | Before save | Case Before Save | `Case_Before_Save` | `OR(ISNEW(), ISCHANGED({!$Record.Status}))`, every time | New Case: junk check (Junk Rule CMDT) → Closed/Junk. Reopened: Unscheduled, Needs Replanning, dates cleared | 5-05, 6-07 |
| Case | After save | Case After Save | `Case_AfterSave` or `Case_After_Save` | `OR(ISNEW(), ISCHANGED({!$Record.Status}))`, every time | New Genuine Case: acknowledgement by channel. Just Closed: Last Service Date + satisfaction email. Faults → Task | 5-03, 6-06 |
| Coverage Plan | After save | Coverage Plan After Save | `Coverage_Plan_After_Save` | Only when updated to meet Status = Active | Sets Current Coverage Plan on every covered unit (one query, one update); fault → Custom Error HES_Coverage_Activation_Failed | 6-04 |
| Case Skill | Before save | Case Skill Before Save | `Case_Skill_Before_Save` | `OR(ISNEW(), ISCHANGED({!$Record.Skill__c}))` | Blocks duplicate skill on a case (Custom Error label); stamps Unique Key | 6-05 |

Planned: Case Apex trigger + scheduling service (module 7, additional to the flows as the brief allows); nightly scheduled flow calling the invocable Apex roll-forward (CAP-06).

## Validation rules

| Object | Rule | Bypass | Purpose | WBS |
|---|---|---|---|---|
| Capacity | Engineer_Required | Yes | A capacity must belong to an engineer | 2-02 / 3-03 |
| Opportunity | Negotiation_Requires_Equipment_Lines | **No (deliberate)** | Negotiation needs at least one product line | 4-05 |
| Case | Effort_Required_Before_Assignment | Yes | Technical case cannot go to a user without effort > 0 | 6-02 |

## Approval process
| Object | Name | Entry | Approver | WBS |
|---|---|---|---|---|
| Opportunity | HES Discount over 15% | Discount > 15 | Submitter's Manager | 4-07 |

Field updates: Stamp_Approval_Submitted (NOW()), Clear_Approval_Decided (blank), Stamp_Approval_Decided (NOW()).

## Assignment rule
**HES Case Routing** (Case, active) – see design.md INT-05 for the entries.

## Email templates (Classic text, folder HES Email Templates, Available For Use)

| Template | Unique name | Used by | WBS |
|---|---|---|---|
| HES Lead Acknowledgement | HES_Lead_Acknowledgement | Alert HES Lead Acknowledgement | 4-02 |
| HES Discount Submitted | HES_Discount_Submitted | Approval assignment email | 4-07 |
| HES Discount Approved | HES_Discount_Approved | Alert HES Discount Approved | 4-07 |
| HES Discount Rejected | HES_Discount_Rejected | Alert HES Discount Rejected | 4-07 |
| HES Case Ack Email | HES_Case_Ack_Email | Alert HES Case Ack Email | 5-03 |
| HES Case Ack Web | HES_Case_Ack_Web | Alert HES Case Ack Web | 5-03 |
| HES Case Satisfaction | HES_Case_Satisfaction | Alert HES Case Satisfaction | 6-06 |

## Email alerts

| Object | Alert | Recipients | From | Fired by |
|---|---|---|---|---|
| Lead | HES Lead Acknowledgement | Email Field: Email | Helios Sales | Lead After Save |
| Opportunity | HES Discount Approved | Owner | Helios Sales | Approval (final approval) |
| Opportunity | HES Discount Rejected | Owner | Helios Sales | Approval (final rejection) |
| Case | HES Case Ack Email | Email Field: Web Email (+ Related Contact) | Helios Service Desk | Case After Save |
| Case | HES Case Ack Web | Email Field: Web Email (+ Related Contact) | Helios Service Desk | Case After Save |
| Case | HES Case Satisfaction | Related Contact: Contact, Email Field: Web Email | Helios Service Desk | Case After Save |

Organization-wide addresses: **Helios Sales**, **Helios Service Desk** (see setup-steps.md).

## Custom labels

| Name | Value | Used by |
|---|---|---|
| HES_Err_Generic | Something went wrong while saving. Your administrator has been notified. | Opportunity After Save fault |
| HES_Err_Effort_Required | Enter an estimated effort above zero before assigning to an engineer. | Apex / LWC (module 7+) |
| HES_Err_Negotiation_Lines | Add at least one equipment line before moving to Negotiation. | Reference text for SAL-03 |
| HES_Msg_Unscheduled | This engineer is not scheduled, so no work has been planned. | Scheduling engine (CAP-01) |
| HES_Msg_No_Coverage_Access | No equipment found that you have access to. | Agent action (module 10) |
| HES_Coverage_Activation_Failed | This plan could not be activated because its equipment could not be updated. Please try again or contact your administrator. | Coverage Plan After Save |
| HES_Duplicate_Case_Skill (check exact name) | This skill is already recorded on this case. | Case Skill Before Save |

Validation rule error messages cannot reference custom labels; their text is translatable with the Translation Workbench.

## Custom metadata
- HES Setting › Default (Horizon 60, Business Hours HES Working Week, At Risk 90).
- Junk Rule › Newsletter, Unsubscribe, Out Of Office, Marketing Sender.

## Retrieve command (everything automation-related)
```powershell
sf project retrieve start --metadata "Flow" "ValidationRule" "ApprovalProcess" "AssignmentRules:Case" "Workflow" "EmailTemplate" "CustomLabels" "CustomMetadata"
```
