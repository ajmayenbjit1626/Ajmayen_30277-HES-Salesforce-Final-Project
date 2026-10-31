
public with sharing class WorkingCalendar {
    private static Id businessHoursId;
    private static Map<Date, Boolean> cache = new Map<Date, Boolean>();

    private static Id bhId() {
        if (businessHoursId == null) {
            String name = HES_Setting__mdt.getInstance('Default').Business_Hours_Name__c;
            businessHoursId = [SELECT Id FROM BusinessHours WHERE Name = :name AND IsActive = true LIMIT 1].Id;
        }
        return businessHoursId;
    }

    public static Boolean isWorkingDay(Date d) {
        // Business hours are Mon-Fri 24h, so noon on a working day is always inside them.
        if (!cache.containsKey(d)) {
            cache.put(d, BusinessHours.isWithin(bhId(), Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0))));
        }
        return cache.get(d);
    }
}