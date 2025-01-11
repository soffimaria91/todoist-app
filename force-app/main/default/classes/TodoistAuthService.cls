public with sharing class TodoistAuthService {
    private static final String CONFIG_NAME = 'Default';
    
    @TestVisible
    private static Todoist_Config__mdt getConfig() {
        System.debug(LoggingLevel.DEBUG, '>>> TodoistAuthService.getConfig: Getting configuration');
        try {
            Todoist_Config__mdt config = [SELECT Client_Id__c, Client_Secret__c, Auth_Endpoint__c, 
                    Token_Endpoint__c, Redirect_URI__c 
                    FROM Todoist_Config__mdt 
                    WHERE DeveloperName = :CONFIG_NAME 
                    LIMIT 1];
            
            System.debug(LoggingLevel.DEBUG, '>>> Configuration retrieved:');
            System.debug(LoggingLevel.DEBUG, '>>> Auth Endpoint: ' + config.Auth_Endpoint__c);
            System.debug(LoggingLevel.DEBUG, '>>> Token Endpoint: ' + config.Token_Endpoint__c);
            System.debug(LoggingLevel.DEBUG, '>>> Redirect URI: ' + config.Redirect_URI__c);
            System.debug(LoggingLevel.DEBUG, '>>> Client ID exists: ' + String.isNotBlank(config.Client_Id__c));
            
            return config;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '>>> Error retrieving configuration: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, '>>> Stack trace: ' + e.getStackTraceString());
            throw e;
        }
    }
    
    public class TokenResponse {
        @AuraEnabled public String access_token;
        @AuraEnabled public String token_type;
        @AuraEnabled public Integer expires_in;
        @AuraEnabled public String refresh_token;
    }
    
    public class TodoistAuthException extends Exception {}
    
    public static String generateAuthUrl() {
        try {
            System.debug('>>> TodoistAuthService.generateAuthUrl: Starting URL generation');
            
            Todoist_Config__mdt config = getConfig();
            if (config == null) {
                System.debug('>>> Error: Failed to retrieve configuration');
                throw new TodoistAuthException('Failed to retrieve Todoist configuration');
            }
            
            System.debug('>>> Config loaded successfully');
            System.debug('>>> Auth Endpoint: ' + config.Auth_Endpoint__c);
            System.debug('>>> Client ID exists: ' + String.isNotBlank(config.Client_Id__c));
            System.debug('>>> Redirect URI: ' + config.Redirect_URI__c);
            
            // Validate required configuration
            if (String.isBlank(config.Auth_Endpoint__c)) {
                throw new TodoistAuthException('Auth endpoint is not configured');
            }
            if (String.isBlank(config.Client_Id__c)) {
                throw new TodoistAuthException('Client ID is not configured');
            }
            if (String.isBlank(config.Redirect_URI__c)) {
                throw new TodoistAuthException('Redirect URI is not configured');
            }
            
            String state = UserInfo.getUserId();
            System.debug('>>> Generated state: ' + state);
            
            // Build the URL with proper encoding
            String authUrl = config.Auth_Endpoint__c;
            if (!authUrl.endsWith('?')) {
                authUrl += '?';
            }
            
            authUrl += 'client_id=' + EncodingUtil.urlEncode(config.Client_Id__c, 'UTF-8') +
                '&scope=' + EncodingUtil.urlEncode('task:add,data:read,data:read_write', 'UTF-8') +
                '&state=' + EncodingUtil.urlEncode(state, 'UTF-8') +
                '&redirect_uri=' + EncodingUtil.urlEncode(config.Redirect_URI__c, 'UTF-8');
            
            System.debug('>>> Generated auth URL: ' + authUrl);
            
            // Validate the generated URL
            if (!authUrl.startsWith('https://')) {
                throw new TodoistAuthException('Generated URL is not using HTTPS');
            }
            
            return authUrl;
            
        } catch (Exception e) {
            System.debug('>>> Error in generateAuthUrl: ' + e.getMessage());
            System.debug('>>> Stack trace: ' + e.getStackTraceString());
            throw new TodoistAuthException('Error generating authorization URL: ' + e.getMessage());
        }
    }
    
    public static void handleAuthCallback(String code, String state) {
        System.debug('>>> Handling auth callback. Code: ' + (code != null) + ', State: ' + state);
        
        try {
            if (state != UserInfo.getUserId()) {
                throw new TodoistAuthException('Invalid state parameter');
            }
            
            // Get the access token
            String accessToken = exchangeCodeForAccessToken(code);
            
            // Validate the token works by making a test API call
            if (!testTokenValidity(accessToken)) {
                throw new TodoistAuthException('Received invalid token from OAuth flow');
            }
            
            // Store the token using the same approach as the token-based method
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
            
            settings.Access_Token__c = accessToken;
            settings.Connected__c = true;
            settings.Token_Expiry__c = DateTime.now().addYears(1); // API tokens don't expire
            settings.Refresh_Token__c = null; // We don't need refresh tokens for Todoist
            
            upsert settings;
            System.debug('>>> Settings updated successfully with OAuth token');
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '>>> Error in handleAuthCallback: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, '>>> Stack trace: ' + e.getStackTraceString());
            throw new TodoistAuthException('Error processing OAuth callback: ' + e.getMessage());
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
    
    public static String exchangeCodeForAccessToken(String code) {
        System.debug('Exchanging code for access token...');
        Todoist_Config__mdt config = getConfig();
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(config.Token_Endpoint__c);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        String body = 'client_id=' + EncodingUtil.urlEncode(config.Client_Id__c, 'UTF-8') +
                     '&client_secret=' + EncodingUtil.urlEncode(config.Client_Secret__c, 'UTF-8') +
                     '&code=' + EncodingUtil.urlEncode(code, 'UTF-8') +
                     '&redirect_uri=' + EncodingUtil.urlEncode(config.Redirect_URI__c, 'UTF-8') +
                     '&grant_type=authorization_code';
        request.setBody(body);
        HttpResponse response = http.send(request);
        if (response.getStatusCode() == 200) {
            TokenResponse tokenResponse = (TokenResponse) JSON.deserialize(response.getBody(), TokenResponse.class);
            System.debug('Access token received: ' + tokenResponse.access_token);
            return tokenResponse.access_token;
        } else {
            System.debug('Failed to exchange code for access token: ' + response.getBody());
            throw new TodoistAuthException('Failed to exchange code for access token');
        }
    }
}