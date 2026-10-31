// scripts/apex/coverage-check.apex  (AI-06 real-data check)
for (String sn : new List<String>{ 'SN-4402', 'SN-4403', 'SN-4404' }) {
    CoverageLookupAction.Request r = new CoverageLookupAction.Request();
    r.serialNumber = sn;
    CoverageLookupAction.Result res = CoverageLookupAction.check(new List<CoverageLookupAction.Request>{ r })[0];
    System.debug('COVERAGE >>> ' + sn + ' | ' + res.coveragePosition + ' | plan ' + res.planName + ' | ends ' + res.endDate + ' | ' + res.message);
}