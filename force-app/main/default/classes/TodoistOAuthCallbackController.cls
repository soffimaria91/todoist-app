public with sharing class TodoistOAuthCallbackController {
    
    public Boolean hasError { get; private set; }
    public String errorMessage { get; private set; }
    
    public PageReference handleCallback() {
        System.debug('TodoistOAuthCallback: Starting callback processing');
        
        try {
            // Get parameters from URL
            String code = ApexPages.currentPage().getParameters().get('code');
            String state = ApexPages.currentPage().getParameters().get('state');
            String error = ApexPages.currentPage().getParameters().get('error');
            
            System.debug('TodoistOAuthCallback: Code present: ' + (String.isNotBlank(code)));
            System.debug('TodoistOAuthCallback: State present: ' + (String.isNotBlank(state)));
            System.debug('TodoistOAuthCallback: Error: ' + error);
            
            if (String.isNotBlank(error)) {
                String errorDesc = ApexPages.currentPage().getParameters().get('error_description');
                throw new TodoistAuthService.TodoistAuthException(error + (String.isNotBlank(errorDesc) ? ': ' + errorDesc : ''));
            }
            
            // Verify CRUD permissions
            if (!Schema.sObjectType.Todoist_Settings__c.isCreateable() ||
                !Schema.sObjectType.Todoist_Settings__c.isAccessible() ||
                !Schema.sObjectType.Todoist_Settings__c.isUpdateable()) {
                throw new TodoistAuthService.TodoistAuthException('Insufficient permissions to manage Todoist settings');
            }
            
            if (String.isBlank(code) || String.isBlank(state)) {
                throw new TodoistAuthService.TodoistAuthException('Missing required OAuth parameters');
            }
            
            // Process the OAuth callback
            TodoistAuthService.handleAuthCallback(code, state);
            System.debug('TodoistOAuthCallback: Successfully processed callback');
            
            // Redirect to the settings page
            PageReference settingsPage = new PageReference('/lightning/n/Todoist_Settings');
            settingsPage.getParameters().put('success', 'true');
            settingsPage.setRedirect(true);
            return settingsPage;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'TodoistOAuthCallback: Error: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'TodoistOAuthCallback: Stack trace: ' + e.getStackTraceString());
            
            hasError = true;
            errorMessage = e.getMessage();
            return null;
        }
    }
}
// Closing brace for the class definition