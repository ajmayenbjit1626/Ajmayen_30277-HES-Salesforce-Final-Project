/** Tests for CaseScheduleController (LWC-02): returns a case's segments in date order with the engineer name. */
@IsTest
private class CaseScheduleControllerTest {
    static final Date MONDAY = Date.newInstance(2026, 12, 21);

    @IsTest
    static void segmentsForCase_returnsSegmentsInDateOrder() {
        User eng = TestDataFactory.engineers(1, 8)[0];
        Case c = TestDataFactory.technicalCases(1, 11)[0];
        CaseSchedulingService.todayOverride = MONDAY;
        c.OwnerId = eng.Id;
        update c;                                    // engine plans Mon 8 h, Tue 3 h

        Test.startTest();
        List<Work_Segment__c> segs = CaseScheduleController.segmentsForCase(c.Id);
        Test.stopTest();

        Assert.areEqual(2, segs.size(), 'Two segments for the 11 h case');
        Assert.areEqual(MONDAY, segs[0].Planned_Date__c, 'Sorted by date');
        Assert.isTrue(segs[0].Planned_Hours__c == 8, 'Monday 8 h');
        Assert.isTrue(segs[1].Planned_Hours__c == 3, 'Tuesday 3 h');
        Assert.isNotNull(segs[0].Capacity__r.Engineer__r.Name, 'Engineer name for the timeline');
    }

    @IsTest
    static void segmentsForCase_emptyWhenNotPlanned() {
        Case c = TestDataFactory.technicalCases(1, 11)[0];   // still in the queue
        Test.startTest();
        Assert.areEqual(0, CaseScheduleController.segmentsForCase(c.Id).size(), 'No work planned yet');
        Test.stopTest();
    }
}