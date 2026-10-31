// AI-07 real test: create a case from a serial number (WBS 10-07)
CreateCaseFromConversationAction.Request r = new CreateCaseFromConversationAction.Request();
r.serialNumber = 'SN-4402';
r.subject = 'AC compressor making a clicking noise';
r.description = 'Reported through the agent test script.';
CreateCaseFromConversationAction.Result res =
    CreateCaseFromConversationAction.create(new List<CreateCaseFromConversationAction.Request>{ r })[0];
System.debug('CASE >>> ' + res.caseNumber + ' | ' + res.message);