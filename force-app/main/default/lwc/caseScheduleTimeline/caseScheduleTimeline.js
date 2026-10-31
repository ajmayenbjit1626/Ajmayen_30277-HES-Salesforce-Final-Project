import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import segmentsForCase from '@salesforce/apex/CaseScheduleController.segmentsForCase';
import START from '@salesforce/schema/Case.Planned_Start__c';
import FINISH from '@salesforce/schema/Case.Planned_Finish__c';
import STATUS from '@salesforce/schema/Case.Schedule_Status__c';
import REPLAN from '@salesforce/schema/Case.Needs_Replanning__c';
import OWNER from '@salesforce/schema/Case.OwnerId';
import EFFORT from '@salesforce/schema/Case.Estimated_Effort__c';
import NEEDS_REPLANNING from '@salesforce/label/c.HES_Lbl_Needs_Replanning';
import NO_WORK_PLANNED from '@salesforce/label/c.HES_Lbl_No_Work_Planned';

export default class CaseScheduleTimeline extends LightningElement {
    @api recordId;
    labels = { needsReplanning: NEEDS_REPLANNING, noWorkPlanned: NO_WORK_PLANNED };
    caseRecord;
    segmentsResult;
    segments = [];
    error;

    @wire(getRecord, { recordId: '$recordId', fields: [START, FINISH, STATUS, REPLAN, OWNER, EFFORT] })
    wiredCase({ data, error }) {
        if (data) {
            this.caseRecord = data;
            if (this.segmentsResult) { refreshApex(this.segmentsResult); }   // owner or effort changed: reload
        } else if (error) { this.error = error; }
    }

    @wire(segmentsForCase, { caseId: '$recordId' })
    wiredSegments(result) {
        this.segmentsResult = result;
        if (result.data) {
            const today = new Date().toISOString().slice(0, 10);
            this.segments = result.data.map((s) => ({
                id: s.Id,
                date: s.Planned_Date__c,
                hours: s.Planned_Hours__c,
                engineer: s.Capacity__r && s.Capacity__r.Engineer__r ? s.Capacity__r.Engineer__r.Name : '',
                barStyle: 'width: ' + Math.min(100, (s.Planned_Hours__c / 8) * 100) + '%',
                cls: s.Planned_Date__c <= today ? 'bar bar_past' : 'bar'
            }));
        } else if (result.error) { this.error = result.error; }
    }

    get status() { return getFieldValue(this.caseRecord, STATUS); }
    get start() { return getFieldValue(this.caseRecord, START); }
    get finish() { return getFieldValue(this.caseRecord, FINISH); }
    get needsReplanning() { return getFieldValue(this.caseRecord, REPLAN); }
    get hasSegments() { return this.segments.length > 0; }
    get errorMessage() { return this.error ? (this.error.body && this.error.body.message) || 'Error' : ''; }
}