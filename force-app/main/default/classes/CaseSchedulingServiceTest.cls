/**
 * Tests for the scheduling engine (CAP-01 to CAP-07, Appendix A1-A7, QA-02).
 * Calendar: Monday 21 December 2026; Thursday 24 December is the only holiday (Business Hours HES Working Week).
 * "Today" is fixed with CaseSchedulingService.todayOverride so the tests work on any run date.
 */
@IsTest
private class CaseSchedulingServiceTest {
    static final Date SUNDAY    = Date.newInstance(2026, 12, 20);
    static final Date MONDAY    = Date.newInstance(2026, 12, 21);
    static final Date TUESDAY   = Date.newInstance(2026, 12, 22);
    static final Date WEDNESDAY = Date.newInstance(2026, 12, 23);
    static final Date HOLIDAY   = Date.newInstance(2026, 12, 24);
    static final Date FRIDAY    = Date.newInstance(2026, 12, 25);
    static final Date NEXT_MON  = Date.newInstance(2026, 12, 28);

    // ---------- helpers ----------
    private static List<Work_Segment__c> segs(Id caseId) {
        return [SELECT Id, Planned_Date__c, Planned_Hours__c, Capacity__r.Engineer__c
                FROM Work_Segment__c WHERE Case__c = :caseId ORDER BY Planned_Date__c];
    }
    private static void assign(Case c, Id engineerId) {
        c.OwnerId = engineerId;
        update c;
    }
    private static Case reload(Id caseId) {
        return [SELECT Schedule_Status__c, Planned_Hours__c, Planned_Start__c, Planned_Finish__c, Needs_Replanning__c
                FROM Case WHERE Id = :caseId];
    }

    private static void hoursEqual(Decimal expected, Decimal actual, String msg) {
        // value comparison, so 8 equals 8.00
        Assert.isTrue(actual != null && expected == actual, msg + ' (expected ' + expected + ', got ' + actual + ')');
    }

    // ---------- Appendix A ----------
    @IsTest
    static void a1_fillAndSpill() {
        User eng = TestDataFactory.engineers(1, 8)[0];
        Case c = TestDataFactory.technicalCases(1, 11)[0];
        CaseSchedulingService.todayOverride = MONDAY;

        Test.startTest();
        assign(c, eng.Id);
        Test.stopTest();

        List<Work_Segment__c> s = segs(c.Id);
        Assert.areEqual(2, s.size(), 'A1: two segments');
        Assert.areEqual(MONDAY, s[0].Planned_Date__c);
        hoursEqual(8, s[0].Planned_Hours__c, '');
        Assert.areEqual(TUESDAY, s[1].Planned_Date__c);
        hoursEqual(3, s[1].Planned_Hours__c, '');
        Case r = reload(c.Id);
        Assert.areEqual('Scheduled', r.Schedule_Status__c);
        hoursEqual(11, r.Planned_Hours__c, 'CAP-04: planned = estimated');
        Assert.areEqual(MONDAY, r.Planned_Start__c);
        Assert.areEqual(TUESDAY, r.Planned_Finish__c);
    }

    @IsTest
    static void a2_partiallyBookedDay() {
        User eng = TestDataFactory.engineers(1, 8)[0];
        List<Case> cs = TestDataFactory.technicalCases(2, 11);
        cs[0].Estimated_Effort__c = 5;
        update cs[0];
        CaseSchedulingService.todayOverride = MONDAY;

        Test.startTest();
        assign(cs[0], eng.Id);   // books 5 h on Monday
        assign(cs[1], eng.Id);   // 11 h case
        Test.stopTest();

        List<Work_Segment__c> other = segs(cs[0].Id);
        Assert.areEqual(1, other.size(), 'A2: other case untouched');
        hoursEqual(5, other[0].Planned_Hours__c, '');
        List<Work_Segment__c> s = segs(cs[1].Id);
        Assert.areEqual(2, s.size());
        Assert.areEqual(MONDAY, s[0].Planned_Date__c);
        hoursEqual(3, s[0].Planned_Hours__c, 'A2: only 3 h left on Monday');
        Assert.areEqual(TUESDAY, s[1].Planned_Date__c);
        hoursEqual(8, s[1].Planned_Hours__c, '');
    }

    @IsTest
    static void a3_weekendAndHoliday() {
        User eng = TestDataFactory.engineers(1, 8)[0];
        Case c = TestDataFactory.technicalCases(1, 20)[0];
        CaseSchedulingService.todayOverride = WEDNESDAY;

        Test.startTest();
        assign(c, eng.Id);
        Test.stopTest();

        List<Work_Segment__c> s = segs(c.Id);
        Assert.areEqual(3, s.size(), 'A3: Wed, Fri, Mon');
        Assert.areEqual(WEDNESDAY, s[0].Planned_Date__c);
        hoursEqual(8, s[0].Planned_Hours__c, '');
        Assert.areEqual(FRIDAY, s[1].Planned_Date__c, 'A3: holiday 24 Dec skipped');
        hoursEqual(8, s[1].Planned_Hours__c, '');
        Assert.areEqual(NEXT_MON, s[2].Planned_Date__c, 'A3: weekend skipped');
        hoursEqual(4, s[2].Planned_Hours__c, '');
    }

