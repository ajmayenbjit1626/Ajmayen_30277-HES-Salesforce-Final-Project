/**
 * AI-06 / SEC-05: Agent action "Check Equipment Coverage".
 * Returns the coverage position (Covered, Expired, Not Covered) and the plan end date
 * for one or more serial numbers. Runs in user mode, so the agent can only answer for
 * equipment and accounts the running user is allowed to see.
 * Bulk-safe: 2 SOQL queries per call, whatever the number of requests.
 */
public with sharing class CoverageLookupAction {

    public class Request {
        @InvocableVariable(required=true label='Serial Number' description='Equipment serial number, for example SN-4412')
        public String serialNumber;
    }

    public class Result {
        @InvocableVariable(label='Serial Number' description='The serial number that was checked')
        public String serialNumber;
        @InvocableVariable(label='Coverage Position' description='Covered, Expired or Not Covered')
        public String coveragePosition;
        @InvocableVariable(label='End Date' description='End date of the current coverage plan, if any')
        public Date endDate;
        @InvocableVariable(label='Coverage Plan' description='Name of the current coverage plan, if any')
        public String planName;
        @InvocableVariable(label='Message' description='Explanation when no answer can be given')
        public String message;
    }

    @InvocableMethod(
        label='Check Equipment Coverage'
        description='Use when someone asks whether a piece of equipment, identified by its serial number, is covered by a service plan. Returns Covered, Expired or Not Covered, the plan name and the plan end date.'
        category='Helios Service')
    public static List<Result> check(List<Request> requests) {
        Set<String> serials = new Set<String>();
        for (Request r : requests) {
            if (String.isNotBlank(r.serialNumber)) {
                serials.add(r.serialNumber.trim());
            }
        }

        Map<String, Equipment__c> bySerial = new Map<String, Equipment__c>();
        Set<Id> accountIds = new Set<Id>();
        Set<Id> visibleAccounts = new Set<Id>();
        try {
            for (Equipment__c e : [
                SELECT Serial_Number__c, Account__c, Coverage_Position__c,
                       Current_Coverage_Plan__r.Name, Current_Coverage_Plan__r.End_Date__c
                FROM Equipment__c
                WHERE Serial_Number__c IN :serials
                WITH USER_MODE
            ]) {
                bySerial.put(e.Serial_Number__c.toUpperCase(), e);
                if (e.Account__c != null) {
                    accountIds.add(e.Account__c);
                }
            }
            // Only answer for accounts this user can see (SEC-05).
            visibleAccounts = new Map<Id, Account>(
                [SELECT Id FROM Account WHERE Id IN :accountIds WITH USER_MODE]
            ).keySet();
        } catch (QueryException e) {
            // The user has no access to Equipment or Account at all: every request gets the message below.
            bySerial.clear();
        }

        List<Result> results = new List<Result>();
        for (Request r : requests) {
            Result res = new Result();
            res.serialNumber = r.serialNumber;
            Equipment__c e = String.isBlank(r.serialNumber) ? null : bySerial.get(r.serialNumber.trim().toUpperCase());
            Boolean accountVisible = e != null && (e.Account__c == null || visibleAccounts.contains(e.Account__c));
            if (!accountVisible) {
                res.message = System.Label.HES_Msg_No_Coverage_Access;
            } else {
                res.coveragePosition = e.Coverage_Position__c;
                if (e.Current_Coverage_Plan__r != null) {
                    res.planName = e.Current_Coverage_Plan__r.Name;
                    res.endDate = e.Current_Coverage_Plan__r.End_Date__c;
                }
            }
            results.add(res);
        }
        return results;
    }
}
