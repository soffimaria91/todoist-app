public with sharing class TodoistAPIService {
    private static final String API_BASE_URL = 'https://api.todoist.com/rest/v2';
    
    public class TodoistTask {
        @AuraEnabled public String content { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String due_date { get; set; }
        @AuraEnabled public String priority { get; set; }
        
        public TodoistTask(String content, String description, String due_date, String priority) {
            this.content = content;
            this.description = description;
            this.due_date = due_date;
            this.priority = priority;
        }
    }
    
    public class TodoistAPIException extends Exception {}
    
    public static String createTask(String content, String description, String dueDate, String priority) {
        // First ensure we have a valid token
        if (!TodoistAuthService.refreshTokenIfNeeded()) {
            throw new TodoistAPIException('Not authenticated with Todoist');
        }
        
        Todoist_Settings__c settings = TodoistAuthService.getUserSettings();
        if (settings == null || !settings.Connected__c) {
            throw new TodoistAPIException('Not connected to Todoist');
        }
        
        TodoistTask task = new TodoistTask(content, description, dueDate, priority);
        
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(API_BASE_URL + '/tasks');
        request.setMethod('POST');
        request.setHeader('Authorization', 'Bearer ' + settings.Access_Token__c);
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('X-Request-Id', generateRequestId());
        
        Map<String, Object> requestBody = new Map<String, Object>{
            'content' => task.content,
            'description' => task.description,
            'due_date' => task.due_date,
            'priority' => Integer.valueOf(task.priority)
        };
        
        request.setBody(JSON.serialize(requestBody));
        
        HttpResponse response = http.send(request);
        
        if (response.getStatusCode() != 200) {
            throw new TodoistAPIException('Failed to create task: ' + response.getBody());
        }
        
        Map<String, Object> responseData = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
        return (String)responseData.get('id');
    }
    
    private static String generateRequestId() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 36);
    }
} 