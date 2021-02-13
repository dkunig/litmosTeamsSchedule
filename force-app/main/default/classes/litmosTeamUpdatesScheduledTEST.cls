@isTest
public class litmosTeamUpdatesScheduledTEST {
	@testSetup
    static void setup() {
        Litmos__Configuration__c config = new Litmos__Configuration__c(
        	Litmos__Api_Key__c = 'myapikey',
            Litmos__Api_End_Point__c = 'https://api.litmos.com/v1.svc/',
            Litmos__Sync_Active__c = true
        );
        insert config;
        Profile standardUser = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User learnerToKeep = new User(
            FirstName = 'Learner1',
            LastName = 'Keep',
            ProfileId = standardUser.Id,
            isActive = true,
            email='learner1@testLitmos.com',
            Username='learner1@testLitmos.com',
            alias='lear1',
            TimeZoneSidKey='America/New_York',
            LocaleSidKey='en_US',
            EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US',
            Litmos__LitmosUserId__c = 'EXISTING'
        );
        User learnerToAdd = new User(
            FirstName = 'Learner2',
            LastName = 'Add',
            ProfileId = standardUser.Id,
            isActive = true,
            email='addlearner@testLitmos.com',
            Username='addlearner@testLitmos.com',
            alias='lear2',
            TimeZoneSidKey='America/New_York',
            LocaleSidKey='en_US',
            EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US',
            Litmos__LitmosUserId__c = 'ADD'
        );
        User learnerToPromote = new User(
            FirstName = 'Learner3',
            LastName = 'Promote',
            ProfileId = standardUser.Id,
            isActive = true,
            email='promotelearner@testLitmos.com',
            Username='promotelearner@testLitmos.com',
            alias='lear3',
            TimeZoneSidKey='America/New_York',
            LocaleSidKey='en_US',
            EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US',
            Litmos__LitmosUserId__c = 'PROMOTE'
        );
        User learnerToDemote = new User(
            FirstName = 'Learner5',
            LastName = 'Demote',
            ProfileId = standardUser.Id,
            isActive = true,
            email='demotelearner@testLitmos.com',
            Username='demotelearner@testLitmos.com',
            alias='lear5',
            TimeZoneSidKey='America/New_York',
            LocaleSidKey='en_US',
            EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US',
            Litmos__LitmosUserId__c = 'DEMOTE'
        );
        insert new List<User>{learnerToKeep, learnerToAdd, learnerToPromote, learnerToDemote};
        
        Litmos_Team__c TEAM1 = new Litmos_Team__c(
        	Name='Existing Team',
            Litmos_Id__c = 'TEST_TEAM'
        );
        insert TEAM1;
        
        Litmos_Team_Member__c existingMem = new Litmos_Team_Member__c(
        	Litmos_Team__c = TEAM1.Id,
            Learner__c = learnerToKeep.Id,
            Litmos_User_Id__c = learnerToKeep.Litmos__LitmosUserId__c,
            Member_Type__c = 'Learner'
        );
        Litmos_Team_Member__c promoteMem = new Litmos_Team_Member__c(
        	Litmos_Team__c = TEAM1.Id,
            Learner__c = learnerToPromote.Id,
            Litmos_User_Id__c = learnerToPromote.Litmos__LitmosUserId__c,
            Member_Type__c = 'Learner'
        );
        Litmos_Team_Member__c demoteMem = new Litmos_Team_Member__c(
        	Litmos_Team__c = TEAM1.Id,
            Learner__c = learnerToDemote.Id,
            Litmos_User_Id__c = learnerToDemote.Litmos__LitmosUserId__c,
            Member_Type__c = 'Admin'
        );
        insert new List<Litmos_Team_Member__c>{existingMem, promoteMem, demoteMem};
    }
    @isTest
    public static void testTeamUpatesScheduled() {
    	Litmos__Configuration__c config = [SELECT Litmos__Api_End_Point__c, Litmos__Api_Key__c FROM Litmos__Configuration__c LIMIT 1];
        
        String startDate = System.now().addDays(-6).format('yyyy-MM-dd');
        String endDate = System.now().addDays(1).format('yyyy-MM-dd');
        Test.startTest();
        MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
        multimock.setStaticResource(config.Litmos__Api_End_Point__c + 'org/teams?source=sourceapp&since=' + startDate + '&to=' + endDate + '&format=json&limit=200', 'litmosTeamScheduledUpdates');
        multimock.setStaticResource(config.Litmos__Api_End_Point__c + 'org/teams/users?source=sourceapp&since=' + startDate + '&to=' + endDate + '&format=json&limit=200','litmosUserTeamUpdates');
        multimock.setHeader('apikey',config.Litmos__Api_Key__c);
        
        
        Test.setMock(HttpCalloutMock.class, multimock);
        litmosTeamUpdatesScheduled.updateTeamsAndMembers();
        Test.stopTest();

        //check that two teams exist
        System.assertEquals(2, [SELECT count() FROM Litmos_Team__c], 'Number of teams');
        //check that learnerToKeep is on team as a learner
        System.assertEquals(1, [SELECT count() FROM Litmos_Team_Member__c WHERE Litmos_User_Id__c = 'EXISTING' AND Member_Type__c = 'Learner'],'Expected 1 learnerToKeep');
        //check that learnerToAdd is on team as learner
        System.assertEquals(1, [SELECT count() FROM Litmos_Team_Member__c WHERE Litmos_User_Id__c = 'ADD' AND Member_Type__c = 'Learner'],'Expected 1 learnerToAdd');
        //check that learnerToPromote is now an admin
        System.assertEquals(1, [SELECT count() FROM Litmos_Team_Member__c WHERE Litmos_User_Id__c = 'PROMOTE' AND Member_Type__c = 'Admin'],'Expected 1 learnerToPromote');
        //check that learnerToDemote is now learner
        System.assertEquals(1, [SELECT count() FROM Litmos_Team_Member__c WHERE Litmos_User_Id__c = 'DEMOTE' AND Member_Type__c = 'Learner'],'Expected 1 learnerToDemote');
        //check that there are only 4 team members
        System.assertEquals(4, [SELECT count() FROM Litmos_Team_Member__c],'Expected 4 total learners');
   }
}