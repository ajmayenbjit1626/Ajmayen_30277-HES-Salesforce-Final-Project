/**
 * Data for the engineerCapacityCalendar LWC (LWC-01). Read only: every method is cacheable (no DML possible).
 * with sharing + WITH USER_MODE: a user only sees the users, segments and cases their access allows.
 * Engineers = active users with a Default Working Hours value (CAP-01), so no role or profile name is hardcoded;
 * not-scheduled engineers are included and shown with a badge. One call per week, a fixed number of queries.
 */
public with sharing class CapacityCalendarController {
    public class EngineerRow {
        @AuraEnabled public Id engineerId;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal hoursPerDay;
        @AuraEnabled public Boolean scheduled;
        @AuraEnabled public List<Decimal> planned = new List<Decimal>{ 0, 0, 0, 0, 0 };            // Mon..Fri
        @AuraEnabled public List<Boolean> working = new List<Boolean>{ true, true, true, true, true }; // false = holiday
    }

    @AuraEnabled(cacheable=true)
    public static List<EngineerRow> weekGrid(Date weekStart) {
        Date weekEnd = weekStart.addDays(4);
        List<Boolean> working = new List<Boolean>();
        for (Integer i = 0; i < 5; i++) { working.add(WorkingCalendar.isWorkingDay(weekStart.addDays(i))); }   // cached, 1 query
        Map<Id, EngineerRow> rows = new Map<Id, EngineerRow>();
            for (User u : [SELECT Id, Name, Default_Working_Hours__c, Is_Scheduled__c FROM User
                       WHERE IsActive = true AND UserType = 'Standard' AND Default_Working_Hours__c != null
                      WITH USER_MODE ORDER BY Name]) {
            EngineerRow r = new EngineerRow();
            r.engineerId = u.Id;
            r.name = u.Name;
            r.hoursPerDay = u.Default_Working_Hours__c;
            r.scheduled = u.Is_Scheduled__c;
            r.working = working;
            rows.put(u.Id, r);
        }
        for (AggregateResult ar : [SELECT Capacity__r.Engineer__c e, Planned_Date__c d, SUM(Planned_Hours__c) h
                                   FROM Work_Segment__c
                                   WHERE Planned_Date__c >= :weekStart AND Planned_Date__c <= :weekEnd
                                   WITH USER_MODE
                                   GROUP BY Capacity__r.Engineer__c, Planned_Date__c]) {
            EngineerRow r = rows.get((Id) ar.get('e'));
            if (r != null) {
                r.planned[weekStart.daysBetween((Date) ar.get('d'))] = (Decimal) ar.get('h');
            }
        }
        return rows.values();
    }

    @AuraEnabled(cacheable=true)
    public static List<Work_Segment__c> casesForDay(Id engineerId, Date day) {
        return [SELECT Id, Planned_Hours__c, Case__c, Case__r.CaseNumber, Case__r.Subject
                FROM Work_Segment__c
                WHERE Capacity__r.Engineer__c = :engineerId AND Planned_Date__c = :day
                WITH USER_MODE ORDER BY Case__r.CaseNumber];
    }
}