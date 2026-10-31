/**
 * Jest tests for caseScheduleTimeline (LWC-02, NFR-05): segment rows, badges, empty state, error.
 * The case record (getRecord) and the Apex call are mocked, so the tests run without an org.
 */
import { createElement } from "lwc";
import CaseScheduleTimeline from "c/caseScheduleTimeline";
import { getRecord } from "lightning/uiRecordApi";
import segmentsForCase from "@salesforce/apex/CaseScheduleController.segmentsForCase";

jest.mock(
  "@salesforce/apex/CaseScheduleController.segmentsForCase",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

const CASE_RECORD = {
  apiName: "Case",
  id: "500000000000001AAA",
  fields: {
    Planned_Start__c: { value: "2026-12-21" },
    Planned_Finish__c: { value: "2026-12-22" },
    Schedule_Status__c: { value: "Scheduled" },
    Needs_Replanning__c: { value: true },
    OwnerId: { value: "005000000000001AAA" },
    Estimated_Effort__c: { value: 11 }
  }
};
const SEGMENTS = [
  {
    Id: "a0Y000000000001AAA",
    Planned_Date__c: "2026-12-21",
    Planned_Hours__c: 8,
    Capacity__r: { Engineer__r: { Name: "Eric Engineer" } }
  },
  {
    Id: "a0Y000000000002AAA",
    Planned_Date__c: "2026-12-22",
    Planned_Hours__c: 3,
    Capacity__r: { Engineer__r: { Name: "Eric Engineer" } }
  }
];
// Lets pending promises and re-renders finish (no setTimeout: the LWC lint rule forbids it)
// Lets pending promises and re-renders finish (no timers or loops, so the LWC lint rules pass)
const flush = () =>
  Promise.resolve()
    .then(() => Promise.resolve())
    .then(() => Promise.resolve())
    .then(() => Promise.resolve());

describe("c-case-schedule-timeline", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  const mount = () => {
    const el = createElement("c-case-schedule-timeline", {
      is: CaseScheduleTimeline
    });
    el.recordId = "500000000000001AAA";
    document.body.appendChild(el);
    return el;
  };

  it("renders one row per segment with hours and engineer", async () => {
    const el = mount();
    getRecord.emit(CASE_RECORD);
    segmentsForCase.emit(SEGMENTS);
    await flush();
    const rows = el.shadowRoot.querySelectorAll("li.row");
    expect(rows.length).toBe(2);
    expect(rows[0].textContent).toContain("2026-12-21");
    expect(rows[0].textContent).toContain("8 h");
    expect(rows[0].textContent).toContain("Eric Engineer");
    expect(rows[1].textContent).toContain("3 h");
  });

  it("shows the status and needs-replanning badges", async () => {
    const el = mount();
    getRecord.emit(CASE_RECORD);
    segmentsForCase.emit(SEGMENTS);
    await flush();
    const labels = Array.from(
      el.shadowRoot.querySelectorAll("lightning-badge")
    ).map((b) => b.label);
    expect(labels).toContain("Scheduled");
    // Jest returns a label as its name (c.HES_Lbl_...); the org returns its value
    expect(labels.some((l) => l.includes("HES_Lbl_Needs_Replanning"))).toBe(
      true
    );
  });

  it("shows the empty state when no work is planned", async () => {
    const el = mount();
    getRecord.emit(CASE_RECORD);
    segmentsForCase.emit([]);
    await flush();
    expect(el.shadowRoot.querySelectorAll("li.row").length).toBe(0);
    expect(el.shadowRoot.querySelector(".empty").textContent).toContain(
      "HES_Lbl_No_Work_Planned"
    );
  });

  it("shows an error message when the Apex call fails", async () => {
    const el = mount();
    segmentsForCase.error({ message: "boom" });
    await flush();
    expect(
      el.shadowRoot.querySelector(".slds-text-color_error")
    ).not.toBeNull();
  });
});
