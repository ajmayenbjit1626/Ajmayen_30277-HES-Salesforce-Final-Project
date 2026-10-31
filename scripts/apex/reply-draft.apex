// AI-02: run the reply draft from Apex (WBS 10-02)
String draft = ReplyDraftService.generateDraft('500fj00002gfzBBAAY');
System.debug('DRAFT >>> ' + draft);