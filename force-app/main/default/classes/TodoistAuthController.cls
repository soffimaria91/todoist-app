public with sharing class TodoistAuthController {
    
    @AuraEnabled
    public static String initiateAuth() {
        try {
            return TodoistAuthService.generateAuthUrl();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void handleOAuthCallback(String code, String state) {
        try {
            TodoistAuthService.handleAuthCallback(code, state);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Boolean isConnected() {
        try {
            Todoist_Settings__c settings = TodoistAuthService.getUserSettings();
            return settings != null && settings.Connected__c && TodoistAuthService.refreshTokenIfNeeded();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void disconnect() {
        try {
            TodoistAuthService.disconnectUser();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
} 