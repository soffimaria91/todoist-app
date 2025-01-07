public with sharing class TodoistTaskController {
    
    @AuraEnabled
    public static void createTask(String content, String description, String dueDate, String priority) {
        try {
            TodoistAPIService.createTask(content, description, dueDate, priority);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
} 