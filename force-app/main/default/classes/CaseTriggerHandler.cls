
public with sharing class CaseTriggerHandler {
    @TestVisible private static Boolean running = false;

    public static void handleAfter(List<Case> cases, Map<Id, Case> oldMap) {
        if (running) { return; }
        Set<Id> toPlan = new Set<Id>();
        Set<Id> toClean = new Set<Id>();

        for (Case c : cases) {
            Case old = (oldMap == null) ? null : oldMap.get(c.Id);
            Boolean ownerIsUser = c.OwnerId.getSobjectType() == User.SObjectType;

            if (c.IsClosed) {
                if (old != null && !old.IsClosed) { toClean.add(c.Id); }
                continue;
            }
            if (!ownerIsUser || c.Estimated_Effort__c == null) { continue; }

            if (old == null) { toPlan.add(c.Id); continue; }           // created already assigned
            Boolean ownerChanged  = c.OwnerId != old.OwnerId;          // events 1 and 3
            Boolean effortChanged = c.Estimated_Effort__c != old.Estimated_Effort__c
                && (old.Schedule_Status__c != 'Unscheduled' || c.Needs_Replanning__c);   // event 2
            if (ownerChanged || effortChanged) { toPlan.add(c.Id); }
        }

        running = true;
        try {
            if (!toClean.isEmpty()) { CaseSchedulingService.removeFutureSegments(toClean); }
            if (!toPlan.isEmpty())  { CaseSchedulingService.planCases(toPlan); }
        } finally {
            running = false;
        }
    }
}