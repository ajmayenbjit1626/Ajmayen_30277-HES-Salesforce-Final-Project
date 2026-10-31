# Scheduling engine design (CAP-01 to CAP-07)

Status: **draft for WBS 7-01 steps 2–5**, to be confirmed while building module 7.

## Why Apex
The brief makes Apex mandatory here: planning reads across other cases and other engineers and must handle 200 cases in one transaction, which a flow cannot do safely in bulk. The nightly job (CAP-06) is a scheduled flow that calls the same invocable Apex.

## Classes

| Class | Sharing | Responsibility |
|---|---|---|
| `CaseTrigger` (after insert, after update) | – | Thin: passes `Trigger.new` / `Trigger.oldMap` to the handler. One trigger on Case. |
| `CaseTriggerHandler` | inherited sharing | Decides per case which event happened: (1) owner queue → user, (2) effort changed on a scheduled case, (3) reassigned user → user, or closure. Ignores every other change (CAP-02). |
| `CaseSchedulingService` | **inherited sharing** | `planCases(…)`, `removeFutureSegments(…)`, `rollForwardStale(…)`. All queries and DML outside loops. |
| `WorkingCalendar` | inherited sharing | `isWorkingDay(Date)` from Business Hours named in HES Setting + its holidays. One query, cached. |
| `NightlyRollForwardAction` | with sharing (invocable) | Entry point for the nightly scheduled flow (CAP-06). |
| `TestDataFactory`, `CaseSchedulingServiceTest`, `CaseTriggerHandlerTest`, `WorkingCalendarTest` | – | Appendix A1–A7, bulk, negative paths. |

## Planning events (CAP-02)

| Event | Detected by | Action |
|---|---|---|
| Owner changes from a queue to a user | old owner starts with queue prefix (via `Schema.SObjectType`/`Group` check, not a hardcoded Id), new owner is a User | Plan full effort from today |
| Effort changes on an already scheduled case | `Estimated_Effort__c` changed and Schedule Status ≠ Unscheduled | Remove future segments, replan outstanding effort for the same engineer |
| Reassigned user → user | both old and new owner are users, different | Remove engineer 1's segments dated after today; plan outstanding = effort − hours kept, for engineer 2 |
| Closed | `IsClosed` changed to true | Remove segments dated after today (SVC-05 / CAP-05), no planning |
| Anything else (subject, reopen…) | – | Nothing (reopen is handled by Case_Before_Save, 6-07) |

## Algorithm (CAP-03), bulk-safe outline
1. Collect affected cases and their engineers (one map).
2. One query: engineers' `Default_Working_Hours__c`, `Is_Scheduled__c`.
3. One query: existing work segments of those engineers between today and today + horizon → map *engineer + date → hours booked*.
4. For each case (sorted), walk dates from the assignment date; skip non-working days (`WorkingCalendar`); free = working hours − booked; take = min(free, outstanding); add a segment to a list **and** update the booked map so the next case of the same engineer sees it.
5. Upsert Capacity records by `Capacity_Key__c` (engineer Id + date) in one DML, insert all Work Segments in one DML, update cases (Planned Start/Finish, Schedule Status, Needs Replanning = false) in one DML.
6. Not scheduled engineer (CAP-01): no segments, Schedule Status = Unscheduled, no error.
7. Horizon reached with effort left (A7): keep placed segments, Schedule Status = Unplaceable.

## "Today" in tests
The service reads today from one method, for example `CaseSchedulingService.today()`, backed by a `@TestVisible static Date todayOverride`. Tests set it to Monday 21 December 2026 so Appendix A dates work on any run date.

## Sharing decision
`CaseSchedulingService` uses **inherited sharing**: called from the trigger it runs in system context and must see **every** engineer's bookings to avoid double-booking, even bookings the current user cannot see. User-facing entry points (LWC controllers, agent action) are **with sharing** and query in user mode (`WITH USER_MODE`), so users never see data they are not allowed to.

## Open question for the reviewer
CAP-05 says segments dated today or earlier are history and are never touched. CAP-06 says stale segments (dated before today) of **open** cases are rolled forward each night. This design treats them as follows: the nightly job moves stale segments of open cases (CAP-06); every other operation keeps past segments as history (CAP-05). Confirm with the reviewer.
