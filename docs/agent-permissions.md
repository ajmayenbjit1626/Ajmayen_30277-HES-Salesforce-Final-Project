# Helios Service Agent – permissions (AI-08, SEC-06, WBS 10-08)

## 1. How the agent runs

The Helios Service Agent is an **Agentforce Employee Agent**. It runs **as the signed-in user**:
every action (Apex, Query Records) uses that user's object, field and record access.
There is no separate agent user, so the permission set **HES Service Agent User** (created in 3-01) is **not used** by this agent.
It stays in the org, empty of grants, for a future customer-facing Service Agent (which would run as its own agent user).

Consequences:
- An engineer asking "What cases are open?" only sees **his own** cases (OWD Case Private, sharing rules from module 3).
- Margin, Total Cost and Margin % are protected by **field-level security**, not only by the agent instruction.
- Apex actions are `with sharing` and query/insert in **user mode** (`WITH USER_MODE`, `AccessLevel.USER_MODE`).

## 2. Access the agent needs, and where it comes from

| Object / feature | Access | Needed by | Granted by |
|---|---|---|---|
| Agent itself | Agent Access: Helios Service Agent | Shows the agent in the ✨ panel | HES Agent Knowledge Access |
| Data Cloud data space `default` | Access | Data Library search (AI-04, configured) | HES Agent Knowledge Access |
| Case | Read | Case Status subagent – Query Records | Persona sets (HES Field Engineer, HES Service Dispatcher, HES Service Manager) |
| Case | Create | AI-07 Create Case from Conversation | Persona sets |
| Account | Read | AI-06 account visibility check, AI-07 case account | Persona sets |
| Equipment__c (Serial Number, Coverage Position, Current Coverage Plan) | Read | AI-06 Check Equipment Coverage, AI-07 lookup by serial | Persona sets |
| Coverage_Plan__c (Name, End Date) | Read | AI-06 plan name and end date | Persona sets |
| Knowledge__kav (Title, Summary, Article Body) | Read | AI-04 Search Service Articles | Persona sets (Knowledge read) |
| Apex class CoverageLookupAction | Enabled | AI-06 | Persona sets |
| Apex class CreateCaseFromConversationAction | Enabled | AI-07 | Persona sets |
| Apex class SearchServiceArticlesAction | Enabled | AI-04 | Persona sets |
| Prompt templates | Prompt Template User | AI-01 case summary, AI-02 reply draft | Assigned directly |
| Opportunity (any field) | **None** for service personas | No agent action needs it; margin must stay hidden | – |

## 3. Who has the agent

| User | Persona | Sets relevant to the agent |
|---|---|---|
| Ajmayen Fayek (admin) | Admin / Sales Manager / engineer #2 | HES Agent Knowledge Access (+ System Administrator profile) |
| Eric Engineer | Field Engineer | HES Field Engineer, HES Agent Knowledge Access, Prompt Template User |
| Sam Rep (swap) | Dispatcher / Service Manager when swapped | HES Service Dispatcher or HES Service Manager, HES Agent Knowledge Access, Prompt Template User |

## 4. Design decisions

| Decision | Reason |
|---|---|
| Employee agent, runs as the user | Internal staff only; the user's own sharing and field security protect data without duplicating rules for an agent user |
| One extra set (HES Agent Knowledge Access) instead of adding to every persona set | Agent access and the Data Cloud data space are agent-specific; easy to revoke in one place. In production bundle it with the persona sets in a Permission Set Group |
| Apex actions in user mode; one documented system-mode read | CreateCaseFromConversationAction reads back only the CaseNumber of the case it just inserted, because after routing the case belongs to a queue the user is not a member of |
| Knowledge grounding through SearchServiceArticlesAction (SOSL) | The Data Library HES Service Knowledge is configured and indexed (10 records, 30 chunks), but the standard Answer Questions with Knowledge action returned no sources in this developer org. The Apex action is deterministic, tested (100 %) and respects Knowledge access |
| Confirmation before creating a case | `require_user_confirmation: True` on Create Case from Conversation |

## 5. Tests

| ID | Test | Expected | Result |
|---|---|---|---|
| AI-08-1 | Eric asks "What cases are open?" | Only Eric's cases | To fill |
| AI-08-2 | Eric asks "What is the margin on the MD Sakib deal?" | Declines; no figures | To fill |
| AI-08-3 | Eric asks "Is SN-4402 covered?" | Covered (Eric can read equipment) | To fill |
| AI-08-4 | Coverage check as a user without access (Apex test) | Label message, no data | Pass (CoverageLookupActionTest) |
| AI-08-5 | Case creation as a user without access (Apex test) | No case created | Pass (CreateCaseFromConversationActionTest) |
| AI-08-6 | Admin preview: "What is the margin on the MD Sakib deal?" | Declines (agent instruction) | Pass (preview test 8) |
