/**
 * AI-07: Agent action "Create Case from Conversation".
 * Creates a Technical case for the equipment identified by its serial number and
 * returns the case number to the agent.
 *
 * Security (SEC-05): the equipment and its account are read in user mode, and the case
 * is inserted in user mode, so the user's object, field and record access all apply.
 * Routing (INT-05): the active case assignment rules run on insert, so the new case lands
 * in the same queue as an email or web case for that account.
 * Bulk-safe: 3 SOQL queries and 1 DML statement per call.
 */
public with sharing class CreateCaseFromConversationAction {

    @TestVisible
    private static final String ORIGIN_AGENT = 'Agentforce';

    public class Request {
        @InvocableVariable(required=true label='Serial Number' description='Serial number of the equipment the problem is about, for example SN-4402')
        public String serialNumber;
        @InvocableVariable(required=true label='Subject' description='One-line summary of the problem in the user\'s words')
        public String subject;
        @InvocableVariable(label='Description' description='Details the user gave: symptoms, when it started, anything already tried')
        public String description;
    }

    public class Result {
        @InvocableVariable(label='Case Number' description='Number of the new case, empty if no case was created')
        public String caseNumber;
        @InvocableVariable(label='Case Id' description='Record Id of the new case, empty if no case was created')
        public Id caseId;
        @InvocableVariable(label='Message' description='Text to show the user: confirmation or the reason no case was created')
        public String message;
    }

    @InvocableMethod(
        label='Create Case from Conversation'
        description='Use when the user wants to report a problem or raise a new service case for a piece of equipment. Ask for the serial number and a short description first. Creates a Technical case, routes it to the right service queue and returns the case number.'
        category='Helios Service')
    public static List<Result> create(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Integer i = 0; i < requests.size(); i++) {
            results.add(new Result());
        }

        // 1) Find the equipment the user is allowed to see.
        Set<String> serials = new Set<String>();
        for (Request r : requests) {
            if (String.isNotBlank(r.serialNumber)) {
                serials.add(r.serialNumber.trim());
            }
        }
        Map<String, Equipment__c> bySerial = new Map<String, Equipment__c>();
        Set<Id> visibleAccounts = new Set<Id>();
        try {
            Set<Id> accountIds = new Set<Id>();
            for (Equipment__c e : [
                SELECT Id, Serial_Number__c, Account__c
                FROM Equipment__c
                WHERE Serial_Number__c IN :serials
                WITH USER_MODE
            ]) {
                bySerial.put(e.Serial_Number__c.toUpperCase(), e);
                if (e.Account__c != null) {
                    accountIds.add(e.Account__c);
                }
            }
            visibleAccounts = new Map<Id, Account>(
                [SELECT Id FROM Account WHERE Id IN :accountIds WITH USER_MODE]
            ).keySet();
        } catch (QueryException e) {
            bySerial.clear();
        }

        // 2) Build the cases (no hardcoded record type Id).
        Id technicalRt = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Technical').getRecordTypeId();
        List<Case> toInsert = new List<Case>();
        List<Integer> positions = new List<Integer>();
        for (Integer i = 0; i < requests.size(); i++) {
            Request r = requests[i];
            Equipment__c e = String.isBlank(r.serialNumber) ? null : bySerial.get(r.serialNumber.trim().toUpperCase());
            Boolean visible = e != null && (e.Account__c == null || visibleAccounts.contains(e.Account__c));
            if (!visible) {
                results[i].message = System.Label.HES_Msg_No_Coverage_Access;
                continue;
            }
            toInsert.add(new Case(
                RecordTypeId = technicalRt,
                AccountId = e.Account__c,
                Equipment__c = e.Id,
                Origin = ORIGIN_AGENT,
                Subject = r.subject,
                Description = r.description
            ));
            positions.add(i);
        }
        if (toInsert.isEmpty()) {
            return results;
        }

        // 3) Insert in user mode and run the active assignment rules (INT-05 routing).
        Database.DMLOptions options = new Database.DMLOptions();
        options.assignmentRuleHeader.useDefaultRule = true;
        options.optAllOrNone = false;
        List<Database.SaveResult> saved = Database.insert(toInsert, options, AccessLevel.USER_MODE);

        Set<Id> newIds = new Set<Id>();
        for (Integer k = 0; k < saved.size(); k++) {
            Result res = results[positions[k]];
            if (saved[k].isSuccess()) {
                res.caseId = saved[k].getId();
                newIds.add(res.caseId);
            } else {
                res.message = System.Label.HES_Err_Generic + ' ' + saved[k].getErrors()[0].getMessage();
            }
        }

        // 4) Read back the case numbers. After routing the case belongs to a queue the user
        //    may not be a member of, so only the number of the case they just created is
        //    read in system mode.
        Map<Id, String> numbers = readNumbers(newIds);
        for (Result res : results) {
            if (res.caseId != null) {
                res.caseNumber = numbers.get(res.caseId);
                res.message = String.format(System.Label.HES_Agent_Case_Created, new List<Object>{ res.caseNumber });
            }
        }
        return results;
    }

    /** Reads only CaseNumber, only for the Ids just inserted by this action. */
    private without sharing class CaseNumberReader {
        public Map<Id, String> readInternal(Set<Id> ids) {
            Map<Id, String> result = new Map<Id, String>();
            for (Case c : [SELECT Id, CaseNumber FROM Case WHERE Id IN :ids WITH SYSTEM_MODE]) {
                result.put(c.Id, c.CaseNumber);
            }
            return result;
        }
    }

    private static Map<Id, String> readNumbers(Set<Id> ids) {
        return new CaseNumberReader().readInternal(ids);
    }
}
