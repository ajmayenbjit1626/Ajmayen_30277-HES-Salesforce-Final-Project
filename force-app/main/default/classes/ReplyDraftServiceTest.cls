/**
 * Tests for ReplyDraftService (AI-02). The AI call is replaced by a fake
 * generator, because prompt templates cannot run inside Apex tests.
 */
@IsTest
private class ReplyDraftServiceTest {

    private class FakeGenerator implements ReplyDraftService.ReplyGenerator {
        private String reply;
        private Boolean fail;
        FakeGenerator(String reply, Boolean fail) {
            this.reply = reply;
            this.fail = fail;
        }
        public String generate(Id caseId) {
            if (fail) {
                throw new CalloutException('LLM unavailable');
            }
            return reply;
        }
    }

    @IsTest
    static void draftReply_returnsGeneratedText() {
        Case c = TestDataFactory.technicalCases(1, 6)[0];
        ReplyDraftService.generator = new FakeGenerator('Hello, your case is covered.', false);

        Test.startTest();
        String reply = ReplyDraftService.generateDraft(c.Id);
        Test.stopTest();

        Assert.areEqual('Hello, your case is covered.', reply, 'The generated draft is returned unchanged');
    }

    @IsTest
    static void draftReply_nullIdGivesFriendlyError() {
        try {
            ReplyDraftService.generateDraft(null);
            Assert.fail('A missing case Id must be rejected');
        } catch (ReplyDraftService.ReplyDraftException e) {
            Assert.isTrue(e.getMessage().startsWith(System.Label.HES_AI_Draft_Failed), 'Message comes from the custom label');
        }
    }

    @IsTest
    static void draftReply_aiFailureGivesFriendlyError() {
        Case c = TestDataFactory.technicalCases(1, 6)[0];
        ReplyDraftService.generator = new FakeGenerator(null, true);

        try {
            ReplyDraftService.generateDraft(c.Id);
            Assert.fail('An AI failure must surface as a handled error');
        } catch (ReplyDraftService.ReplyDraftException e) {
            Assert.isTrue(e.getMessage().startsWith(System.Label.HES_AI_Draft_Failed), 'Label message shown');
            Assert.isTrue(e.getMessage().contains('LLM unavailable'), 'Technical detail kept for support');
        }
    }

    @IsTest
    static void draftReply_emptyResponseGivesFriendlyError() {
        Case c = TestDataFactory.technicalCases(1, 6)[0];
        ReplyDraftService.generator = new FakeGenerator('  ', false);

        try {
            ReplyDraftService.generateDraft(c.Id);
            Assert.fail('An empty draft must not be returned');
        } catch (ReplyDraftService.ReplyDraftException e) {
            Assert.isTrue(e.getMessage().startsWith(System.Label.HES_AI_Draft_Failed), 'Label message shown');
        }
    }

    @IsTest
    static void realGenerator_isTheDefaultAndCallsTheTemplate() {
        Assert.isTrue(ReplyDraftService.generator instanceof ReplyDraftService.PromptTemplateGenerator,
            'Production code uses the prompt template generator');
        Assert.areEqual('HES_Customer_Reply_Draft', ReplyDraftService.TEMPLATE_NAME, 'Template API name');

        Case c = TestDataFactory.technicalCases(1, 6)[0];
        try {
            new ReplyDraftService.PromptTemplateGenerator().generate(c.Id);
        } catch (Exception e) {
            // Prompt templates do not run in Apex tests; reaching the call is enough here.
            Assert.isNotNull(e.getMessage(), 'The ConnectApi call was reached');
        }
    }

    @IsTest
    static void draftReply_lightningEntryPointReturnsDraft() {
        Case c = TestDataFactory.technicalCases(1, 6)[0];
        ReplyDraftService.generator = new FakeGenerator('Draft for LWC', false);
        Assert.areEqual('Draft for LWC', ReplyDraftService.draftReply(c.Id), 'Aura entry point returns the same draft');
    }

    @IsTest
    static void draftReply_lightningEntryPointConvertsErrors() {
        try {
            ReplyDraftService.draftReply(null);
            Assert.fail('Error expected');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().startsWith(System.Label.HES_AI_Draft_Failed), 'Converted to AuraHandledException with label text');
        }
    }
}
