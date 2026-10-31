
## Tool selection � custom components (LWC-01 to LWC-03, WBS 8-01)

| Need | Standard option considered | Why it is not enough | Decision |
|---|---|---|---|
| Capacity Calendar: dispatcher sees, for one week, every engineer with booked and free hours per day, and clicks through to the cases | Report (matrix by engineer x day), list view, dashboard chart | A report shows booked hours only; it cannot show free hours (working hours minus booked) for days with no bookings, cannot show part-time or not-scheduled engineers in the same grid, and cannot click a cell to open that day's cases | LWC `hesCapacityCalendar` on the Dispatcher home / app page |
| Schedule Timeline: on a case, see its segments against planned start, finish and status in one view | Related list "Work Segments" | A related list shows segments as rows only; it cannot show them on a date line next to planned start, finish, status and Needs Replanning, or mark weekends and holidays | LWC `hesScheduleTimeline` on the Case Technical Page |

Rules for both components:
- They only **display** data. All planning stays in `CaseSchedulingService` (Apex); the coverage value stays a formula (SVC-03). No component writes Work Segments or Capacity.
- Apex controllers are `with sharing` and query `WITH USER_MODE`, so users see only what their access allows.
- User-facing text comes from custom labels (HES_Lbl_*).
- Built with SLDS base components (lightning-card, lightning-badge, an SLDS table), so they look like standard Salesforce.
- Review check for 8-02 to 8-07: the LWC Apex controllers contain only SELECT queries (no insert, update, delete), and the JavaScript calls no Apex method that writes data.

## Dashboard running users (AN-05, WBS 9-05)

| Dashboard | View Dashboard As | Reason | Trade-off |
|---|---|---|---|
| Service Operations | Me (admin owner, sees all cases) | Dispatchers and service managers must see workload across every queue, engineer and region to balance work. A viewer-based dashboard would show an engineer only his own cases and hide queue backlog. | Every viewer with access to the HES Service Dashboards folder sees team-wide totals. Mitigation: folder shared only with the Service Manager role hierarchy and HES Leadership; clicking a widget opens the source report, which runs as the viewer and so still respects record sharing (an engineer drills into his own cases only). |
| Sales Performance | The dashboard viewer | Reps must see only their own pipeline (OWD Opportunity Private); managers see their team through the role hierarchy; Finance sees what the "Pipeline to finance" sharing rule gives them. | Each viewer sees a different picture, and the dashboard refreshes per viewer. Accepted, because pipeline data is commercially sensitive. |

Note: with only 4 licences there is no separate Service Manager user, so the admin is the running user. In production this would be a dedicated Service Manager user, not an administrator.