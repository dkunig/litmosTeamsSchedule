public class litmosTeamUpdatesScheduled {
	private static final Litmos__Configuration__c config = [SELECT Litmos__Api_Key__c, Litmos__Api_End_Point__c FROM Litmos__Configuration__c WHERE isDeleted = false AND Litmos__Sync_Active__c = true LIMIT 1];
    
    //schedule this apex
    @future(callout=true)
    public static void updateTeamsAndMembers() {
        //for testing purposes, use this apikey and endpoint
        string apikey = 'c86a5a1f-4057-411a-99cd-e180ecfe9bee';
        
        String startDate = System.now().addDays(-6).format('yyyy-MM-dd');
        String endDate = System.now().addDays(1).format('yyyy-MM-dd');
//***********UNCOMMENT NEXT LINE FOR PRODUCTION***************************        
        String endpoint = config.Litmos__API_End_Point__c + 'org/teams';
        //String endpoint = 'https://api.litmos.com/v1.svc/org/teams';
        String endpointCap = '?source=sourceapp&since=' + startDate + '&to=' + endDate + '&format=json&limit=200';
        List<Litmos_Team__c> teams = new List<Litmos_Team__c>();
        Map<String,String> childrenIds = new Map<String, String>();
        List<Object> memberResults = new List<Object>();

        HttpResponse response = litmosConnection.getLitmosExternalService(endpoint + endpointCap, config.Litmos__Api_Key__c);
        
        if(response.getStatusCode() == 200) {
            List<Object> results = (List<Object>)(JSON.deserializeUntyped(response.getBody()));
            for(Object o : results) {
                Map<String,Object> myMap = (Map<String,Object>)o;
                teams.add(new Litmos_Team__c(
                	Name = String.valueOf(myMap.get('Name')),
                    Litmos_Id__c = String.valueOf(myMap.get('Id')),
                    Team_Code_for_Bulk_Import__c = String.valueOf(myMap.get('TeamCodeForBulkImport'))
                ));
                if(myMap.get('ParentTeamId') != '') {
                    childrenIds.put(String.valueOf(myMap.get('Id')), String.valueOf(myMap.get('ParentTeamId')));
                }
            }
        }
        //members changed on team in last 3 days
        
        response = litmosConnection.getLitmosExternalService(endpoint + '/users' + endpointCap, config.Litmos__Api_Key__c);
        if(response.getStatusCode() == 200) {
			memberResults = (List<Object>)JSON.deserializeUntyped(response.getBody());
        }
        if(teams.size() > 0) {
			updateTeams(teams, childrenIds);
            updateTeamMembers(memberResults);
        }
    }
    static void updateTeams(List<Litmos_Team__c> teams, Map<String,String> childrenIds) {
        Schema.SObjectField litmosId = Litmos_Team__c.Fields.Litmos_Id__c;
        List<Database.upsertResult> upsertResults = Database.upsert(teams, litmosId,false);
        List<Litmos_Team__c> successes = new List<Litmos_Team__c>();
        List<Litmos_Team__c> failures = new List<Litmos_Team__c>();
        Set<Id> successIds = new Set<Id>();
        Set<Id> failedIds = new Set<Id>();
        Map<String,String> errors = new Map<String,String>();
        for(Database.upsertResult r : upsertResults) {
            if(r.isSuccess()) {
                successIds.add(r.getId());
            } else {
                failedIds.add(r.getId());
                errors.put(r.getId(),String.valueOf(r.getErrors()));
            }
        }
		//update parentIds
        List<Litmos_Team__c> parents = [SELECT Id, Litmos_Id__c FROM Litmos_Team__c WHERE Litmos_Id__c IN : childrenIds.values()];
        List<Litmos_Team__c> children = [SELECT Id, Litmos_Id__c FROM Litmos_Team__c WHERE Litmos_Id__c IN : childrenIds.keySet()];

        List<Litmos_Team__c> updates = new List<Litmos_Team__c>();
        for(Litmos_Team__c c : children) {
            for(Litmos_Team__c parent : parents) {
                if(childrenIds.get(c.Litmos_Id__c) == parent.Litmos_Id__c) {
                    updates.add(new Litmos_Team__c(
                        Id = c.Id,
                        Litmos_Parent_Team__c = parent.Id
                    ));
                }
            }
        }
		//update children
        List<Database.SaveResult> updateResults = Database.update(updates, false);
        for(Database.SaveResult r : updateResults) {
            if(r.isSuccess()) {
                successIds.add(r.getId());
            } else {
                failedIds.add(r.getId());
                errors.put(r.getId(),String.valueOf(r.getErrors()));
            }
        }
        if(successIds.size() > 0) {
            litmosSyncLogs.logTeamsSuccess([SELECT Id FROM Litmos_Team__c WHERE Id IN :successIds]);
        } 
        if(errors.size() > 0) {
            litmosSyncLogs.logTeamsErrors([SELECT Id FROM Litmos_Team__c WHERE Id IN :failedIds], errors);
        }
    }
    static void updateTeamMembers(List<object> memberResults) {
        Map<String,Map<String,Litmos_Team_Member__c>> currentTeamMembers = new Map<String,Map<String,Litmos_Team_Member__c>>();
        Map<String,Id> teamIdMap = new Map<String,Id>();
        for(Litmos_Team__c team : [SELECT Id,Litmos_Id__c,(SELECT Id,Litmos_User_Id__c,Litmos_Team__c,Learner__c,Member_Type__c From Litmos_Team_Members__r) FROM Litmos_Team__c]) {
            if(!team.Litmos_Team_Members__r.isEmpty()) {
                Map<String,Litmos_Team_Member__c> memberMap = new Map<String, Litmos_Team_Member__c>();
            for(Litmos_Team_Member__c member : team.Litmos_Team_Members__r) {
                memberMap.put(member.Litmos_User_Id__c, member);
            }
            currentTeamMembers.put(team.Litmos_Id__c, memberMap);
            }
			teamIdMap.put(team.Litmos_Id__c, team.Id);
        }
        
        List<Litmos_Team_Member__c> memberUpdates = new List<Litmos_Team_Member__c>();
        List<Litmos_Team_Member__c> newMembers = new List<Litmos_Team_Member__c>();
        Set<String> userIds = new Set<String>();
        Map<String, Map<String, Litmos_Team_Member__c>> mapObjects = new Map<String, Map<String, Litmos_Team_Member__c>>();
        for(Object o : memberResults) {
            Map<String,Object> myMap = (Map<String,Object>)o;
            if(currentTeamMembers.containsKey(String.valueOf(myMap.get('TeamId')))) {
                Map<String,Litmos_Team_Member__c> thisMemberMap = currentTeamMembers.get(String.valueOf(myMap.get('TeamId')));
                if(thisMemberMap.containsKey(String.valueOf(myMap.get('Id')))) {
                    Litmos_Team_Member__c mem = thisMemberMap.get(String.valueOf(myMap.get('Id')));
                    String memberType = myMap.get('IsTeamLeader') == true ? 'Leader' : myMap.get('IsTeamAdmin') == true ? 'Admin' : 'Learner';
                    if(mem.Member_Type__c != memberType) {
                    	mem.Member_Type__c = memberType;
                        memberUpdates.add(mem);
                    }
                } else {
                    //add new member to this team
                    newMembers.add(new Litmos_Team_Member__c(
                    	Litmos_User_Id__c = String.valueOf(myMap.get('Id')),
                        Litmos_Team__c = teamIdMap.get(String.valueOf(myMap.get('TeamId'))),
                        Member_Type__c = myMap.get('IsTeamLeader') == true ? 'Leader' : myMap.get('IsTeamAdmin') == true ? 'Admin' : 'Learner'
                    ));
                    userIds.add(String.valueOf(myMap.get('Id')));
                }   
            }   
        }
        //check to see if user exists in SFDC; if not, add error log
        List<String> errors = new List<String>();
        Map<String,Id> mapUserIds = new Map<String,Id>();
        for(User u : [SELECT Id, Litmos__LitmosUserId__c FROM User WHERE Litmos__LitmosUserId__c IN : userIds]) {
            mapUserIds.put(u.Litmos__LitmosUserId__c, u.Id);
        }
        List<Litmos_Team_Member__c> insertMembers = new List<Litmos_Team_Member__c>();
        for(Litmos_Team_Member__c mem : newMembers) {
            if(mapUserIds.containsKey(mem.Litmos_User_Id__c)) {
				mem.Learner__c = mapUserIds.get(mem.Litmos_User_Id__c);
                insertMembers.add(mem);
            } else {
                errors.add('No user exists with Litmos User Id ' + mem.Litmos_User_Id__c);
            }
        }
        //insert learners
        Integer countInserts = 0;
        Integer countUpdates = 0;
        List<Database.SaveResult> saveNew = Database.insert(insertMembers);
        for(Database.SaveResult sr : saveNew) {
            if(sr.isSuccess()) {
                countInserts += 1;
            } else {
				errors.add('Error adding new team member during scheduled sync: ' + String.valueOf(sr.getErrors()));
            }
        }
        //update learners
        //
        List<Database.SaveResult> updateResults = Database.update(memberUpdates);
        for(Database.SaveResult sr : updateResults) {
            if(sr.isSuccess()) {
                countUpdates += 1;
            } else {
                errors.add('Error updating team member during scheduled sync: ' + String.valueOf(sr.getErrors()));
            }
        }
        //successes
        if(countInserts > 0) {
            litmosSyncLogs.logTeamMemberSuccess(newMembers);
        }
        if(countUpdates > 0) {
            litmosSyncLogs.logTeamMemberSuccess(memberUpdates);
        }
        //errors
        if(errors.size() > 0) {
            litmosSyncLogs.logTeamMemberErrors(errors);
        }
    }
}