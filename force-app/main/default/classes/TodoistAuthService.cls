public with sharing class TodoistAuthService {
    private static final String CONFIG_NAME = 'Default';
    
    @TestVisible
    private static Todoist_Config__mdt getConfig() {
        return [SELECT Client_Id__c, Client_Secret__c, Auth_Endpoint__c, 
                Token_Endpoint__c, Redirect_URI__c 
                FROM Todoist_Config__mdt 
                WHERE DeveloperName = :CONFIG_NAME 
                LIMIT 1];
    }
    
    public class TokenResponse {
        @AuraEnabled public String access_token;
        @AuraEnabled public String token_type;
        @AuraEnabled public Integer expires_in;
        @AuraEnabled public String refresh_token;
    }
    
    public class TodoistAuthException extends Exception {}
    
    public static String generateAuthUrl() {
        Todoist_Config__mdt config = getConfig();
        String authUrl = config.Auth_Endpoint__c + 
            '?client_id=' + EncodingUtil.urlEncode(config.Client_Id__c, 'UTF-8') +
            '&scope=' + EncodingUtil.urlEncode('task:add,data:read,data:read_write,data:delete,project:delete', 'UTF-8') +
            '&state=' + EncodingUtil.urlEncode(UserInfo.getUserId(), 'UTF-8') +
            '&redirect_uri=' + EncodingUtil.urlEncode(config.Redirect_URI__c, 'UTF-8');
        return authUrl;
    }
    
    public static void handleAuthCallback(String code, String state) {
        if (state != UserInfo.getUserId()) {
            throw new TodoistAuthException('Invalid state parameter');
        }
        
        TokenResponse tokens = exchangeCodeForTokens(code);
        upsertUserSettings(tokens);
    }
    
    private static TokenResponse exchangeCodeForTokens(String code) {
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
        
        HttpResponse response = http.send(request);
        
        if (response.getStatusCode() != 200) {
            throw new TodoistAuthException('Token exchange failed: ' + response.getBody());
        }
        
        return (TokenResponse)JSON.deserialize(response.getBody(), TokenResponse.class);
    }
    
    private static void upsertUserSettings(TokenResponse tokens) {
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
        
        settings.Access_Token__c = tokens.access_token;
        settings.Refresh_Token__c = tokens.refresh_token;
        settings.Token_Expiry__c = DateTime.now().addSeconds(tokens.expires_in);
        settings.Connected__c = true;
        
        upsert settings;
    }
    
    public static Boolean refreshTokenIfNeeded() {
        Todoist_Settings__c settings = getUserSettings();
        if (settings == null || !settings.Connected__c) {
            return false;
        }
        
        if (settings.Token_Expiry__c > DateTime.now()) {
            return true;
        }
        
        return refreshToken(settings);
    }
    
    private static Boolean refreshToken(Todoist_Settings__c settings) {
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
        
        try {
            HttpResponse response = http.send(request);
            if (response.getStatusCode() != 200) {
                settings.Connected__c = false;
                update settings;
                return false;
            }
            
            TokenResponse tokens = (TokenResponse)JSON.deserialize(response.getBody(), TokenResponse.class);
            settings.Access_Token__c = tokens.access_token;
            settings.Refresh_Token__c = tokens.refresh_token;
            settings.Token_Expiry__c = DateTime.now().addSeconds(tokens.expires_in);
            update settings;
            return true;
        } catch (Exception e) {
            settings.Connected__c = false;
            update settings;
            return false;
        }
    }
    
    public static Todoist_Settings__c getUserSettings() {
        List<Todoist_Settings__c> settings = [
            SELECT Id, Access_Token__c, Refresh_Token__c, Token_Expiry__c, Connected__c 
            FROM Todoist_Settings__c 
            WHERE User__c = :UserInfo.getUserId() 
            LIMIT 1
        ];
        return settings.isEmpty() ? null : settings[0];
    }
    
    public static void disconnectUser() {
        List<Todoist_Settings__c> settings = [
            SELECT Id FROM Todoist_Settings__c 
            WHERE User__c = :UserInfo.getUserId()
        ];
        
        if (!settings.isEmpty()) {
            delete settings;
        }
    }
} 