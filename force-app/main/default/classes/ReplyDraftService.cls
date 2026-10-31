/**
 * AI-02: Drafts a customer reply for a service case by calling the
 * HES Customer Reply Draft prompt template from Apex.
 * The same template is used by the Draft Customer Reply flow.
 * Draft only: nothing is sent to the customer.
 *
 * The AI call sits behind the ReplyGenerator interface so that tests can
 * replace it (prompt templates cannot run inside Apex tests).
 */
public with sharing class ReplyDraftService {

    /** Produces the reply text for one case. */
    public interface ReplyGenerator {
        String generate(Id caseId);
    }

    /** Real implementation: calls the prompt template through ConnectApi. */
    public with sharing class PromptTemplateGenerator implements ReplyGenerator {
        public String generate(Id caseId) {
            ConnectApi.WrappedValue caseValue = new ConnectApi.WrappedValue();
            caseValue.value = new Map<String, String>{ 'id' => caseId };

            ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            input.isPreview = false;
            input.inputParams = new Map<String, ConnectApi.WrappedValue>{ 'Input:Case' => caseValue };
            // Identifies the calling application; required when the template is run from Apex.
            input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            input.additionalConfig.applicationName = 'PromptBuilderPreview';

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation output =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(TEMPLATE_NAME, input);
            if (output == null || output.generations == null || output.generations.isEmpty()) {
                return null;
            }
            return output.generations[0].text;
        }
    }

    @TestVisible
    private static final String TEMPLATE_NAME = 'HES_Customer_Reply_Draft';

    @TestVisible
    private static ReplyGenerator generator = new PromptTemplateGenerator();

    /** Raised by generateDraft; its message comes from the HES_AI_Draft_Failed label. */
    public class ReplyDraftException extends Exception {}

    /**
     * For Apex callers (scripts, other classes, flows via invocable wrappers):
     * returns a reply draft or throws ReplyDraftException.
     */
    public static String generateDraft(Id caseId) {
        if (caseId == null) {
            throw newError(null);
        }
        // Only draft for cases the running user can see (record sharing respected).
        List<Case> visible = [SELECT Id FROM Case WHERE Id = :caseId WITH USER_MODE LIMIT 1];
        if (visible.isEmpty()) {
            throw newError(null);
        }

        String text;
        try {
            text = generator.generate(caseId);
        } catch (Exception e) {
            throw newError(e.getMessage());
        }
        if (String.isBlank(text)) {
            throw newError(null);
        }
        return text;
    }

    /**
     * For Lightning components (LWC / Aura): same as generateDraft, but errors are
     * converted to AuraHandledException so the user sees the label text.
     * AuraHandledException may only be thrown in a Lightning request, so Apex
     * scripts must call generateDraft instead.
     */
    @AuraEnabled
    public static String draftReply(Id caseId) {
        try {
            return generateDraft(caseId);
        } catch (ReplyDraftException e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    private static ReplyDraftException newError(String detail) {
        String message = System.Label.HES_AI_Draft_Failed + (String.isBlank(detail) ? '' : ' ' + detail);
        return new ReplyDraftException(message);
    }
}
