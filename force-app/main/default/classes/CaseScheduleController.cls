/**
 * Data for the caseScheduleTimeline LWC on the Case Technical Page (LWC-02).
 * Read only: cacheable (no DML possible). with sharing + WITH USER_MODE: returns only segments,
 * fields and engineer names the current user is allowed to see.
 */
public with sharing class CaseScheduleController {
    @AuraEnabled(cacheable=true)
    public static List<Work_Segment__c> segmentsForCase(Id caseId) {
        return [SELECT Id, Planned_Date__c, Planned_Hours__c, Capacity__r.Engineer__r.Name
                FROM Work_Segment__c WHERE Case__c = :caseId
                WITH USER_MODE ORDER BY Planned_Date__c];
    }
}