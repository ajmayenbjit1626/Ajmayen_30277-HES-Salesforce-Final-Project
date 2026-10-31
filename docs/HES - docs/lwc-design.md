# Custom components – design and sketches (LWC-01 to LWC-03, WBS 8-01)

Both components only **display** data. All planning stays in `CaseSchedulingService` (Apex) and the coverage value stays a formula (SVC-03). No component writes Work Segments or Capacity. Apex controllers are `with sharing`, `@AuraEnabled(cacheable=true)` and query `WITH USER_MODE`. User-facing text comes from custom labels (HES_Lbl_*).

## 1. engineerCapacityCalendar (Dispatcher app page / home – LWC-01)

```
+--------------------------------------------------------------------------------------------+
| Engineer capacity - week of 21 Dec 2026                                     [ < ]  [ > ]   |
+--------------------------------------------------------------------------------------------+
| Engineer          Mon 21   Tue 22   Wed 23   Thu 24    Fri 25   Sat 26   Sun 27            |
| Eric Engineer     8 / 8    3 / 8    0 / 8    Holiday   0 / 8    -        -                 |
| Emma Engineer     6 / 6    5 / 6    0 / 6    Holiday   0 / 6    -        -   [Part-time]   |
| Admin             0 / 8    0 / 8    0 / 8    Holiday   0 / 8    -        -                 |
| Long-leave Eng.   -        -        -        -         -        -        -   [Not scheduled]|
|                                                                                            |
| cell = booked hours / capacity    green = free   amber = partly booked   red = full        |
+--------------------------------------------------------------------------------------------+
| Selected: Eric Engineer - Tue 22 Dec                                                       |
|   00001063   Chiller not cooling          3.00 h   (link to the case)                      |
+--------------------------------------------------------------------------------------------+
Empty state: "No engineers to show for this week."   (label HES_Lbl_No_Engineers)
```

- SLDS building blocks: `lightning-card`, `lightning-button-icon` (previous / next week), SLDS table, `lightning-badge` (Part-time, Not scheduled).
- Data: `CapacityCalendarController.weekGrid(weekStart)` – one cacheable, read-only query per week.
- Answers: "Who has free time this week?" Click a cell to see that day's cases.

## 2. caseScheduleTimeline (Case Technical Page – LWC-02)

```
+-------------------------------------------------------------------------------+
| Schedule                                                                      |
+-------------------------------------------------------------------------------+
| [Scheduled]   Start 21 Dec 2026  ->  Finish 22 Dec 2026    11.00 of 11.00 h   |
| [Needs replanning]   (badge shown only when the flag is ticked)               |
+-------------------------------------------------------------------------------+
| Mon 21 Dec   Eric Engineer   ########          8.00 h                         |
| Tue 22 Dec   Eric Engineer   ###               3.00 h                         |
|                                                                               |
| bar length = hours of the day; past days shown greyed as history              |
+-------------------------------------------------------------------------------+
Empty state: "Not scheduled yet."  (case has no segments)
```

- SLDS building blocks: `lightning-card`, `lightning-badge` (status, Needs replanning), SLDS list with a simple bar.
- Data: `CaseScheduleController` – cacheable, read-only; refreshes when the case record changes (for example after a reassignment).
- Answers: "When is this case being worked, and by whom?"

## Decisions

| Decision | Capacity calendar | Schedule timeline |
|---|---|---|
| Users | Dispatcher, Service Manager | Engineer, dispatcher on a case |
| Location | App page / Home of the service app | Case Technical Page |
| Click action | Cell opens the list of that day's cases | – |
| Special states | Holiday, weekend, Part-time, Not scheduled, empty week | Needs replanning, Unplaceable, not scheduled yet |

## Why standard tools are not enough (tool-selection matrix)

| Need | Standard option considered | Why it is not enough |
|---|---|---|
| Week grid of engineers with booked and free hours and click-through | Matrix report, list view, dashboard chart | A report shows booked hours only; it cannot show free hours on days without bookings, part-time and not-scheduled engineers in one grid, or open a cell's cases |
| Segments of one case against its planned start, finish and status | Related list "Work Segments" | Rows only; no date line next to plan dates, status and Needs Replanning, no greyed history |

Review check for 8-02 to 8-07: the controllers contain only SELECT queries (no insert, update, delete) and every method is `cacheable=true`.
