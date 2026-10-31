/**
 * Jest tests for engineerCapacityCalendar (LWC-01, NFR-05): rows, colours, badges, holiday, empty state, error, click-through.
 * Apex calls are mocked, so the tests run without an org.
 */
import { createElement } from "lwc";
import EngineerCapacityCalendar from "c/engineerCapacityCalendar";
import weekGrid from "@salesforce/apex/CapacityCalendarController.weekGrid";
import casesForDay from "@salesforce/apex/CapacityCalendarController.casesForDay";

jest.mock(
  "@salesforce/apex/CapacityCalendarController.weekGrid",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/CapacityCalendarController.casesForDay",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const ROWS = [
  {
    engineerId: "005000000000001AAA",
    name: "Eric Engineer",
    hoursPerDay: 8,
    scheduled: true,
    planned: [8, 3, 0, 0, 0],
    working: [true, true, true, false, true]
  },
  {
    engineerId: "005000000000002AAA",
    name: "Emma Engineer",
    hoursPerDay: 6,
    scheduled: true,
    planned: [0, 0, 0, 0, 0],
    working: [true, true, true, false, true]
  },
  {
    engineerId: "005000000000003AAA",
    name: "Long Leave",
    hoursPerDay: 8,
    scheduled: false,
    planned: [0, 0, 0, 0, 0],
    working: [true, true, true, false, true]
  }
];
// Lets pending promises and re-renders finish (no setTimeout: the LWC lint rule forbids it)
// Lets pending promises and re-renders finish (no timers or loops, so the LWC lint rules pass)
const flush = () =>
  Promise.resolve()
    .then(() => Promise.resolve())
    .then(() => Promise.resolve())
    .then(() => Promise.resolve());

describe("c-engineer-capacity-calendar", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  const mount = () => {
    const el = createElement("c-engineer-capacity-calendar", {
      is: EngineerCapacityCalendar
    });
    document.body.appendChild(el);
    return el;
  };

  it("renders one row per engineer with booked / capacity in each cell", async () => {
    const el = mount();
    weekGrid.emit(ROWS);
    await flush();
    const rows = el.shadowRoot.querySelectorAll("tbody tr");
    expect(rows.length).toBe(3);
    const ericCells = rows[0].querySelectorAll("button");
    expect(ericCells[0].textContent).toBe("8 / 8 h");
    expect(ericCells[0].className).toContain("cell_full");
    expect(ericCells[1].textContent).toBe("3 / 8 h");
    expect(ericCells[1].className).toContain("cell_part");
  });

  it("shows the holiday as a grey dash", async () => {
    const el = mount();
    weekGrid.emit(ROWS);
    await flush();
    const thursday = el.shadowRoot
      .querySelectorAll("tbody tr")[0]
      .querySelectorAll("button")[3];
    expect(thursday.textContent).toBe("-");
    expect(thursday.className).toContain("cell_off");
  });

  it("shows the part-time and not-scheduled badges from custom labels", async () => {
    const el = mount();
    weekGrid.emit(ROWS);
    await flush();
    const rows = el.shadowRoot.querySelectorAll("tbody tr");
    expect(rows[1].querySelector("th").textContent).toContain(
      "HES_Lbl_Part_Time"
    );
    expect(rows[2].querySelector("th").textContent).toContain(
      "HES_Lbl_Not_Scheduled"
    );
  });

  it("shows the empty state when there are no engineers", async () => {
    const el = mount();
    weekGrid.emit([]);
    await flush();
    expect(el.shadowRoot.querySelector("table")).toBeNull();
    expect(el.shadowRoot.querySelector(".empty")).not.toBeNull();
  });

  it("shows an error message when the Apex call fails", async () => {
    const el = mount();
    weekGrid.error({ message: "boom" });
    await flush();
    expect(
      el.shadowRoot.querySelector(".slds-text-color_error")
    ).not.toBeNull();
  });

  it("lists the cases of a day when a cell is clicked", async () => {
    casesForDay.mockResolvedValue([
      {
        Id: "a0X000000000001AAA",
        Planned_Hours__c: 3,
        Case__c: "500000000000001AAA",
        Case__r: { CaseNumber: "00001063", Subject: "Chiller not cooling" }
      }
    ]);
    const el = mount();
    weekGrid.emit(ROWS);
    await flush();
    el.shadowRoot
      .querySelectorAll("tbody tr")[0]
      .querySelectorAll("button")[1]
      .click();
    await flush();
    expect(casesForDay).toHaveBeenCalledTimes(1);
    const link = el.shadowRoot.querySelector("li a");
    expect(link.textContent).toContain("00001063");
    expect(link.getAttribute("href")).toBe("/500000000000001AAA");
  });
});
