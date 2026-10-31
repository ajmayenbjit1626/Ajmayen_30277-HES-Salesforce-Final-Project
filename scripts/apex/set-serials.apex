// One-off test data: give every unit without a serial number a unique one (SN-4401, SN-4402, ...).
// 1 query, 1 update. Prints the serial, name and coverage of each unit.
List<Equipment__c> units = [
    SELECT Id, Name, Coverage_Position__c
    FROM Equipment__c
    WHERE Serial_Number__c = null
    ORDER BY CreatedDate
    LIMIT 200
];
Integer n = 4401;
for (Equipment__c e : units) {
    e.Serial_Number__c = 'SN-' + n;
    n++;
}
update units;
for (Equipment__c e : units) {
    System.debug('SERIAL >>> ' + e.Serial_Number__c + ' | ' + e.Name + ' | ' + e.Coverage_Position__c);
}