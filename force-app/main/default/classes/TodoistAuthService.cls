public with sharing class TodoistAuthService {
    private static final String CONFIG_NAME = 'Default';
    
    @TestVisible
    private static Todoist_Config__mdt getConfig() {
        System.debug('Getting config...');
        Todoist_Config__mdt config = [SELECT Client_Id__c, Client_Secret__c, Auth_Endpoint__c, 
                Token_Endpoint__c, Redirect_URI__c 
                FROM Todoist_Config__mdt 
                WHERE DeveloperName = :CONFIG_NAME 
                LIMIT 1];
        System.debug('Config retrieved: ' + config);
        return config;
    }
    
    public class TokenResponse {
        @AuraEnabled public String access_token;
        @AuraEnabled public String token_type;
        @AuraEnabled public Integer expires_in;
        @AuraEnabled public String refresh_token;
    }
    
    public class TodoistAuthException extends Exception {}
    
    public static String generateAuthUrl() {
        System.debug('Generating auth URL...');
        Todoist_Config__mdt config = getConfig();
        String scopes = 'task:add,data:read,data:read_write,data:delete,project:delete';
        String state = UserInfo.getUserId();
        
        String authUrl = config.Auth_Endpoint__c + 
            '?client_id=' + EncodingUtil.urlEncode(config.Client_Id__c, 'UTF-8') +
            '&scope=' + EncodingUtil.urlEncode(scopes, 'UTF-8') +
            '&state=' + EncodingUtil.urlEncode(state, 'UTF-8') +
            '&response_type=code' +
            '&redirect_uri=' + EncodingUtil.urlEncode(config.Redirect_URI__c, 'UTF-8');
        
        System.debug('Generated Auth URL: ' + authUrl);
        return authUrl;
    }
    
    public static void handleAuthCallback(String code, String state) {
        System.debug('Handling auth callback. Code: ' + (code != null) + ', State: ' + state);
        if (state != UserInfo.getUserId()) {
            throw new TodoistAuthException('Invalid state parameter');
        }
        
        Todoist_Config__mdt config = getConfig();
        
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(config.Token_Endpoint__c);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        
        String body = 'client_id=' + EncodingUtil.urlEncode(config.Client_Id__c, 'UTF-8') +
                     '&client_secret=' + EncodingUtil.urlEncode(config.Client_Secret__c, 'UTF-8') +
                     '&code=' + EncodingUtil.urlEncode(code, 'UTF-8') +
                     '&redirect_uri=' + EncodingUtil.urlEncode(config.Redirect_URI__c, 'UTF-8');
        
        request.setBody(body);
        System.debug('Token request body: ' + body);
        
        HttpResponse response = http.send(request);
        System.debug('Token response status: ' + response.getStatusCode());
        System.debug('Token response body: ' + response.getBody());
        
        if (response.getStatusCode() != 200) {
            throw new TodoistAuthException('Failed to exchange code for token: ' + response.getBody());
        }
        
        TokenResponse tokenResponse = (TokenResponse)JSON.deserialize(response.getBody(), TokenResponse.class);
        
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
        
        settings.Access_Token__c = tokenResponse.access_token;
        settings.Refresh_Token__c = tokenResponse.refresh_token;
        settings.Token_Expiry__c = DateTime.now().addSeconds(tokenResponse.expires_in);
        settings.Connected__c = true;
        
        upsert settings;
        System.debug('Settings updated successfully');
    }
    
    public static Todoist_Settings__c getUserSettings() {
        System.debug('Getting user settings...');
        List<Todoist_Settings__c> settings = [
            SELECT Id, Access_Token__c, Refresh_Token__c, Token_Expiry__c, Connected__c 
            FROM Todoist_Settings__c 
            WHERE User__c = :UserInfo.getUserId() 
            LIMIT 1
        ];
        
        if (!settings.isEmpty()) {
            System.debug('Settings found: ' + settings[0]);
            return settings[0];
        }
        System.debug('No settings found');
        return null;
    }
    
    public static Boolean refreshTokenIfNeeded() {
        System.debug('Checking if token refresh is needed...');
        Todoist_Settings__c settings = getUserSettings();
        if (settings == null || !settings.Connected__c) {
            System.debug('No settings or not connected');
            return false;
        }
        
        if (settings.Token_Expiry__c > DateTime.now()) {
            System.debug('Token still valid');
            return true;
        }
        
        if (String.isBlank(settings.Refresh_Token__c)) {
            System.debug('No refresh token available');
            return false;
        }
        
        try {
            System.debug('Refreshing token...');
            Todoist_Config__mdt config = getConfig();
            
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(config.Token_Endpoint__c);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            
            String body = 'client_id=' + EncodingUtil.urlEncode(config.Client_Id__c, 'UTF-8') +
                         '&client_secret=' + EncodingUtil.urlEncode(config.Client_Secret__c, 'UTF-8') +
                         '&refresh_token=' + EncodingUtil.urlEncode(settings.Refresh_Token__c, 'UTF-8') +
                         '&grant_type=refresh_token';
            
            request.setBody(body);
            System.debug('Refresh token request body: ' + body);
            
            HttpResponse response = http.send(request);
            System.debug('Refresh token response status: ' + response.getStatusCode());
            System.debug('Refresh token response body: ' + response.getBody());
            
            if (response.getStatusCode() != 200) {
                throw new TodoistAuthException('Failed to refresh token: ' + response.getBody());
            }
            
            TokenResponse tokenResponse = (TokenResponse)JSON.deserialize(response.getBody(), TokenResponse.class);
            
            settings.Access_Token__c = tokenResponse.access_token;
            if (!String.isBlank(tokenResponse.refresh_token)) {
                settings.Refresh_Token__c = tokenResponse.refresh_token;
            }
            settings.Token_Expiry__c = DateTime.now().addSeconds(tokenResponse.expires_in);
            
            update settings;
            System.debug('Token refreshed successfully');
            return true;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error refreshing token: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            settings.Connected__c = false;
            update settings;
            return false;
        }
    }
    
    public static void disconnectUser() {
        System.debug('Disconnecting user...');
        List<Todoist_Settings__c> settings = [
            SELECT Id 
            FROM Todoist_Settings__c 
            WHERE User__c = :UserInfo.getUserId()
        ];
        
        if (!settings.isEmpty()) {
            delete settings;
            System.debug('User disconnected successfully');
        } else {
            System.debug('No settings found to disconnect');
        }
    }
} 