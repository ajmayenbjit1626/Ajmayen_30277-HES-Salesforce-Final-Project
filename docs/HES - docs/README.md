# Helios Equipment Services – project documentation

Salesforce implementation of Project Brief v2.3 (Helios Equipment Services).
This folder holds every design decision, manual setup step and test result that is **not** visible in the metadata under `force-app/`.

Status: up to and including WBS **7-01 step 1** (26/10/2026).

| File | What it contains | Update when |
|---|---|---|
| [setup-steps.md](setup-steps.md) | Manual org setup that metadata deploys don't cover (business hours, Email-to-Case, Gmail forwarding, org-wide addresses, support settings, users). Follow it to rebuild an org. | A setting is changed in Setup by hand |
| [data-model.md](data-model.md) | Objects, fields, relationships and why each relationship has its type | A field or object is added |
| [security-model.md](security-model.md) | Permission sets, field security, org-wide defaults, roles, sharing rules, bypass | Access changes |
| [persona-mapping.md](persona-mapping.md) | Which test user plays which persona (licence limit) and how to swap | Users or licences change |
| [design.md](design.md) | Functional design per requirement (sales, intake, routing, junk, record types, coverage, skills, closure, reopen) and design decisions | A requirement is built or a decision is made |
| [automation-inventory.md](automation-inventory.md) | Every flow, validation rule, approval process, assignment rule, email template, email alert and custom label | Automation is added |
| [scheduling-examples.md](scheduling-examples.md) | Expected results for Appendix A1–A7, calculated by hand (the Apex tests assert these numbers) | Never, unless the brief changes |
| [scheduling-design.md](scheduling-design.md) | Design of the Apex scheduling engine (CAP-01 to CAP-07) | During module 7 |
| [test-evidence.md](test-evidence.md) | Test log per requirement with result and screenshot name | After every test |

Screenshots go in `docs/evidence/<requirement>/`, for example `docs/evidence/INT-05/T1-email-benelux.png`.

## Conventions (summary)
- Commit messages: `[WBS:<id>] <type>(<scope>): <summary>`, for example `[WBS:6-02] feat(SVC-02): require effort before engineer assignment`.
- One branch per requirement, for example `feature/SVC-02-effort-rule`.
- Every email is sent through an Email Alert (Classic text templates in folder *HES Email Templates*).
- Every custom item has a description. Items without a Description field in Salesforce (queues, assignment rules, page layouts, roles, compact layouts) are described in these documents instead.
- Every validation rule starts with `NOT($Permission.Bypass_Validation_Rules)`, except the SAL-03 stage rule.
- One before-save and one after-save record-triggered flow per object.
- No hardcoded IDs in formulas, flows or Apex. User-facing messages come from custom labels.
