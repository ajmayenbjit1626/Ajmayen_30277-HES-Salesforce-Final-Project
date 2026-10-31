trigger CaseTrigger on Case (after insert, after update) {

    CaseTriggerHandler.handleAfter(Trigger.new, Trigger.oldMap);

}