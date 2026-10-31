/**
 * AI-04 / AI-05: Agent action "Search Service Articles".
 * Searches published Helios Knowledge articles with SOSL for the user's question and
 * returns the best matching articles (number, title, summary, steps and a link) so the
 * agent can answer from them and name the source.
 *
 * Why: the standard Answer Questions with Knowledge action returned no sources in this
 * developer org although the Data Cloud index held the articles (see design.md, AI-04).
 * This action is deterministic, testable and runs in user mode, so Knowledge access rules apply.
 * Governor limits: 1 SOSL search per request; the agent sends one request per question.
 */
public with sharing class SearchServiceArticlesAction {

    @TestVisible
    private static final Integer MAX_ARTICLES = 3;
    private static final Integer MAX_SEARCHES = 20;   // SOSL limit per transaction
    private static final Set<String> STOP_WORDS = new Set<String>{
        'how', 'do', 'does', 'did', 'the', 'a', 'an', 'to', 'i', 'is', 'are', 'what', 'when',
        'my', 'our', 'can', 'you', 'of', 'on', 'in', 'for', 'and', 'or', 'with', 'should',
        'please', 'there', 'it', 'be', 'me', 'we', 'this', 'that', 'which', 'why', 'too', 'not', 'any', 'get'
    };

    public class Request {
        @InvocableVariable(required=true label='Question' description='The maintenance or troubleshooting question in the user\'s words, for example "How do I reset a compressor controller?"')
        public String question;
    }

    public class Result {
        @InvocableVariable(label='Articles' description='Matching articles: number, title, summary, numbered steps and link. Answer only from this text.')
        public String articles;
        @InvocableVariable(label='Source Titles' description='Titles of the matching articles, to name as the source')
        public String sourceTitles;
        @InvocableVariable(label='Message' description='Shown when no article matches')
        public String message;
    }

    @InvocableMethod(
        label='Search Service Articles'
        description='Use for how-to, maintenance and troubleshooting questions about chillers, compressors and air dryers. Searches published Helios Knowledge articles and returns the matching articles with their steps and titles, so the answer can name its source.'
        category='Helios Service')
    public static List<Result> search(List<Request> requests) {
        List<Result> results = new List<Result>();
        Integer searches = 0;
        for (Request r : requests) {
            Result res = new Result();
            String term = buildSearchTerm(r.question);
            if (term == null || searches >= MAX_SEARCHES) {
                res.message = System.Label.HES_Agent_No_Article;
                results.add(res);
                continue;
            }
            searches++;
            String sosl = 'FIND \'' + term + '\' IN ALL FIELDS RETURNING Knowledge__kav('
                + 'Id, ArticleNumber, Title, Summary, Article_Body__c '
                + 'WHERE PublishStatus = \'Online\' AND Language = \'en_US\' '
                + 'LIMIT ' + MAX_ARTICLES + ')';
            List<List<SObject>> found = Search.query(sosl, AccessLevel.USER_MODE);
            List<Knowledge__kav> articles = (List<Knowledge__kav>) found[0];
            if (articles.isEmpty()) {
                res.message = System.Label.HES_Agent_No_Article;
            } else {
                fill(res, articles);
            }
            results.add(res);
        }
        return results;
    }

    /** Turns a question into an OR search of its meaningful words, e.g. "reset OR compressor OR controller". */
    @TestVisible
    private static String buildSearchTerm(String question) {
        if (String.isBlank(question)) {
            return null;
        }
        String cleaned = question.toLowerCase().replaceAll('[^a-z0-9 \\-]', ' ');
        List<String> words = new List<String>();
        for (String w : cleaned.split('\\s+')) {
            if (w.length() >= 3 && !STOP_WORDS.contains(w) && words.size() < 8) {
                words.add(String.escapeSingleQuotes(w.replace('-', ' ').trim()));
            }
        }
        return words.isEmpty() ? null : String.join(words, ' OR ');
    }

    private static void fill(Result res, List<Knowledge__kav> articles) {
        String base = URL.getOrgDomainUrl().toExternalForm() + '/lightning/r/Knowledge__kav/';
        List<String> blocks = new List<String>();
        List<String> titles = new List<String>();
        for (Knowledge__kav k : articles) {
            titles.add(k.Title);
            String steps = k.Article_Body__c == null ? '' :
                k.Article_Body__c.replace('<li>', '\n- ').replace('</p>', '\n').stripHtmlTags();
            blocks.add(k.Title + ' (article ' + k.ArticleNumber + ')\n'
                + 'Summary: ' + (k.Summary == null ? '' : k.Summary) + '\n'
                + 'Steps:' + steps + '\n'
                + 'Link: ' + base + k.Id + '/view');
        }
        res.articles = String.join(blocks, '\n\n');
        res.sourceTitles = String.join(titles, '; ');
    }
}
