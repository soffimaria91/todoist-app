public with sharing class TodoistTaskController {
    @AuraEnabled
    public static void createTask(String subject, String dueDate, String priority, String relatedToId) {
        try {
            // Get the current user's Todoist settings
            Todoist_Settings__c settings = TodoistAuthService.getUserSettings();
            if (settings == null || !settings.Connected__c || String.isBlank(settings.Access_Token__c)) {
                throw new AuraHandledException('Not connected to Todoist. Please connect first.');
            }
            
            Map<String, Object> taskData = new Map<String, Object>{
                'content' => subject
            };
            
            if (String.isNotBlank(dueDate)) {
                taskData.put('due_date', dueDate);
            }
            
            if (String.isNotBlank(priority)) {
                taskData.put('priority', Integer.valueOf(priority));
            }
            
            // Add link to Salesforce record in description if relatedToId is provided
            if (String.isNotBlank(relatedToId)) {
                String baseUrl = URL.getSalesforceBaseUrl().toExternalForm();
                String recordUrl = baseUrl + '/' + relatedToId;
                taskData.put('description', 'Salesforce Record: ' + recordUrl);
            }
            
            String endpoint = 'https://api.todoist.com/rest/v2/tasks';
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + settings.Access_Token__c);
            req.setBody(JSON.serialize(taskData));
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() != 200) {
                throw new AuraHandledException('Error creating task in Todoist: ' + res.getBody());
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
} 