global class litmosTeamsSchedule implements Schedulable{
	//utilize the callout method already created to pull teams within specific time frame
    public void execute(SchedulableContext SC) {
        litmosTeamUpdatesScheduled.updateTeamsAndMembers();
    }
}