    @IsTest
    static void a4_partTimeEngineer() {
        User eng = TestDataFactory.engineers(1, 6)[0];
        Case c = TestDataFactory.technicalCases(1, 11)[0];
        CaseSchedulingService.todayOverride = MONDAY;

        Test.startTest();
        assign(c, eng.Id);
        Test.stopTest();

        List<Work_Segment__c> s = segs(c.Id);
        Assert.areEqual(2, s.size());
        hoursEqual(6, s[0].Planned_Hours__c, 'A4: 6-hour day');
        hoursEqual(5, s[1].Planned_Hours__c, '');
    }

    @IsTest
    static void a5_reassignmentKeepsHistory() {
        List<User> engs = TestDataFactory.engineers(2, 8);
        Assert.isTrue(engs.size() >= 2, 'A5 needs two scheduled engineers');
        Case c = TestDataFactory.technicalCases(1, 11)[0];
        CaseSchedulingService.todayOverride = MONDAY;

        Test.startTest();
        assign(c, engs[0].Id);   // Mon 8, Tue 3 on engineer 1
        assign(c, engs[1].Id);   // Monday evening: reassigned
        Test.stopTest();

        List<Work_Segment__c> s = segs(c.Id);
        Assert.areEqual(2, s.size());
        Assert.areEqual(MONDAY, s[0].Planned_Date__c);
        hoursEqual(8, s[0].Planned_Hours__c, 'A5: today kept as history');
        Assert.areEqual(engs[0].Id, s[0].Capacity__r.Engineer__c, 'A5: history stays with engineer 1');
        hoursEqual(3, s[1].Planned_Hours__c, 'A5: outstanding 3 h replanned');
        Assert.areEqual(engs[1].Id, s[1].Capacity__r.Engineer__c, 'A5: on engineer 2');
        hoursEqual(11, reload(c.Id).Planned_Hours__c, '');
    }

    @IsTest
    static void a6_bulkTwoHundredCases() {
        List<User> engs = TestDataFactory.engineers(20, 8);   // fewer if the org has no free licences (D1)
        List<Case> cs = TestDataFactory.technicalCases(200, 11);
        CaseSchedulingService.todayOverride = MONDAY;
        for (Integer i = 0; i < cs.size(); i++) {
            cs[i].OwnerId = engs[Math.mod(i, engs.size())].Id;
        }

        Test.startTest();
        update cs;   // one data load
        Integer queriesUsed = Limits.getQueries();
        Test.stopTest();

        Assert.isTrue(queriesUsed < Limits.getLimitQueries(), 'A6: within SOQL limit');
        Integer processed = 0, scheduled = 0;
        for (Case r : [SELECT Schedule_Status__c, Planned_Hours__c FROM Case WHERE Id IN :cs]) {
            if (r.Schedule_Status__c != 'Unscheduled') { processed++; }
            if (r.Schedule_Status__c == 'Scheduled') {
                scheduled++;
                hoursEqual(11, r.Planned_Hours__c, 'A6: every scheduled case reconciles');
            }
        }
        Assert.areEqual(200, processed, 'A6: all 200 cases planned in one transaction');
        if (engs.size() >= 20) {
            Assert.areEqual(200, scheduled, 'A6: with 20 engineers every case fits');
        }
    }

    @IsTest
    static void a7_unplaceable() {
        User eng = TestDataFactory.engineers(1, 8)[0];
        Case c = TestDataFactory.technicalCases(1, 600)[0];
        CaseSchedulingService.todayOverride = MONDAY;

        Test.startTest();
        assign(c, eng.Id);
        Test.stopTest();

        List<Work_Segment__c> s = segs(c.Id);
        Assert.areEqual(43, s.size(), 'A7: 43 working days in 60 calendar days');
        Assert.areEqual(Date.newInstance(2027, 2, 18), s[s.size() - 1].Planned_Date__c, 'A7: horizon end');
        for (Work_Segment__c seg : s) {
            Assert.areNotEqual(HOLIDAY, seg.Planned_Date__c, 'A7: no work on the holiday');
        }
        Case r = reload(c.Id);
        Assert.areEqual('Unplaceable', r.Schedule_Status__c);
        hoursEqual(344, r.Planned_Hours__c, 'A7: placed hours kept');
    }

    // ---------- CAP-01, CAP-02, CAP-05, CAP-06 and negative paths ----------
    @IsTest
    static void notScheduledEngineer_noSegments() {
        User eng = TestDataFactory.engineers(1, 8)[0];
        eng.Is_Scheduled__c = false;
        System.runAs(new User(Id = UserInfo.getUserId())) { update eng; }
        Case c = TestDataFactory.technicalCases(1, 8)[0];
        CaseSchedulingService.todayOverride = MONDAY;

        Test.startTest();
        assign(c, eng.Id);   // must not fail
        Test.stopTest();

        Assert.areEqual(0, segs(c.Id).size(), 'CAP-01: no segments');
        Assert.areEqual('Unscheduled', reload(c.Id).Schedule_Status__c);
    }

