SearchServiceArticlesAction.Request r = new SearchServiceArticlesAction.Request();
r.question = 'How do I reset a compressor controller?';
SearchServiceArticlesAction.Result res = SearchServiceArticlesAction.search(new List<SearchServiceArticlesAction.Request>{ r })[0];
System.debug('ARTICLES >>> ' + res.sourceTitles + ' | ' + res.message);