# Data model

Built in Schema Builder (WBS 2-01 to 2-05). Every object and field has a description in Salesforce.

## Custom objects

| Object | API name | Record name | Purpose | Tab |
|---|---|---|---|---|
| Equipment | `Equipment__c` | Equipment Name (text) | One installed unit at a customer site | Yes |
| Coverage Plan | `Coverage_Plan__c` | Plan Number, auto `CP-{0000}` | Service contract covering one or more units for a period | Yes |
| Equipment Coverage | `Equipment_Coverage__c` | Coverage Link, auto `EC-{00000}` | Junction: which units a plan covers (history kept) | No |
| Skill | `Skill__c` | Skill Name (text) | Catalogue of technical skills | Yes |
| Case Skill | `Case_Skill__c` | auto `CS-{00000}` | Junction: skills a case requires (SVC-04) | No |
| Capacity | `Capacity__c` | auto `CAP-{000000}` | One engineer-day of working capacity | No |
| Work Segment | `Work_Segment__c` | auto `WS-{000000}` | One planned block of an engineer's time for a case on one date | No |

## Relationships

| Child | Field | Type | Parent | Reason |
|---|---|---|---|---|
| Equipment | Account | Lookup (required) | Account | A unit always belongs to a customer; deleting an account must not silently delete installed-base history |
| Equipment | Product | Lookup | Product | Model of the unit, for reporting by product |
| Equipment | Opportunity | Lookup | Opportunity | Deal that sold the unit (SAL-06) |
| Equipment | Current Coverage Plan | Lookup | Coverage Plan | The single current plan read by the Coverage Position formula (SVC-03); maintained by Coverage Plan After Save |
| Coverage Plan | Account | Lookup | Account | Customer of the plan |
| Coverage Plan | Opportunity | Lookup | Opportunity | Deal that created the draft plan (SAL-07) |
| Equipment Coverage | Equipment | Master-Detail | Equipment | Junction side 1; link cannot exist without its unit |
| Equipment Coverage | Coverage Plan | Master-Detail | Coverage Plan | Junction side 2; Covered Units roll-up |
| Case | Equipment | Lookup | Equipment | Unit the service case is about |
| Case Skill | Case | Master-Detail | Case | Junction side 1; access follows the case |
| Case Skill | Skill | Master-Detail | Skill | Junction side 2; reportable by skill |
| Capacity | Engineer | Lookup (required, validation rule Engineer_Required) | User | Whose working day this is |
| Work Segment | Case | Master-Detail (primary) | Case | Created first so Case controls access; Planned Hours roll-up |
| Work Segment | Capacity | Master-Detail (secondary) | Capacity | Engineer-day the work is booked against |

## Fields on standard objects

| Object | Field | Type | Notes |
|---|---|---|---|
| Account | Region__c | Picklist (restricted): Benelux, Nordics, DACH, UK & Ireland | Drives routing and regional reports |
| Lead | Equipment_Type__c, Site_Postcode__c, Indicative_Budget__c, Region__c | Picklist / Text(20) / Currency / Picklist | Web-to-Lead enquiry fields, mapped on conversion (SAL-02) |
| Opportunity | Equipment_Type__c, Site_Postcode__c, Indicative_Budget__c, Discount__c, Total_Cost__c | | Cost restricted by field security (ACC-04) |
| Opportunity | Margin__c, Margin_Percent__c | Formula | Restricted (ACC-04) |
| Opportunity | Deal_Health__c | Formula (Text) | At Risk / Healthy from HES Setting At_Risk_Days__c (SAL-04) |
| Opportunity | Approval_Submitted_At__c, Approval_Decided_At__c, Approval_Hours__c | Date/Time, Date/Time, Formula | Discount approval timing (SAL-05, AN-04) |
| Case | Equipment__c | Lookup(Equipment) | |
| Case | Equipment_Type__c | Picklist (restricted): Chiller, Compressor, Air Dryer | From the web form |
| Case | Estimated_Effort__c | Number(3,2) | Required > 0 before assignment to an engineer (SVC-02) |
| Case | Planned_Start__c, Planned_Finish__c | Date | Set by the scheduling engine (CAP-04) |
| Case | Planned_Hours__c | Roll-up SUM of Work Segment Planned Hours | CAP-04 reconciliation |
| Case | Schedule_Status__c | Picklist (restricted): Unscheduled (default), Scheduled, Unplaceable | |
| Case | Needs_Replanning__c | Checkbox | Set on reopen (SVC-06) and by nightly roll-forward (CAP-06) |
| Case | Account_Region__c | Formula Text `TEXT(Account.Region__c)` | Used by assignment rules and reports |
| Case | Coverage_Position__c | Formula Text | Reads `Equipment__r.Coverage_Position__c`; Not Covered when no equipment (SVC-03) |
| Case | Covered_Hours__c | Formula Number | Effort when Covered, else 0 (AN-02) |
| Case | Invoice_Reference__c | Text(30) | Billing cases only |
| Case | AI_Summary__c | Long Text Area(5000) | Filled by the AI-01 prompt (module 10) |
| User | Default_Working_Hours__c, Is_Scheduled__c | Number (default 8), Checkbox (default true) | CAP-01 |

