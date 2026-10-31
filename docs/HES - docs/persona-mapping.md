# Persona-to-User Mapping (HES)

**Why this exists:** the development org has only 2 free Salesforce licences (4 total, 2 used).
Salesforce Platform licences can't be used because they exclude Leads, Opportunities and Cases.
So 3 users cover all 7 personas. Recorded in SRS v1.2 (assumptions, revision 1.2).
If the reviewer provides an org with 9 or more Salesforce licences, create one user per persona instead (see 3-01 step 4 table).

## 1. Who plays whom

| User | Licence | Permanent persona | Permission set(s) | Role (3-02) | Manager | Default Working Hours / Is Scheduled |
|---|---|---|---|---|---|---|
| Admin (you) | Salesforce (existing) | Sales Manager approver, scheduled engineer #2, Service Manager / Dispatcher for setup work | System Administrator profile (no persona set needed) | Sales Manager | none | 8 / ticked |
| Sam Rep | Salesforce | Sales Representative | HES Sales Representative | Sales Representative | Admin | blank / unticked (not an engineer) |
| Eric Engineer | Salesforce | Field Engineer (always) | HES Field Engineer | Field Engineer | none | 8 / ticked |

Rules:
- **Eric always stays an engineer**, so cases he owns keep testing engineer visibility and the dispatcher sharing rule.
- **Sam is the "swap" user** for the office personas. The admin can't prove restrictions because the admin sees everything.
- **The admin has the Sales Manager role**, so opportunities the admin owns are shared to Finance by the "Pipeline to finance" rule.
- **Admin + Eric are the 2 scheduled engineers.** Part-time and not-scheduled scenarios are shown by changing Default Working Hours (e.g. 4) and Is Scheduled on one of them, then putting it back.

## 2. Persona test matrix

| Persona to test | Log in as | Temporary permission set | Temporary role | Typical test |
|---|---|---|---|---|
| Sales Representative | Sam | (as is) | (as is) | Sees only own leads and opportunities; can't see Total Cost, Margin, Margin % |
| Sales Manager | Admin (approvals); Sam for field-security checks | HES Sales Manager | Sales Manager | Approves 20% discount; sees margin fields |
| Finance Approver | Sam | HES Finance Approver | Finance Approver | Opportunities owned by the admin are visible and read-only |
| Service Dispatcher | Sam | HES Service Dispatcher | Service Dispatcher | Sees every open case (sharing rule "Open cases to dispatchers"); closed cases owned by others are hidden |
| Field Engineer | Eric | (as is) | (as is) | Sees only own cases; can edit them |
| Service Manager | Sam | HES Service Manager | Service Manager | Sees all cases (View All Records); creates coverage plans |
| Agent user | Agentforce agent user (own licence, 10-08) | HES Service Agent User | n/a | Coverage lookup works; margin is not reachable |

## 3. How to swap Sam to another persona (and back)

1. Setup › Users › Users › **Sam Rep** › **Permission Set Assignments** › **Edit Assignments**.
2. Move **HES Sales Representative** to *Available*, move the persona's set (e.g. **HES Finance Approver**) to *Enabled* › **Save**.
3. Back on Sam's user record › **Edit** › **Role**: the persona's role › **Save**. (Skip until 3-02 has created roles.)
4. Setup › Users › **Login** next to Sam Rep › run the test › take screenshots for the test evidence.
5. Log out › reverse steps 1-3 (back to HES Sales Representative + Sales Representative role).
6. In the test evidence, write: *"Tested with Sam Rep temporarily holding <set> and <role>"*.

Notes:
- Records Sam owns stay his after a swap. When testing Finance or Dispatcher, use records owned by the admin or Eric, not Sam.
- Changing a role recalculates sharing; wait a few seconds before logging in.

## 4. Impact on later WBS tasks

| WBS | Change because of the licence limit |
|---|---|
| 3-01 | Create only Sam Rep (Manager = Admin) and Eric Engineer; assign HES Sales Representative and HES Field Engineer |
| 3-02 | Roles: Admin = Sales Manager, Sam = Sales Representative, Eric = Field Engineer |
| 4-07 | Approver = Sam's Manager = Admin |
| 5-04 | Admin is a member of every queue |
| 6-02, 7-x | Engineers available to the scheduling engine: Eric and the admin |
| 7-08 | Apex tests insert test engineer users; if the org returns LICENSE_LIMIT_EXCEEDED, the test data factory must be adapted (raise it then) |
| 11-01 | Seed creates cases for Eric and the admin instead of 8 engineers |
| 11-03 | Demo script includes the swap steps above between scenes |
