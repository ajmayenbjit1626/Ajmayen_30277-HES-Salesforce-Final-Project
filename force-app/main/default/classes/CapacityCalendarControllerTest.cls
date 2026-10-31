/**
 * Tests for CapacityCalendarController (LWC-01).
 * Uses the scheduling engine to create real segments (A1: Mon 8 h, Tue 3 h) in the week of Monday 21 December 2026,
 * then checks what the calendar receives. Thursday 24 December is the holiday in Business Hours HES Working Week.
 */
@IsTest
private class CapacityCalendarControllerTest {
    static final Date MONDAY  = Date.newInstance(2026, 12, 21);
    static final Date TUESDAY = Date.newInstance(2026, 12, 22);

    private static CapacityCalendarController.EngineerRow rowFor(List<CapacityCalendarController.EngineerRow> rows, Id engineerId) {
        for (CapacityCalendarController.EngineerRow r : rows) {
            if (r.engineerId == engineerId) { return r; }
        }
        return null;
    }

    @IsTest
    static void weekGrid_showsBookedHoursPerDayAndHoliday() {
        User eng = TestDataFactory.engineers(1, 8)[0];
        Case c = TestDataFactory.technicalCases(1, 11)[0];
        CaseSchedulingService.todayOverride = MONDAY;
        c.OwnerId = eng.Id;
        update c;                                         // engine plans Mon 8 h, Tue 3 h

        Test.startTest();
        List<CapacityCalendarController.EngineerRow> rows = CapacityCalendarController.weekGrid(MONDAY);
        Test.stopTest();

        CapacityCalendarController.EngineerRow r = rowFor(rows, eng.Id);
        Assert.isNotNull(r, 'The engineer appears in the calendar');
        Assert.isTrue(r.planned[0] == 8, 'Monday booked hours (got ' + r.planned[0] + ')');
        Assert.isTrue(r.planned[1] == 3, 'Tuesday booked hours (got ' + r.planned[1] + ')');
        Assert.isTrue(r.planned[2] == 0, 'Wednesday free');
        Assert.isTrue(r.hoursPerDay == 8, 'Capacity per day');
        Assert.isTrue(r.scheduled, 'Engineer is scheduled');
        Assert.isTrue(r.working[0], 'Monday is a working day');
        Assert.isFalse(r.working[3], 'Thursday 24 December is the holiday');
    }

    @IsTest
    static void casesForDay_returnsThatDaysCases() {
        User eng = TestDataFactory.engineers(1, 8)[0];
        Case c = TestDataFactory.technicalCases(1, 11)[0];
        CaseSchedulingService.todayOverride = MONDAY;
        c.OwnerId = eng.Id;
        update c;

        Test.startTest();
        List<Work_Segment__c> tuesday = CapacityCalendarController.casesForDay(eng.Id, TUESDAY);
        Test.stopTest();

        Assert.areEqual(1, tuesday.size(), 'One case booked on Tuesday');
        Assert.areEqual(c.Id, tuesday[0].Case__c);
        Assert.isTrue(tuesday[0].Planned_Hours__c == 3, 'Tuesday segment is 3 h');
    }

    @IsTest
    static void weekGrid_includesNotScheduledEngineer() {
        User eng = TestDataFactory.engineers(1, 8)[0];
        eng.Is_Scheduled__c = false;
        System.runAs(new User(Id = UserInfo.getUserId())) { update eng; }

        Test.startTest();
        CapacityCalendarController.EngineerRow r = rowFor(CapacityCalendarController.weekGrid(MONDAY), eng.Id);
        Test.stopTest();

        Assert.isNotNull(r, 'Not-scheduled engineers are still shown (with a badge)');
        Assert.isFalse(r.scheduled);
    }
}