    @IsTest
    static void noEffort_assignmentBlocked() {
        User eng = TestDataFactory.engineers(1, 8)[0];
        Case c = TestDataFactory.technicalCases(1, null)[0];

        Test.startTest();
        try {
            assign(c, eng.Id);
            Assert.fail('SVC-02: assignment without effort must be blocked');
        } catch (DmlException e) {
            Assert.areEqual(StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, e.getDmlType(0));
        }
        Test.stopTest();
        Assert.areEqual(0, segs(c.Id).size());
    }

    @IsTest
    static void createdAlreadyAssigned_isPlanned() {
        User eng = TestDataFactory.engineers(1, 8)[0];
        CaseSchedulingService.todayOverride = MONDAY;
        Id rt = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Technical').getRecordTypeId();

        Test.startTest();
        Case c = new Case(Subject = 'Created assigned', RecordTypeId = rt, OwnerId = eng.Id,
                          Origin = 'Phone', Estimated_Effort__c = 4);
        insert c;
        Test.stopTest();

        Assert.areEqual(1, segs(c.Id).size(), 'Created directly for an engineer: planned');
    }

    @IsTest
    static void unrelatedEdit_noReplanning() {
        User eng = TestDataFactory.engineers(1, 8)[0];
        Case c = TestDataFactory.technicalCases(1, 11)[0];
        CaseSchedulingService.todayOverride = MONDAY;
        assign(c, eng.Id);
        Set<Id> before = new Map<Id, Work_Segment__c>(segs(c.Id)).keySet();

        Test.startTest();
        c.Subject = 'Typo corrected';
        update c;
        Test.stopTest();

        Set<Id> after = new Map<Id, Work_Segment__c>(segs(c.Id)).keySet();
        Assert.areEqual(before, after, 'CAP-02: subject edit must not replan');
    }

    @IsTest
    static void effortChange_shortensAndExtends() {
        User eng = TestDataFactory.engineers(1, 8)[0];
        Case c = TestDataFactory.technicalCases(1, 11)[0];
        CaseSchedulingService.todayOverride = SUNDAY;   // Monday and Tuesday are in the future
        assign(c, eng.Id);                               // Mon 8, Tue 3

        Test.startTest();
        c.Estimated_Effort__c = 6;
        update c;
        List<Work_Segment__c> shorter = segs(c.Id);
        c.Estimated_Effort__c = 14;
        update c;
        Test.stopTest();

        Assert.areEqual(1, shorter.size(), 'Lower effort shortens the plan');
        hoursEqual(6, shorter[0].Planned_Hours__c, '');
        List<Work_Segment__c> longer = segs(c.Id);
        Assert.areEqual(2, longer.size(), 'Higher effort extends the plan');
        hoursEqual(8, longer[0].Planned_Hours__c, '');
        hoursEqual(6, longer[1].Planned_Hours__c, '');
        hoursEqual(14, reload(c.Id).Planned_Hours__c, '');
    }

    @IsTest
    static void closure_removesOnlyFutureSegments() {
        User eng = TestDataFactory.engineers(1, 8)[0];
        Case c = TestDataFactory.technicalCases(1, 11)[0];
        CaseSchedulingService.todayOverride = MONDAY;
        assign(c, eng.Id);                               // Mon 8 (today), Tue 3 (future)

        Test.startTest();
        c.Status = 'Closed';
        update c;
        Test.stopTest();

        List<Work_Segment__c> s = segs(c.Id);
        Assert.areEqual(1, s.size(), 'CAP-05: future segment removed');
        Assert.areEqual(MONDAY, s[0].Planned_Date__c, 'CAP-05: today kept as history');
    }

    @IsTest
    static void nightlyRollForward_movesStaleSegments() {
        User eng = TestDataFactory.engineers(1, 8)[0];
        Case c = TestDataFactory.technicalCases(1, 11)[0];
        CaseSchedulingService.todayOverride = MONDAY;
        assign(c, eng.Id);                               // Mon 8, Tue 3
        CaseSchedulingService.todayOverride = WEDNESDAY; // both segments are now stale

        Test.startTest();
        NightlyRollForwardAction.run();
        Test.stopTest();

        List<Work_Segment__c> s = segs(c.Id);
        Assert.areEqual(2, s.size());
        Assert.areEqual(WEDNESDAY, s[0].Planned_Date__c, 'CAP-06: moved to next free capacity');
        hoursEqual(8, s[0].Planned_Hours__c, '');
        Assert.areEqual(FRIDAY, s[1].Planned_Date__c, 'CAP-06: holiday still skipped');
        hoursEqual(3, s[1].Planned_Hours__c, '');
        Case r = reload(c.Id);
        Assert.isTrue(r.Needs_Replanning__c, 'CAP-06: case flagged');
        hoursEqual(11, r.Planned_Hours__c, 'CAP-06: no hours lost');
    }
}