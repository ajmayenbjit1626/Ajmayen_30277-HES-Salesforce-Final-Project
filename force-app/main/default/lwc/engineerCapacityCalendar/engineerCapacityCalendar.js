import { LightningElement, api, wire } from 'lwc';
import weekGrid from '@salesforce/apex/CapacityCalendarController.weekGrid';
import casesForDay from '@salesforce/apex/CapacityCalendarController.casesForDay';
import PART_TIME from '@salesforce/label/c.HES_Lbl_Part_Time';
import NOT_SCHEDULED from '@salesforce/label/c.HES_Lbl_Not_Scheduled';
import NO_ENGINEERS from '@salesforce/label/c.HES_Lbl_No_Engineers';

const DAY_NAMES = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
const iso = (d) => d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
const mondayOf = (d) => { const x = new Date(d.getFullYear(), d.getMonth(), d.getDate()); x.setDate(x.getDate() - ((x.getDay() + 6) % 7)); return x; };

export default class EngineerCapacityCalendar extends LightningElement {
    @api cardTitle = 'Engineer capacity';
    labels = { noEngineers: NO_ENGINEERS };
    weekStart = iso(mondayOf(new Date()));
    rows = [];
    error;
    selected;

    @wire(weekGrid, { weekStart: '$weekStart' })
    wiredGrid({ data, error }) {
        if (data) { this.rows = data.map((r) => this.toRow(r)); this.error = undefined; }
        else if (error) { this.error = error; this.rows = []; }
    }

    get days() {
        const start = new Date(this.weekStart + 'T00:00:00');
        return DAY_NAMES.map((name, i) => {
            const d = new Date(start);
            d.setDate(start.getDate() + i);
            return { key: iso(d), label: name + ' ' + d.getDate() };
        });
    }
    get hasRows() { return this.rows.length > 0; }
    get errorMessage() { return this.error ? (this.error.body && this.error.body.message) || 'Error' : ''; }

    toRow(r) {
        const days = this.days;
        const cells = r.planned.map((h, i) => {
            let cls = 'cell';
            const working = r.working[i];
            if (!r.scheduled || !working) cls += ' cell_off';
            else if (h >= r.hoursPerDay) cls += ' cell_full';
            else if (h > 0) cls += ' cell_part';
            return { key: r.engineerId + '-' + i, day: days[i].key, cls,
                     label: r.scheduled && working ? h + ' / ' + r.hoursPerDay + ' h' : '-' };
        });
        const note = !r.scheduled ? NOT_SCHEDULED : (r.hoursPerDay < 8 ? PART_TIME : '');
        return { engineerId: r.engineerId, name: r.name, note, cells };
    }

    handleCellClick(event) {
        const { engineer, day, name } = event.currentTarget.dataset;
        casesForDay({ engineerId: engineer, day })
            .then((segs) => {
                this.selected = {
                    title: name + ', ' + day,
                    items: segs.map((s) => ({ id: s.Id, url: '/' + s.Case__c, hours: s.Planned_Hours__c,
                                              text: s.Case__r.CaseNumber + ' ' + s.Case__r.Subject }))
                };
            })
            .catch((e) => { this.error = e; });
    }

    shiftWeek(days) {
        const d = new Date(this.weekStart + 'T00:00:00');
        d.setDate(d.getDate() + days);
        this.weekStart = iso(d);
        this.selected = undefined;
    }
    prevWeek() { this.shiftWeek(-7); }
    nextWeek() { this.shiftWeek(7); }
}