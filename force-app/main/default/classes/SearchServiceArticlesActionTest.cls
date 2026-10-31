/**
 * Tests for SearchServiceArticlesAction (AI-04 / AI-05).
 * SOSL returns nothing in tests unless Test.setFixedSearchResults is used, so each test
 * fixes the search result and checks what the action returns.
 */
@IsTest
private class SearchServiceArticlesActionTest {

    private static Knowledge__kav publishedArticle() {
        Knowledge__kav k = new Knowledge__kav(
            Title = 'KA-TEST Resetting the compressor controller',
            UrlName = 'KA-TEST-Resetting-the-compressor-controller-' + String.valueOf(Crypto.getRandomInteger()).replace('-', ''),
            Summary = 'Safe steps to reset a compressor controller.',
            Article_Body__c = '<ol><li>Press Stop.</li><li>Hold Reset for 3 seconds.</li></ol>',
            Language = 'en_US'
        );
        insert k;
        Id articleId = [SELECT KnowledgeArticleId FROM Knowledge__kav WHERE Id = :k.Id].KnowledgeArticleId;
        KbManagement.PublishingService.publishArticle(articleId, true);
        return [SELECT Id FROM Knowledge__kav WHERE KnowledgeArticleId = :articleId AND PublishStatus = 'Online' LIMIT 1];
    }

    private static SearchServiceArticlesAction.Request req(String q) {
        SearchServiceArticlesAction.Request r = new SearchServiceArticlesAction.Request();
        r.question = q;
        return r;
    }

    @IsTest
    static void matchingArticle_returnsStepsTitleAndLink() {
        Knowledge__kav k = publishedArticle();
        Test.setFixedSearchResults(new List<Id>{ k.Id });

        Test.startTest();
        SearchServiceArticlesAction.Result res = SearchServiceArticlesAction.search(
            new List<SearchServiceArticlesAction.Request>{ req('How do I reset a compressor controller?') })[0];
        Test.stopTest();

        Assert.isNull(res.message, 'No error message');
        Assert.isTrue(res.sourceTitles.contains('Resetting the compressor controller'), 'Source title returned');
        Assert.isTrue(res.articles.contains('Hold Reset for 3 seconds.'), 'Steps returned as plain text');
        Assert.isTrue(res.articles.contains('/lightning/r/Knowledge__kav/' + k.Id), 'Link to the article');
    }

    @IsTest
    static void noMatch_returnsLabelMessage() {
        Test.setFixedSearchResults(new List<Id>());
        SearchServiceArticlesAction.Result res = SearchServiceArticlesAction.search(
            new List<SearchServiceArticlesAction.Request>{ req('How do I paint a forklift?') })[0];

        Assert.isNull(res.articles, 'Nothing found');
        Assert.areEqual(System.Label.HES_Agent_No_Article, res.message);
    }

    @IsTest
    static void blankOrStopWordsOnly_returnsMessageWithoutSearching() {
        List<SearchServiceArticlesAction.Result> results = SearchServiceArticlesAction.search(
            new List<SearchServiceArticlesAction.Request>{ req(''), req('how do I do it?') });

        Assert.areEqual(System.Label.HES_Agent_No_Article, results[0].message);
        Assert.areEqual(System.Label.HES_Agent_No_Article, results[1].message);
        Assert.areEqual(0, Limits.getSoslQueries(), 'No search for empty questions');
    }

    @IsTest
    static void buildSearchTerm_keepsMeaningfulWordsOnly() {
        Assert.areEqual('reset OR compressor OR controller',
            SearchServiceArticlesAction.buildSearchTerm('How do I reset a compressor controller?'));
        Assert.areEqual('dew OR point OR high',
            SearchServiceArticlesAction.buildSearchTerm('Dew point too high?'));
    }
}
