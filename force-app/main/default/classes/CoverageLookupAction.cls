/**
 * Agent action "Check Equipment Coverage" (AI-06, extended by AI-06-R1 page context).
 *
 * Finds the equipment in this order:
 *   1. the serial number the user typed (always wins), otherwise
 *   2. the record the user has open: an Equipment record, or a Case linked to equipment.
 * Returns Covered / Expired / Not Covered, the current plan name and its end date.
 *
 * Security: with sharing and USER_MODE queries, so the user only gets an answer for
 * equipment, cases and accounts they can already see.
 * Governor limits: at most 3 SOQL per call, whatever the number of requests; no SOQL or DML in loops.
 */
public with sharing class CoverageLookupAction {
  public class Request {
    @InvocableVariable(
      label='Serial Number'
      description='Equipment serial number, for example SN-4402. Leave empty to use the record the user has open.'
    )
    public String serialNumber;
    @InvocableVariable(
      label='Current Record Id'
      description='Id of the record open on the user\'s screen (Case or Equipment). Filled by the agent from the page context.'
    )
    public String recordId;
  }

  public class Result {
    @InvocableVariable(
      label='Coverage Position'
      description='Covered, Expired or Not Covered'
    )
    public String coveragePosition;
    @InvocableVariable(
      label='Coverage Plan'
      description='Name of the current coverage plan, if any'
    )
    public String planName;
    @InvocableVariable(
      label='End Date'
      description='End date of the current coverage plan, if any'
    )
    public Date endDate;
    @InvocableVariable(
      label='Serial Number'
      description='The serial number that was checked'
    )
    public String serialNumber;
    @InvocableVariable(
      label='Message'
      description='Explanation when no answer can be given'
    )
    public String message;
  }

  @InvocableMethod(
    label='Check Equipment Coverage'
    description='Use when someone asks whether a piece of equipment is covered by a service plan. Uses the serial number if given, otherwise the case or equipment record the user has open. Returns Covered, Expired or Not Covered, the plan name and the plan end date.'
  )
  public static List<Result> check(List<Request> requests) {
    // 1. Split the inputs: typed serials, open Equipment records, open Case records.
    Set<String> serials = new Set<String>();
    Set<Id> equipmentIds = new Set<Id>();
    Set<Id> caseIds = new Set<Id>();
    for (Request r : requests) {
      if (String.isNotBlank(r.serialNumber)) {
        serials.add(r.serialNumber.trim());
        continue;
      }
      Id ctx = toId(r.recordId);
      if (ctx == null) {
        continue;
      }
      if (ctx.getSobjectType() == Equipment__c.SObjectType) {
        equipmentIds.add(ctx);
      } else if (ctx.getSobjectType() == Case.SObjectType) {
        caseIds.add(ctx);
      }
    }

    Map<Id, Id> equipmentByCase = new Map<Id, Id>();
    Map<String, Equipment__c> bySerial = new Map<String, Equipment__c>();
    Map<Id, Equipment__c> byId = new Map<Id, Equipment__c>();
    Set<Id> accountIds = new Set<Id>();
    Set<Id> visibleAccounts = new Set<Id>();
    try {
      // 2. Case on screen -> its equipment (query 1, only when needed).
      if (!caseIds.isEmpty()) {
        for (Case c : [
          SELECT Id, Equipment__c
          FROM Case
          WHERE Id IN :caseIds
          WITH USER_MODE
        ]) {
          if (c.Equipment__c != null) {
            equipmentByCase.put(c.Id, c.Equipment__c);
            equipmentIds.add(c.Equipment__c);
          }
        }
      }

      // 3. Load all equipment once, by serial or by Id (query 2).
      if (!serials.isEmpty() || !equipmentIds.isEmpty()) {
        for (Equipment__c e : [
          SELECT
            Id,
            Serial_Number__c,
            Account__c,
            Coverage_Position__c,
            Current_Coverage_Plan__r.Name,
            Current_Coverage_Plan__r.End_Date__c
          FROM Equipment__c
          WHERE Serial_Number__c IN :serials OR Id IN :equipmentIds
          WITH USER_MODE
        ]) {
          byId.put(e.Id, e);
          if (e.Serial_Number__c != null) {
            bySerial.put(e.Serial_Number__c.toUpperCase(), e);
          }
          accountIds.add(e.Account__c);
        }
      }

      // 4. Only answer for accounts this user can see (query 3).
      if (!accountIds.isEmpty()) {
        visibleAccounts = new Map<Id, Account>(
            [SELECT Id FROM Account WHERE Id IN :accountIds WITH USER_MODE]
          )
          .keySet();
      }
    } catch (QueryException ex) {
      // USER_MODE throws when the user has no access to Case, Equipment or Account:
      // answer every request with the no-access message, never with data.
      List<Result> denied = new List<Result>();
      for (Request r : requests) {
        Result res = new Result();
        res.message = System.Label.HES_Msg_No_Coverage_Access;
        denied.add(res);
      }
      return denied;
    }

    // 5. Build one result per request.
    List<Result> results = new List<Result>();
    for (Request r : requests) {
      Result res = new Result();
      Equipment__c e = null;
      Id ctx = toId(r.recordId);

      if (String.isNotBlank(r.serialNumber)) {
        e = bySerial.get(r.serialNumber.trim().toUpperCase());
      } else if (
        ctx != null &&
        ctx.getSobjectType() == Equipment__c.SObjectType
      ) {
        e = byId.get(ctx);
      } else if (ctx != null && ctx.getSobjectType() == Case.SObjectType) {
        Id eqId = equipmentByCase.get(ctx);
        e = eqId == null ? null : byId.get(eqId);
        if (e == null) {
          res.message = System.Label.HES_Agent_Case_No_Equipment;
        }
      } else {
        res.message = System.Label.HES_Agent_Need_Serial;
      }

      if (res.message == null) {
        if (e == null || !visibleAccounts.contains(e.Account__c)) {
          res.message = System.Label.HES_Msg_No_Coverage_Access;
        } else {
          res.serialNumber = e.Serial_Number__c;
          res.coveragePosition = e.Coverage_Position__c;
          res.planName = e.Current_Coverage_Plan__r == null
            ? null
            : e.Current_Coverage_Plan__r.Name;
          res.endDate = e.Current_Coverage_Plan__r == null
            ? null
            : e.Current_Coverage_Plan__r.End_Date__c;
        }
      }
      results.add(res);
    }
    return results;
  }

  /** Turns the page-context text into an Id; returns null for blank or invalid values. */
  private static Id toId(String value) {
    if (String.isBlank(value)) {
      return null;
    }
    try {
      return Id.valueOf(value.trim());
    } catch (Exception ex) {
      return null;
    }
  }
}
