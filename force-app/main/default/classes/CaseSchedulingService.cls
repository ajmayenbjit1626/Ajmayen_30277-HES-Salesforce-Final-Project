/**
 * Fill-and-spill capacity planning (CAP-01 to CAP-05, CAP-07).
 * inherited sharing: from the trigger it must see every engineer's bookings to avoid double-booking.
 * Bulk-safe: a fixed number of queries and DML statements, whatever the number of cases.
* Engineers are active standard users with Is Scheduled; internal users (e.g. the automated process user) are never planned.
 */
public inherited sharing class CaseSchedulingService {
    @TestVisible private static Date todayOverride;
    public static Date today() { return todayOverride != null ? todayOverride : Date.today(); }

    public static void planCases(Set<Id> caseIds) {
        Date t = today();
        Integer horizon = Integer.valueOf(HES_Setting__mdt.getInstance('Default').Horizon_Days__c);
        Date horizonEnd = t.addDays(horizon - 1);

        List<Case> cases = [SELECT Id, OwnerId, Estimated_Effort__c FROM Case WHERE Id IN :caseIds];
        Set<Id> engineerIds = new Set<Id>();
        for (Case c : cases) { engineerIds.add(c.OwnerId); }
               Map<Id, User> engineers = new Map<Id, User>(
           [SELECT Id, Default_Working_Hours__c, Is_Scheduled__c FROM User WHERE Id IN :engineerIds AND UserType = 'Standard']);

        // 1. Replanning starts clean: remove this case's future segments (today and earlier stay as history).
        delete [SELECT Id FROM Work_Segment__c WHERE Case__c IN :caseIds AND Planned_Date__c > :t];

        // 2. Hours already kept as history, per case.
        Map<Id, Decimal> keptHours = new Map<Id, Decimal>();
        Map<Id, Date> keptFirst = new Map<Id, Date>();
        Map<Id, Date> keptLast = new Map<Id, Date>();
        for (AggregateResult ar : [SELECT Case__c c, SUM(Planned_Hours__c) h, MIN(Planned_Date__c) f, MAX(Planned_Date__c) l
                                   FROM Work_Segment__c WHERE Case__c IN :caseIds GROUP BY Case__c]) {
            Id cid = (Id) ar.get('c');
            keptHours.put(cid, (Decimal) ar.get('h'));
            keptFirst.put(cid, (Date) ar.get('f'));
            keptLast.put(cid, (Date) ar.get('l'));
        }

        // 3. Hours each engineer already has booked per day (all their cases).
        Map<String, Decimal> booked = new Map<String, Decimal>();
        for (AggregateResult ar : [SELECT Capacity__r.Engineer__c e, Planned_Date__c d, SUM(Planned_Hours__c) h
                                   FROM Work_Segment__c
                                   WHERE Capacity__r.Engineer__c IN :engineerIds
                                   AND Planned_Date__c >= :t AND Planned_Date__c <= :horizonEnd
                                   GROUP BY Capacity__r.Engineer__c, Planned_Date__c]) {
            booked.put(key((Id) ar.get('e'), (Date) ar.get('d')), (Decimal) ar.get('h'));
        }

        // 4. Existing Capacity records to reuse as parents.
        Map<String, Capacity__c> capacityByKey = new Map<String, Capacity__c>();
        for (Capacity__c cap : [SELECT Id, Capacity_Key__c FROM Capacity__c
                                WHERE Engineer__c IN :engineerIds
                                AND Capacity_Date__c >= :t AND Capacity_Date__c <= :horizonEnd]) {
            capacityByKey.put(cap.Capacity_Key__c, cap);
        }

        // 5. Plan in memory.
        List<Capacity__c> newCapacity = new List<Capacity__c>();
        List<Work_Segment__c> newSegments = new List<Work_Segment__c>();
        List<String> segmentKeys = new List<String>();
        List<Case> caseUpdates = new List<Case>();

        for (Case c : cases) {
            User eng = engineers.get(c.OwnerId);
            Case upd = new Case(Id = c.Id, Needs_Replanning__c = false);
            if (eng == null || !eng.Is_Scheduled__c) {                   // CAP-01
                upd.Schedule_Status__c = 'Unscheduled';
                upd.Planned_Start__c = null;
                upd.Planned_Finish__c = null;
                caseUpdates.add(upd);
                continue;
            }
            Decimal perDay = eng.Default_Working_Hours__c == null ? 8 : eng.Default_Working_Hours__c;
            Decimal kept = keptHours.containsKey(c.Id) ? keptHours.get(c.Id) : 0;
            Decimal remaining = c.Estimated_Effort__c - kept;
            Date day = (keptLast.containsKey(c.Id) && keptLast.get(c.Id) >= t) ? t.addDays(1) : t;
            Date first = keptFirst.get(c.Id);
            Date last = keptLast.get(c.Id);

            while (remaining > 0 && day <= horizonEnd) {
                if (WorkingCalendar.isWorkingDay(day)) {
                    String k = key(c.OwnerId, day);
                    Decimal used = booked.containsKey(k) ? booked.get(k) : 0;
                    Decimal take = Math.min(perDay - used, remaining);
                    if (take > 0) {
                        if (!capacityByKey.containsKey(k)) {
                            Capacity__c cap = new Capacity__c(Engineer__c = c.OwnerId, Capacity_Date__c = day,
                                                              Available_Hours__c = perDay, Capacity_Key__c = k);
                            capacityByKey.put(k, cap);
                            newCapacity.add(cap);
                        }
                        newSegments.add(new Work_Segment__c(Case__c = c.Id, Planned_Date__c = day, Planned_Hours__c = take));
                        segmentKeys.add(k);
                        booked.put(k, used + take);
                        remaining -= take;
                        if (first == null) { first = day; }
                        last = day;
                    }
                }
                day = day.addDays(1);
            }
            upd.Planned_Start__c = first;
            upd.Planned_Finish__c = last;
            upd.Schedule_Status__c = remaining > 0 ? 'Unplaceable' : 'Scheduled';   // CAP-04
            caseUpdates.add(upd);
        }

        // 6. Write: one insert per object, one update.
        insert newCapacity;
        for (Integer i = 0; i < newSegments.size(); i++) {
            newSegments[i].Capacity__c = capacityByKey.get(segmentKeys[i]).Id;
        }
        insert newSegments;
        update caseUpdates;
    }

    /** CAP-05: on closure, remove only segments dated after today. */
    public static void removeFutureSegments(Set<Id> caseIds) {
        Date t = today();
        delete [SELECT Id FROM Work_Segment__c WHERE Case__c IN :caseIds AND Planned_Date__c > :t];
    }

    /** CAP-06: move stale past segments of open cases forward and flag the cases. */
    public static void rollForwardStale() {
        Date t = today();
        List<Work_Segment__c> stale = [SELECT Id, Case__c FROM Work_Segment__c
                                       WHERE Planned_Date__c < :t AND Case__r.IsClosed = false LIMIT 5000];
        if (stale.isEmpty()) { return; }
        Set<Id> caseIds = new Set<Id>();
        for (Work_Segment__c s : stale) { caseIds.add(s.Case__c); }
        delete stale;
        planCases(caseIds);
        List<Case> flags = new List<Case>();
        for (Id cid : caseIds) { flags.add(new Case(Id = cid, Needs_Replanning__c = true)); }
        update flags;
    }

    private static String key(Id engineerId, Date d) {
        return String.valueOf(engineerId) + '|' + String.valueOf(d);
    }
}