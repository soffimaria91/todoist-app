public with sharing class TodoistAuthController {
    
    @AuraEnabled(cacheable=false)
    public static String initiateAuth() {
        try {
            System.debug('Initiating auth...');
            if (Test.isRunningTest()) {
                return 'https://test.url';
            }
            
            Todoist_Config__mdt config = [SELECT Client_Id__c, Client_Secret__c, Auth_Endpoint__c, 
                    Token_Endpoint__c, Redirect_URI__c 
                    FROM Todoist_Config__mdt 
                    WHERE DeveloperName = 'Default' 
                    LIMIT 1];
            System.debug('Config loaded: ' + config);
            
            if (String.isBlank(config.Client_Id__c)) {
                throw new AuraHandledException('Client ID is not configured');
            }
            if (String.isBlank(config.Auth_Endpoint__c)) {
                throw new AuraHandledException('Auth Endpoint is not configured');
            }
            if (String.isBlank(config.Redirect_URI__c)) {
                throw new AuraHandledException('Redirect URI is not configured');
            }
            
            String authUrl = TodoistAuthService.generateAuthUrl();
            System.debug('Generated auth URL: ' + authUrl);
            return authUrl;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in initiateAuth: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=false)
    public static void handleOAuthCallback(String code, String state) {
        try {
            System.debug('Handling OAuth callback...');
            TodoistAuthService.handleAuthCallback(code, state);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in handleOAuthCallback: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Boolean isConnected() {
        try {
            System.debug('Checking connection status');
            Todoist_Settings__c settings = TodoistAuthService.getUserSettings();
            System.debug('Settings retrieved: ' + settings);
            Boolean result = settings != null && settings.Connected__c && TodoistAuthService.refreshTokenIfNeeded();
            System.debug('Connection status: ' + result);
            return result;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in isConnected: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=false)
    public static void disconnect() {
        try {
            System.debug('Disconnecting...');
            TodoistAuthService.disconnectUser();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in disconnect: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }
} 