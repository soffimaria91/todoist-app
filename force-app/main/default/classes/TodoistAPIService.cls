public with sharing class TodoistAPIService {
    private static final String API_BASE_URL = 'https://api.todoist.com/rest/v2';
    
    public class TodoistTask {
        public String content;
        public String description;
        public String due_date;
        public String priority;
        
        public TodoistTask(String content, String description, String dueDate, String priority) {
            this.content = content;
            this.description = description;
            this.due_date = dueDate;
            this.priority = String.valueOf(5 - Integer.valueOf(priority));
        }
    }
    
    public static void createTask(String content, String description, String dueDate, String priority) {
        try {
            if (!TodoistAuthService.refreshTokenIfNeeded()) {
                throw new AuraHandledException('Not authenticated with Todoist');
            }
            
            Todoist_Settings__c settings = TodoistAuthService.getUserSettings();
            if (settings == null || !settings.Connected__c) {
                throw new AuraHandledException('Not authenticated with Todoist');
            }
            
            TodoistTask task = new TodoistTask(content, description, dueDate, priority);
            
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(API_BASE_URL + '/tasks');
            request.setMethod('POST');
            request.setHeader('Authorization', 'Bearer ' + settings.Access_Token__c);
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('X-Request-Id', generateRequestId());
            
            String jsonBody = JSON.serialize(task);
            request.setBody(jsonBody);
            
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() != 200) {
                throw new AuraHandledException('Error creating task: ' + response.getBody());
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    private static String generateRequestId() {
        Blob key = Crypto.generateAesKey(128);
        String hex = EncodingUtil.convertToHex(key);
        // Ensure we don't try to substring beyond the string length
        Integer length = Math.min(hex.length(), 36);
        return hex.substring(0, length);
    }
} 