# Scheduling engine – expected results (Appendix A1–A7)

Calculated by hand before writing Apex (WBS 7-01 step 1). The Apex tests in 7-08 assert exactly these numbers; if code and paper disagree, the code is wrong.

## Rule applied (CAP-03)
For each candidate date, starting from the assignment date:
1. Skip weekends and holidays (from Business Hours **HES Working Week** and its holidays, not from code).
2. Free hours = engineer's Default Working Hours − hours already planned for that engineer on that date across all cases.
3. Take = min(free hours, hours still to plan). If take > 0, create a work segment for that date.
4. Hours still to plan −= take; next date. Stop at 0, or after 60 calendar days (HES Setting Horizon Days) → Unplaceable.

Calendar used: **Monday = 21 December 2026**. Weekends off. Thursday 24 December is the only holiday; Friday 25 December is a working day.

## A1 Straightforward – 8 h/day, nothing booked, 11 h case assigned Mon 21 Dec

| Date | Free | Take | Left after |
|---|---|---|---|
| Mon 21 Dec | 8 | **8** | 3 |
| Tue 22 Dec | 8 | **3** | 0 |

Planned Start 21 Dec · Planned Finish 22 Dec · Planned Hours 11 = Estimated Effort 11 · Schedule Status Scheduled.

## A2 Partially booked – 5 h already booked on Monday by another case, 11 h case

| Date | Free | Take | Left after |
|---|---|---|---|
| Mon 21 Dec | 8 − 5 = 3 | **3** | 8 |
| Tue 22 Dec | 8 | **8** | 0 |

The other case's 5 h segment on Monday is untouched.

## A3 Weekend and holiday – 20 h case assigned Wed 23 Dec

| Date | Free | Take | Left after |
|---|---|---|---|
| Wed 23 Dec | 8 | **8** | 12 |
| Thu 24 Dec | holiday – skipped | – | 12 |
| Fri 25 Dec | 8 | **8** | 4 |
| Sat 26 / Sun 27 Dec | weekend – skipped | – | 4 |
| Mon 28 Dec | 8 | **4** | 0 |

Planned Start 23 Dec · Planned Finish 28 Dec · 3 segments.

## A4 Part-time – Default Working Hours 6, 11 h case assigned Mon 21 Dec

| Date | Free | Take | Left after |
|---|---|---|---|
| Mon 21 Dec | 6 | **6** | 5 |
| Tue 22 Dec | 6 | **5** | 0 |

## A5 Reassignment – A1 case reassigned to engineer 2 on Monday evening; today = Mon 21 Dec

| Segment | Result |
|---|---|
| Mon 21 Dec, 8 h, engineer 1 | **Kept** (dated today = history) |
| Tue 22 Dec, 3 h, engineer 1 | **Deleted** (dated after today) |
| Outstanding = 11 − 8 kept = **3 h** | Planned for engineer 2 from Mon 21 Dec against his free capacity (Mon 21 Dec 3 h if he has nothing booked) |

Planned Start stays 21 Dec; Planned Finish = date of the last new segment. Engineer 1's other cases are not touched.

## A6 Bulk – 200 cases × 11 h, from a queue to 20 engineers in one data load

- 10 cases per engineer, planned one after another against the same running capacity → 110 h per engineer (13 full days + 6 h, about 14 working days).
- Total 2,200 h planned; every case Scheduled; Planned Hours = 11 on every case.
- One transaction, within governor limits; no query or DML inside any loop (checked by reading the code, CAP-07).

## A7 Unplaceable – 600 h case, 8 h/day, assigned Mon 21 Dec

| Item | Value |
|---|---|
| Horizon (60 calendar days) | 21 Dec 2026 – 18 Feb 2027 |
| Working days in horizon (weekdays minus 24 Dec) | **43** |
| Hours placed (kept) | 43 × 8 = **344 h** |
| Hours not placed | **256 h** |
| Last segment | Thu 18 Feb 2027 |
| Schedule Status | **Unplaceable**; the Planned Hours = Estimated Effort check does not apply |

If the org's holidays also include 1 January 2027, the result is 42 days / 336 h. Tests must use the same holiday list as this calculation.
