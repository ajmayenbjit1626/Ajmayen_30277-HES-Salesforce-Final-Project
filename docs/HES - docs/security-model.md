# Security model (ACC-01 to ACC-04)

All persona users have the profile **Minimum Access - Salesforce**. Every real permission comes from a **permission set**, so onboarding a user means assigning one set (ACC-01). The profile only carries the record type defaults (permission sets cannot set a default record type).

## Permission sets

| Permission set | Persona | Description (as in Salesforce) |
|---|---|---|
| HES Sales Representative | Sales rep | Manages own leads, accounts, contacts and opportunities; reads equipment and coverage. |
| HES Sales Manager | Sales manager | Everything a rep has, plus team visibility and discount approvals. |
| HES Finance Approver | Finance | Read-only on accounts, opportunities and products; approves large discounts. |
| HES Service Dispatcher | Dispatcher | Creates and assigns service cases, sets effort and skills, sees engineer capacity. |
| HES Field Engineer | Field engineer | Reads and updates the cases assigned to them; sees their planned work. |
| HES Service Manager | Service manager | Full access to cases, equipment, coverage plans and skills; sees all cases. |
| HES Service Agent User | Agentforce agent | Read-only coverage lookup and case creation (filled in 10-08). |
| HES Data Loader | Data load only | Grants the custom permission **Bypass Validation Rules**. Assigned only during data loads (11-01), then removed. |

All persona sets also grant the system permission **Lightning Experience User**.

## Object access (C = Create, R = Read, E = Edit, VA = View All; no Delete or Modify All anywhere)

| Object | Rep | Sales Mgr | Finance | Dispatcher | Engineer | Service Mgr |
|---|---|---|---|---|---|---|
| Lead | CRE | CRE | – | – | – | – |
| Account | CRE | CRE | R | R | R | R VA |
| Contact | CRE | CRE | R | CRE | R | CRE |
| Opportunity | CRE | CRE | R | – | – | R |
| Product / Price Book | R | R | R | – | – | – |
| Case | – | – | – | CRE | RE | CRE VA |
| Equipment | R | R | R | RE | R | CRE |
| Coverage Plan | R | R | R | R | R | CRE |
| Equipment Coverage | R | R | R | R | R | CRE |
| Skill | – | – | – | R | R | CRE |
| Case Skill | – | – | – | CRED | R | CRED |
| Capacity | – | – | – | R | R | R |
| Work Segment | – | – | – | R | R | R |

Case Skill Delete for Dispatcher and Service Manager lets them remove a wrongly added skill (6-05).

## Case record types per set (6-01)
| Set | Technical | Billing |
|---|---|---|
| Service Dispatcher, Service Manager, Data Loader | ✔ | ✔ |
| Field Engineer | ✔ | – |

## Field-level security highlights
- **Opportunity cost and margin (ACC-04):** Total Cost, Margin, Margin Percent are hidden from the Sales Representative. Sales Manager: Total Cost Read+Edit, Margin and Margin % Read. Finance and Service Manager: Read only. Discount: Rep and Manager Read+Edit, Finance Read.
- **Case for Field Engineer (corrected in 6-02 testing):** Read on Subject, Description, Account, Contact, Priority, Type, Origin, Reason, Equipment, Equipment Type, Estimated Effort, Coverage Position, scheduling fields and Web fields; Edit only on Status and Internal Comments. No access to Invoice Reference.
- **Coverage Position / Covered Hours (6-03):** Read for Field Engineer, Dispatcher, Service Manager (Covered Hours: Dispatcher and Service Manager).
- **Case Skill Unique Key:** System Administrator only (set by flow, which runs in system context).

## Organization-wide defaults (ACC-02)

| Object | Internal | Reason |
|---|---|---|
| Lead, Account, Opportunity, Case | Private | Owners and the role hierarchy see records; sharing rules open them on purpose |
| Contact | Controlled by Parent | Follows the account |
| Equipment, Coverage Plan, Skill | Public Read/Write | Shared reference data; object permissions decide who can edit |
| Capacity | Public Read Only (target) | Everyone can see capacity; only the engine writes it. If the org still shows Public Read/Write, change it (noted in 6-02) |
| Equipment Coverage, Case Skill, Work Segment | Controlled by Parent | Master-detail |
| External access | Private on every row | No community users |

## Role hierarchy (roles have no description field)

```
HES Leadership
├── Sales Manager            ← admin
│   └── Sales Representative ← Sam Rep
├── Finance Approver         (Sam when testing Finance)
└── Service Manager          (Sam when testing Service Manager)
    ├── Service Dispatcher   (Sam when testing Dispatcher)
    └── Field Engineer       ← Eric Engineer
```

## Sharing rules

| Object | Rule | Type | From | To | Access | Why |
|---|---|---|---|---|---|---|
| Opportunity | Pipeline to finance | Owner | Roles and Subordinates: Sales Manager | Role: Finance Approver | Read Only | Finance sits beside Sales in the hierarchy |
| Opportunity | Pipeline to service manager | Owner | Roles and Subordinates: Sales Manager | Role: Service Manager | Read Only | ACC-04: service manager sees cost and margin on the same deal |
| Case | Open cases to dispatchers | Criteria: Status ≠ Closed | – | Role: Service Dispatcher | Read/Write | ACC-02: dispatcher sees every open case |
| Account | Accounts to service team (added 6-02) | Owner | Public Group: All Internal Users | Roles and Subordinates: Service Manager | Account Read Only; Contact Read Only; **Opportunity Private; Case Private** | Change Owner on a case fails with "no sharing access to parent account" if the dispatcher cannot read the account. Case Access must stay Private, otherwise engineers see every case of the account (found in testing) |

## Queues (5-04)
Six Case queues, each with members **Role: Service Dispatcher** and **User: admin** (licence limit). Queue Email blank, Send Email to Members unticked. The Service Manager sees queue records through the role hierarchy.

## Bypass (ACC-03)
- Custom permission **Bypass_Validation_Rules**, granted only by **HES Data Loader**.
- Every validation rule begins with `NOT($Permission.Bypass_Validation_Rules)` except `Opportunity.Negotiation_Requires_Equipment_Lines` (SAL-03, deliberately never bypassed).
- Tested with `scripts/apex/bypass-test.apex` (BLOCKED without the set, SAVED with it).

## Who can change a case owner
- Dispatcher and Service Manager: queue members / sharing; they assign work.
- Field Engineer: only cases he owns (standard owner right). Design decision: an engineer may hand his own case back to a queue; the SVC-02 rule still blocks giving it to another engineer without effort. A stricter "Assign Cases" custom permission was considered and not built (not required by the brief).

### Regional service groups (ACC-02-R1)
| Group | Members | Used by |
|---|---|---|
| HES Benelux Service | Benelux dispatchers (test: Sam Rep) | Queue Benelux Technical; sharing rule "Benelux open cases to Benelux service" |
| HES Nordics Service | Nordics dispatchers | Nordics sharing rule (+ queue when created) |
| HES DACH Service | DACH dispatchers | DACH sharing rule (+ queue when created) |
| HES UKI Service | UK & Ireland dispatchers | UKI sharing rule (+ queue when created) |
Grant Access Using Hierarchies: on (Service Manager sees the same cases).