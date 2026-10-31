# Functional design and decisions

One section per requirement, in build order. "Decision" lines record choices a reviewer may ask about.

---

## Module 4 – Sales

### SAL-01 Web enquiry (4-02)
- Website `enquiry.html` (Netlify) posts to Web-to-Lead with `lead_source = Web` and the enquiry fields (Equipment Type, Site Postcode, Indicative Budget, Region). Opening it from a product (`enquiry.html?product=CH-200`) pre-selects the equipment type.
- **Lead_AfterSave** (after-save flow) fires email alert **HES Lead Acknowledgement** for new leads with an email; fault path creates a Task.
- Decision: Classic text templates instead of Lightning templates, because a Lightning template cannot use Lead merge fields ("We don't recognize the field prefix Lead") and Classic works in every email alert.

### SAL-02 Lead conversion (4-03)
Map Lead Fields: Equipment Type, Site Postcode, Indicative Budget → Opportunity; Region → Account. Stored in LeadConvertSettings.

### SAL-03 Stages, Path, negotiation rule (4-04, 4-05)
- Stages: Qualification 10 %, Needs Analysis 25 %, Proposal/Price Quote 50 %, Negotiation/Review 75 %, Closed Won 100 %, Closed Lost 0 %.
- Path **HES Opportunity Path** with key fields and guidance per stage (no cost or margin fields, reps can't see them).
- Validation rule **Negotiation_Requires_Equipment_Lines**: `AND(OR(ISNEW(), ISCHANGED(StageName)), ISPICKVAL(StageName, "Negotiation/Review"), NOT(HasOpportunityLineItem))`. Deliberately **no bypass**.

### SAL-04 Deal health (4-06)
`Deal_Health__c` = "At Risk" when open and older than `$CustomMetadata.HES_Setting__mdt.Default.At_Risk_Days__c` days, else "Healthy". Threshold in custom metadata, not in the formula. List view *Open Pipeline – Health*, report *Pipeline by Deal Health* (folder HES Sales Reports, shared with HES Leadership and subordinates).

### SAL-05 Discount approval (4-07)
Approval process **HES Discount over 15%** (entry: Discount > 15; approver: submitter's Manager; editable by administrators only). Initial submission: lock + Stamp Approval Submitted + Clear Approval Decided. Approval/Rejection: unlock + alert (HES Discount Approved / Rejected) + Stamp Approval Decided. Recall: unlock. Approval Hours formula for AN-04.

### SAL-06 / SAL-07 Closed Won (4-08, 4-09)
**Opportunity_AfterSave** (only when updated to meet Stage = Closed Won):
1. One Get Records for the lines; loop builds one Equipment per unit (quantity 3 → 3 units).
2. One Create Records for all units, one Draft Coverage Plan (Start = Close Date, End = +12 months − 1 day, Standard), one Create Records for all Equipment Coverage links.
3. Fault paths → Custom Error `{!$Label.HES_Err_Generic}`.
Bulk-safe: no DML inside loops. Tested: 3 units, plan CP-0004 with Covered Units 3, no duplicates on later edits.

---

## Module 5 – Service intake

### INT-01 / INT-02 Email-to-Case (5-01)
Support mailbox (Gmail) forwards to the Email-to-Case services address. Routing address **HES Support**: Origin Email, Priority Medium, **Case Owner blank** (see INT-05). Lightning threading on.

### INT-03 Web-to-Case (5-02, 6-01)
Website `service.html` sends name, email, phone, company, subject, description (serial number merged in), Equipment Type, Priority (shown as "Urgency"), **Type** (Breakdown / Maintenance / Installation) and the hidden **recordType = Technical**. The record type ID lives only in the web page.

### INT-04 Acknowledgements (5-03)
**Case_AfterSave** outcome *New Genuine Case* (new and Reason ≠ Junk) → *Which Channel?*: Origin Email → alert **HES Case Ack Email**; Origin Web (with Web Email) → **HES Case Ack Web**. Fault path → Task "Acknowledgement email failed" (never a Custom Error: a failed email must not roll back the customer's case).
Open item: web acknowledgement not arriving although the flow runs the action (see test-evidence.md). First check: the alert's recipients (Email Field: Web Email) and From address are saved.

### INT-05 Routing (5-04)
Assignment rule **HES Case Routing** (active), first match wins:

| Order | Criteria | Assign to |
|---|---|---|
| 1 | Case Reason = Junk | Do Not Reassign Owner |
| 2 | Case Record Type = Billing (added after 6-01) | Billing queue |
| 3–6 | Account Region = Benelux / Nordics / DACH / UK & Ireland | matching Technical queue |
| 7 | Formula `TRUE` | Service Triage |

Behaviour:
- Email-to-Case and Web-to-Case: the rule always runs on creation.
- Account (and Account Region) is only set when the sender's email matches exactly **one** contact. If several contacts share the email, none is linked and the case goes to Service Triage.
- Manual create or edit: the rule runs only when the user ticks "Assign using active assignment rule". The box is shown but **not ticked by default**, so editing an assigned case does not pull it back into a queue.
- Data loads and API updates do not run the rule unless the assignment rule header is set.
- Decision: the routing address **Case Owner is left blank**. When it was filled, Email-to-Case used that owner and skipped the assignment rule (found in testing). Without it the Default Case Owner (admin, a user) applies, so junk cases stay out of every queue.
- Decision: entry 7 uses formula `TRUE` as an explicit catch-all.

Queues (queues have no description field):

| Queue | Purpose |
|---|---|
| Benelux Technical | Technical cases from Benelux accounts |
| Nordics Technical | Technical cases from Nordics accounts |
| DACH Technical | Technical cases from DACH accounts |
| UK & Ireland Technical | Technical cases from UK & Ireland accounts |
| Billing | Billing cases from any region |
| Service Triage | Fallback when no routing rule matches |

### INT-06 Junk (5-05)
**Case_Before_Save** outcome *New Case*: reads active **Junk Rule** custom metadata (one query), loops, and when `fxMatches` is true sets Status = Closed and Reason = Junk. Runs before assignment rules and before Case_AfterSave, so junk is never routed (rule entry 1) and never acknowledged (Reason ≠ Junk check). Fault path appends "[Junk check skipped: …]" to Description so the case is still created. `fxMatches` ignores blank match values and is case-insensitive.

---

## Module 6 – Service handling

### SVC-01 Technical and Billing (6-01)
- Support process **HES Support Process** (New, Working, Escalated, Closed) used by both record types.
- Record types Technical (default) and Billing; Type values per record type (see data-model.md).
- Layouts: **Case - Technical** (Equipment & Coverage, Scheduling sections) and **Case - Billing** (Billing Details: Invoice Reference; no effort or scheduling fields). Master keeps Case Layout for old cases.
- Lightning pages **Case Technical Page** (Work Segments and Required Skills cards) and **Case Billing Page**, activated per record type for the Sales app (add the service apps when they exist).
- Email-to-Case cases get the default record type Technical; a billing email is changed to Billing by the dispatcher.

### SVC-02 Effort before assignment (6-02)
Validation rule **Effort_Required_Before_Assignment**:
```
AND(
  NOT($Permission.Bypass_Validation_Rules),
  RecordType.DeveloperName = "Technical",
  ISCHANGED(OwnerId),
  NOT(ISBLANK(Owner:User.Id)),
  OR(ISBLANK(Estimated_Effort__c), Estimated_Effort__c <= 0)
)
```
Only Technical cases, only when the owner changes to a **user** (queues allowed), bypass for data loads. Uses the record type developer name, not an ID.

### SVC-03 Coverage position (6-03, 6-04)
- Equipment `Coverage_Position__c`:
```
IF( OR( ISBLANK(Current_Coverage_Plan__c), ISPICKVAL(Current_Coverage_Plan__r.Status__c, "Draft") ), "Not Covered",
  IF( OR( ISPICKVAL(Current_Coverage_Plan__r.Status__c, "Expired"), Current_Coverage_Plan__r.End_Date__c < TODAY() ), "Expired",
    IF( Current_Coverage_Plan__r.Start_Date__c <= TODAY(), "Covered", "Not Covered" ) ) )
```
- Case `Coverage_Position__c` = `IF(ISBLANK(Equipment__c), "Not Covered", Equipment__r.Coverage_Position__c)`; `Covered_Hours__c` = effort when Covered, else 0.
- **Coverage_Plan_After_Save** (only when updated to meet Status = Active): one Get Records of the plan's Equipment Coverage links, loop builds the units, one Update sets **Current Coverage Plan**. Fault → Custom Error `{!$Label.HES_Coverage_Activation_Failed}` (rolls back the activation).
- Trade-off (defend at review): the value Covered/Expired/Not Covered is **never stored**; only the reference to the current plan is maintained. The formula is always correct on read (no stale value when a plan expires overnight) at the cost of not being usable in some filters/roll-ups. `TODAY()` uses the user's time zone (Europe/Amsterdam), so a plan starting "tomorrow" in Amsterdam shows Not Covered until midnight there.

### SVC-04 Required skills (6-05)
- Skills: Chiller, Compressor, Air Dryer, Electrical, Refrigerant Handling.
- Case Skill junction shown as the **Required Skills** card on the Case Technical Page (columns Skill Name, Skill Description).
- **Case_Skill_Before_Save**: blocks the same skill twice on one case with `{!$Label.HES_Duplicate_Case_Skill}` (or the label name actually used) and stamps `Unique_Key__c` (unique field as the database-level guard for bulk loads).
- Future (not in scope): engineer skills (User ↔ Skill) to enable skill-based assignment, as hinted by the SVC-04 example.

### SVC-05 Closure (6-06)
**Case_AfterSave** outcome *Just Closed* (`IsClosed` changed to true and Reason ≠ Junk):
1. *Has Equipment?* → Update the unit's **Last Service Date** = `$Flow.CurrentDate`.
2. Email alert **HES Case Satisfaction** (Related Contact + Web Email, From Helios Service Desk).
3. Fault paths → Task "Closure follow-up failed".
Removing work segments dated after today is owned by the **Apex scheduling service via the Case trigger (7-06)**, so the rule lives in one place.
Support Settings › "Show Closed Statuses in Case Status Field" is on so engineers can close from the Status field.

### SVC-06 Reopen (6-07)
**Case_Before_Save** outcome *Reopened* (`fxReopened`: not new, was closed, Status ≠ Closed, record type Technical): Schedule Status = Unscheduled, Needs Replanning = true, Planned Start/Finish cleared. No planning here: the next owner change or effort change replans (7-02). In a before-save flow `IsClosed` may still hold the old value, so the current state is checked with Status.

---

## Decisions log (summary)

| # | Decision | Reason | Where |
|---|---|---|---|
| D1 | 3 users play 7 personas | Only 2 free Salesforce licences | persona-mapping.md, SRS v1.2 |
| D2 | Classic text email templates everywhere | Lead merge fields and approval emails need Classic; consistent retrieval | 4-02, 4-07, 5-03, 6-06 |
| D3 | Routing address Case Owner blank | A filled owner bypasses the assignment rule | 5-04 |
| D4 | Assignment checkbox shown but not ticked by default | Editing an assigned case must not re-route it | 5-04, 6-06 |
| D5 | Catch-all routing entry uses formula TRUE | Explicit, readable fallback | 5-04 |
| D6 | Account sharing rule to the service team, Case access Private | Change Owner needs account access; engineers must still see only their cases | 6-02 |
| D7 | Coverage value derived by formula, reference maintained by flow | Brief SVC-03: value must not be stored | 6-03, 6-04 |
| D8 | Engineers may hand their own case back to a queue | Real-world need; SVC-02 still applies | 6-02 |
| D9 | Future segments removed by Apex only | One owner per rule | 6-06, 7-06 |
| D10 | Flow API names | Older flows `Object_AfterSave`; newer ones `Object_Before_Save` / `Object_After_Save` (Salesforce default). Confirm exact names with `sf org list metadata --metadata-type Flow`; see automation-inventory.md | all |


Bulk Safe Test: 

PS C:\src\HES> sf apex run --file scripts/apex/bulk-test.apex | Select-String "BULK"

Execute Anonymous: // 7-04 bulk check (CAP-07). Change N to 1, then 50, and compare the numbers.
Execute Anonymous:         cs.add(new Case(Subject = 'Bulk test ' + i, RecordTypeId = rt, OwnerId = queueId,
Execute Anonymous:     System.debug('BULK N=' + N
Execute Anonymous:     System.debug('BULK ERROR: ' + e.getMessage());
16:34:01.643 (3637849049)|USER_DEBUG|[21]|DEBUG|BULK N=50 &#124; SOQL 8 (limit 100) &#124; DML statements 3 &#124; DML rows 168 &#124; CPU ms 259 &#124; segments created 68


PS C:\src\HES> sf apex run --file scripts/apex/bulk-test.apex | Select-String "BULK"

Execute Anonymous: // 7-04 bulk check (CAP-07). Change N to 1, then 50, and compare the numbers.
Execute Anonymous:         cs.add(new Case(Subject = 'Bulk test ' + i, RecordTypeId = rt, OwnerId = queueId,
Execute Anonymous:     System.debug('BULK N=' + N
Execute Anonymous:     System.debug('BULK ERROR: ' + e.getMessage());
16:37:13.40 (588945346)|USER_DEBUG|[21]|DEBUG|BULK N=1 &#124; SOQL 8 (limit 100) &#124; DML statements 3 &#124; DML rows 5 &#124; CPU ms 93 &#124; segments created 3

