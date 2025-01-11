public with sharing class TodoistAuthController {
    
    @AuraEnabled
    public static void connectWithToken(String token) {
        try {
            System.debug(LoggingLevel.DEBUG, '>>> TodoistAuthController.connectWithToken: Starting token connection');
            
            // Log user context
            System.debug(LoggingLevel.DEBUG, '>>> Current user: ' + UserInfo.getUserId() + ' (' + UserInfo.getUserName() + ')');
            
            // Ensure the user has access
            if (!Schema.sObjectType.Todoist_Settings__c.isCreateable() ||
                !Schema.sObjectType.Todoist_Settings__c.isAccessible() ||
                !Schema.sObjectType.Todoist_Settings__c.isUpdateable()) {
                throw new AuraHandledException('Insufficient permissions to manage Todoist settings');
            }
            
            if (String.isBlank(token)) {
                throw new AuraHandledException('API token is required');
            }
            
            // Test the token first
            if (!testTokenValidity(token)) {
                throw new AuraHandledException('Invalid API token. Please check and try again.');
            }
            
            // Save the token
            Todoist_Settings__c settings;
            try {
                settings = [SELECT Id FROM Todoist_Settings__c 
                           WHERE User__c = :UserInfo.getUserId() 
                           LIMIT 1];
            } catch (Exception e) {
                settings = new Todoist_Settings__c(
                    User__c = UserInfo.getUserId()
                );
            }
            
            settings.Access_Token__c = token;
            settings.Connected__c = true;
            settings.Token_Expiry__c = DateTime.now().addYears(1); // API tokens don't expire
            
            upsert settings;
            System.debug('>>> Settings updated successfully');
            
        } catch (AuraHandledException e) {
            System.debug(LoggingLevel.ERROR, '>>> AuraHandledException in connectWithToken: ' + e.getMessage());
            throw e;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '>>> Error in connectWithToken: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, '>>> Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error connecting with token: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Boolean testConnection(String token) {
        try {
            System.debug(LoggingLevel.DEBUG, '>>> TodoistAuthController.testConnection: Testing connection');
            
            if (String.isBlank(token)) {
                throw new AuraHandledException('API token is required');
            }
            
            return testTokenValidity(token);
            
        } catch (AuraHandledException e) {
            System.debug(LoggingLevel.ERROR, '>>> AuraHandledException in testConnection: ' + e.getMessage());
            throw e;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '>>> Error in testConnection: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, '>>> Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error testing connection: ' + e.getMessage());
        }
    }
    
    private static Boolean testTokenValidity(String token) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://api.todoist.com/rest/v2/projects');
        request.setMethod('GET');
        request.setHeader('Authorization', 'Bearer ' + token);
        
        try {
            HttpResponse response = http.send(request);
            System.debug('>>> Test connection response status: ' + response.getStatusCode());
            
            if (response.getStatusCode() == 200) {
                return true;
            } else {
                System.debug('>>> Test connection failed. Response: ' + response.getBody());
                return false;
            }
        } catch (Exception e) {
            System.debug('>>> Error testing token: ' + e.getMessage());
            return false;
        }
    }
    
    @AuraEnabled
    public static Boolean isConnected() {
        try {
            // Ensure the user has access to check connection status
            if (!Schema.sObjectType.Todoist_Settings__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Todoist settings');
            }
            
            System.debug('>>> Checking connection status');
            Todoist_Settings__c settings = TodoistAuthService.getUserSettings();
            System.debug('>>> Settings retrieved: ' + settings);
            System.debug('>>> Settings details - Connected: ' + (settings?.Connected__c) + ', Has token: ' + String.isNotBlank(settings?.Access_Token__c));
            
            if (settings != null && settings.Connected__c && String.isNotBlank(settings.Access_Token__c)) {
                // Test if the token is still valid
                Boolean isValid = testTokenValidity(settings.Access_Token__c);
                System.debug('>>> Token validity test result: ' + isValid);
                return isValid;
            }
            
            System.debug('>>> Not connected - either no settings, not marked as connected, or no token');
            return false;
            
        } catch (AuraHandledException e) {
            System.debug(LoggingLevel.ERROR, '>>> AuraHandledException in isConnected: ' + e.getMessage());
            throw e;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '>>> Error in isConnected: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, '>>> Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error checking connection status: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void disconnect() {
        try {
            // Ensure the user has access to disconnect
            if (!Schema.sObjectType.Todoist_Settings__c.isDeletable() ||
                !Schema.sObjectType.Todoist_Settings__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to manage Todoist settings');
            }
            
            System.debug('>>> Disconnecting...');
            TodoistAuthService.disconnectUser();
        } catch (AuraHandledException e) {
            System.debug(LoggingLevel.ERROR, '>>> AuraHandledException in disconnect: ' + e.getMessage());
            throw e;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '>>> Error in disconnect: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, '>>> Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error disconnecting from Todoist: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String initiateAuth() {
        try {
            System.debug('>>> TodoistAuthController.initiateAuth: Starting OAuth flow');
            
            // Ensure the user has access
            if (!Schema.sObjectType.Todoist_Settings__c.isCreateable() ||
                !Schema.sObjectType.Todoist_Settings__c.isAccessible() ||
                !Schema.sObjectType.Todoist_Settings__c.isUpdateable()) {
                System.debug('>>> Error: Insufficient permissions to manage Todoist settings');
                throw new AuraHandledException('Insufficient permissions to manage Todoist settings');
            }
            
            // Get the auth URL
            String authUrl = TodoistAuthService.generateAuthUrl();
            System.debug('>>> Generated auth URL: ' + authUrl);
            
            // Validate the URL
            if (String.isBlank(authUrl)) {
                System.debug('>>> Error: Generated auth URL is blank');
                throw new AuraHandledException('Failed to generate authorization URL');
            }
            
            // Ensure URL starts with https://
            if (!authUrl.startsWith('https://')) {
                System.debug('>>> Error: Generated auth URL does not start with https://');
                throw new AuraHandledException('Invalid authorization URL generated');
            }
            
            System.debug('>>> Successfully generated auth URL. Returning for redirect.');
            return authUrl;
            
        } catch (AuraHandledException e) {
            System.debug('>>> AuraHandledException in initiateAuth: ' + e.getMessage());
            throw e;
        } catch (Exception e) {
            System.debug('>>> Error in initiateAuth: ' + e.getMessage());
            System.debug('>>> Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error initiating authentication: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void handleOAuthCallback(String code, String state) {
        try {
            System.debug(LoggingLevel.DEBUG, '>>> TodoistAuthController.handleOAuthCallback: Starting OAuth callback');
            
            // Ensure the user has access
            if (!Schema.sObjectType.Todoist_Settings__c.isCreateable() ||
                !Schema.sObjectType.Todoist_Settings__c.isAccessible() ||
                !Schema.sObjectType.Todoist_Settings__c.isUpdateable()) {
                throw new AuraHandledException('Insufficient permissions to manage Todoist settings');
            }
            
            if (String.isBlank(code) || String.isBlank(state)) {
                throw new AuraHandledException('Missing required OAuth parameters');
            }
            
            // Process the OAuth callback
            TodoistAuthService.handleAuthCallback(code, state);
            System.debug('>>> Successfully processed OAuth callback');
            
        } catch (AuraHandledException e) {
            System.debug(LoggingLevel.ERROR, '>>> AuraHandledException in handleOAuthCallback: ' + e.getMessage());
            throw e;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '>>> Error in handleOAuthCallback: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, '>>> Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error processing OAuth callback: ' + e.getMessage());
        }
    }
} 