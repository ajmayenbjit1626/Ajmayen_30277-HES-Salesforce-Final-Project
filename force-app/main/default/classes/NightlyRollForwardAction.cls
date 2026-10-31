/**
 * Called by the nightly scheduled flow Nightly_Schedule_Maintenance (CAP-06).
 * Reuses CaseSchedulingService.rollForwardStale(); there is no second copy of the planning algorithm.
 * without sharing: a system job that must see every open case and every engineer's bookings.
 * Not reachable by business users or the Agentforce agent (only the scheduled flow calls it).
 */
public without sharing class NightlyRollForwardAction {
    @InvocableMethod(label='Roll Forward Stale Work Segments'
                     description='Moves past work segments of still-open cases into the engineer\'s next free capacity and flags the cases for replanning.')
    public static void run() {
        CaseSchedulingService.rollForwardStale();
    }
}