// AI-04 (WBS 10-04): creates and publishes the 10 HES service Knowledge articles.
// Run once: sf apex run --file scripts/apex/seed-knowledge.apex
// Body field: Article_Body__c (Rich Text Area on the Knowledge object).
// Governor limits: 1 insert, 1 query, 10 publish calls.

List<List<String>> data = new List<List<String>>{
  new List<String>{ 'KA-0001 Chiller high-pressure alarm: first checks', 'KA-0001-Chiller-high-pressure-alarm',
    'First checks when a chiller stops on a high-pressure (HP) alarm.',
    '<p>A high-pressure alarm means the condenser cannot reject heat fast enough. Do not reset the alarm more than once before finding the cause.</p><ol><li>Check that the condenser fans or water pump are running.</li><li>Inspect the condenser coil for dirt, leaves or blockage; clean if needed.</li><li>Check the ambient temperature and that nothing blocks the airflow around the unit.</li><li>For water-cooled units, check water flow and inlet temperature.</li><li>Reset the alarm once and watch the discharge pressure for 15 minutes.</li><li>If the alarm returns, isolate the unit and raise a case for a refrigerant engineer.</li></ol>' },
  new List<String>{ 'KA-0002 Reading chiller fault codes', 'KA-0002-Reading-chiller-fault-codes',
    'How to read and record the fault code history on a chiller controller.',
    '<p>The controller keeps the last fault codes with date and time. Always record them before resetting.</p><ol><li>Open the controller menu and choose Alarms or Fault History.</li><li>Note each code, date, time and the operating values shown.</li><li>Look up the code in the manufacturer manual for the model on the equipment record.</li><li>Add the codes as a Case Comment so the next engineer can see them.</li><li>Only reset after the codes are recorded.</li></ol>' },
  new List<String>{ 'KA-0003 Replacing chiller air filters', 'KA-0003-Replacing-chiller-air-filters',
    'Steps to replace the air filters on an air-cooled chiller.',
    '<p>Dirty filters reduce airflow and capacity. Replace them at every service visit or when visibly dirty.</p><ol><li>Switch the unit off at the local isolator and lock it off.</li><li>Open the filter panels and remove the old filters, noting the airflow arrow.</li><li>Clean the filter frames with a soft brush.</li><li>Fit new filters of the same size with the arrow pointing towards the coil.</li><li>Close the panels, remove the lock and restart the unit.</li><li>Record the filter change in the case and update Last Service Date.</li></ol>' },
  new List<String>{ 'KA-0004 Seasonal chiller shutdown checklist', 'KA-0004-Seasonal-chiller-shutdown-checklist',
    'Checklist for shutting down a chiller for the winter season.',
    '<ol><li>Agree the shutdown date with the customer.</li><li>Run the unit and record operating pressures and temperatures.</li><li>Switch off and lock the isolator.</li><li>Drain water circuits or confirm the glycol concentration protects against frost.</li><li>Clean the condenser coil and replace air filters.</li><li>Cover the unit if it is outdoors and exposed.</li><li>Record all readings in the case and close it with the restart date in the comments.</li></ol>' },
  new List<String>{ 'KA-0005 Compressor overheating: causes and checks', 'KA-0005-Compressor-overheating',
    'Common causes of compressor overheating and what to check.',
    '<p>Overheating shortens compressor life. Find the cause before restarting repeatedly.</p><ol><li>Check the room ventilation and ambient temperature around the compressor.</li><li>Check the oil level and oil condition.</li><li>Inspect the cooler for dirt and check that its fan runs.</li><li>Check the inlet filter; a blocked filter raises the discharge temperature.</li><li>Compare the running pressure with the rated pressure on the equipment record.</li><li>If the temperature stays high, stop the unit and raise a case with the readings.</li></ol>' },
  new List<String>{ 'KA-0006 Changing screw compressor oil', 'KA-0006-Changing-screw-compressor-oil',
    'How to change the oil and oil filter on a screw compressor.',
    '<ol><li>Stop the compressor, isolate it and release all pressure from the system.</li><li>Let it cool for at least 15 minutes.</li><li>Drain the oil from the separator drain into an approved container.</li><li>Replace the oil filter and lightly oil the new seal.</li><li>Refill with the oil type on the equipment record to the correct level.</li><li>Run for 5 minutes, check for leaks and top up if needed.</li><li>Dispose of the used oil according to local rules and record the change in the case.</li></ol>' },
  new List<String>{ 'KA-0007 Resetting the compressor controller', 'KA-0007-Resetting-the-compressor-controller',
    'Safe steps to reset a compressor controller after a fault or freeze.',
    '<p>Record any active fault codes before you reset (see KA-0002).</p><ol><li>Press Stop and wait until the compressor has fully stopped.</li><li>Note the fault code and values on the display.</li><li>Press and hold the Reset button for 3 seconds until the alarm clears.</li><li>If the display freezes, switch off at the isolator, wait 30 seconds and switch on again.</li><li>Press Start and watch the unit for 10 minutes.</li><li>If the same fault returns, do not reset again; raise a case with the fault code.</li></ol>' },
  new List<String>{ 'KA-0008 Air dryer dew point too high', 'KA-0008-Air-dryer-dew-point-too-high',
    'Checks when a refrigerated air dryer shows a high pressure dew point.',
    '<ol><li>Check that the dryer is switched on and the refrigerant compressor runs.</li><li>Check the condensate drain; a blocked drain lets water back into the air.</li><li>Clean the condenser and check the dryer fan.</li><li>Check that the inlet air temperature and flow are within the dryer rating.</li><li>Check that the bypass valve is closed.</li><li>If the dew point stays high after 30 minutes, raise a case for a refrigeration check.</li></ol>' },
  new List<String>{ 'KA-0009 Refrigerant leak: first response', 'KA-0009-Refrigerant-leak-first-response',
    'What to do first when a refrigerant leak is suspected.',
    '<p>Safety first. Only certified engineers may handle refrigerant.</p><ol><li>Ventilate the area and keep people away from the plant room.</li><li>Switch the unit off at the isolator if it is safe to do so.</li><li>Do not use open flames or create sparks near the unit.</li><li>Use a leak detector to confirm the leak and note its location.</li><li>Raise a High priority case requiring a certified refrigerant engineer.</li><li>Record the refrigerant type and estimated loss for the leak log.</li></ol>' },
  new List<String>{ 'KA-0010 Preparing a site for equipment installation', 'KA-0010-Preparing-a-site-for-installation',
    'What the customer site must have before an installation visit.',
    '<ol><li>Confirm the delivery date and access route with the customer.</li><li>Check that the floor or plinth can carry the unit weight.</li><li>Check the electrical supply matches the unit rating and has a local isolator.</li><li>Check clearances around the unit for airflow and service access.</li><li>Confirm water or air connections are ready where needed.</li><li>Record the site check in the case before the installation is scheduled.</li></ol>' }
};

List<Knowledge__kav> drafts = new List<Knowledge__kav>();
for (List<String> d : data) {
    drafts.add(new Knowledge__kav(
        Title = d[0],
        UrlName = d[1],
        Summary = d[2],
        Article_Body__c = d[3],
        Language = 'en_US'
    ));
}
insert drafts;

for (Knowledge__kav k : [SELECT KnowledgeArticleId FROM Knowledge__kav WHERE Id IN :drafts]) {
    KbManagement.PublishingService.publishArticle(k.KnowledgeArticleId, true);
}
System.debug('Published articles: ' + drafts.size());
