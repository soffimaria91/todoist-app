public with sharing class TodoistTaskController {
    
    @AuraEnabled
    public static String createTask(String content, String description, String dueDate, String priority) {
        try {
            return TodoistAPIService.createTask(content, description, dueDate, priority);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
} 