## Fields on custom objects

| Object | Field | Type | Notes |
|---|---|---|---|
| Equipment | Serial_Number__c | Text(40), Unique, External ID, not required | Entered at installation |
| Equipment | Install_Date__c, Last_Service_Date__c | Date | Last Service Date stamped on closure (SVC-05) |
| Equipment | Coverage_Position__c | Formula Text | Covered / Expired / Not Covered (see design.md, SVC-03) |
| Equipment | Coverage_Count__c | Roll-up COUNT of Equipment Coverage | |
| Coverage Plan | Start_Date__c, End_Date__c | Date (required) | |
| Coverage Plan | Service_Level__c | Picklist: Standard (default), Premium, Critical | |
| Coverage Plan | Status__c | Picklist: Draft (default), Active, Expired | |
| Coverage Plan | Covered_Units__c | Roll-up COUNT of Equipment Coverage | |
| Skill | Description__c | Text Area(255) | |
| Case Skill | Unique_Key__c | Text(40), Unique (case-insensitive) | Case Id + "-" + Skill Id, set by Case Skill before-save flow |
| Capacity | Capacity_Date__c | Date (required) | |
| Capacity | Available_Hours__c | Number(2,2) | |
| Capacity | Capacity_Key__c | Text(40), Unique, External ID | Engineer Id + date; lets the engine upsert one capacity per engineer-day |
| Work Segment | Planned_Date__c, Planned_Hours__c | Date, Number(2,2) (both required) | |

## Custom metadata types

| Type | Fields | Records |
|---|---|---|
| HES Setting (`HES_Setting__mdt`) | Horizon_Days__c, Business_Hours_Name__c, At_Risk_Days__c | Default: 60 / HES Working Week / 90 |
| Junk Rule (`Junk_Rule__mdt`) | Field_To_Check__c (Subject, Supplied Email, Description), Match_Value__c, Active__c | Newsletter, Unsubscribe, Out Of Office, Marketing Sender |

## Standard picklist values added
- Case Reason: **Junk**. Case Origin: **Agentforce**. Lead Source: **Trade Event**.
- Case Type: **Breakdown, Maintenance, Installation** (Technical), **Invoice Query, Payment** (Billing). Old sample values deleted.
- Case Status (HES Support Process): New, Working, Escalated, Closed.
- Product Family: Chiller, Compressor, Air Dryer.
- Opportunity Stage: Qualification, Needs Analysis, Proposal/Price Quote, Negotiation/Review, Closed Won, Closed Lost.

## Record types
| Object | Record type | Process | Layout | Lightning page | Default |
|---|---|---|---|---|---|
| Case | Technical | HES Support Process | Case - Technical | Case Technical Page | Yes (System Administrator, Minimum Access - Salesforce) |
| Case | Billing | HES Support Process | Case - Billing | Case Billing Page | No |
| Case | Master | – | Case Layout | default | Older cases only |
