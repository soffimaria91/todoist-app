import { LightningElement, api } from 'lwc';
import handleOAuthCallback from '@salesforce/apex/TodoistAuthController.handleOAuthCallback';

export default class TodoistOAuthCallback extends LightningElement {
    @api code;
    @api state;
    
    connectedCallback() {
        console.log('TodoistOAuthCallback LWC: Starting callback processing');
        this.processCallback();
    }
    
    async processCallback() {
        try {
            console.log('TodoistOAuthCallback LWC: Processing callback with code:', this.code);
            await handleOAuthCallback({ code: this.code, state: this.state });
            console.log('TodoistOAuthCallback LWC: Successfully processed callback');
            
            // Redirect to the settings page
            window.location.href = '/lightning/n/Todoist_Settings?success=true';
            
        } catch (error) {
            console.error('TodoistOAuthCallback LWC: Error processing callback:', error);
            // Show error in the parent page
            const errorContainer = document.getElementById('errorContainer');
            const errorText = document.getElementById('errorText');
            const errorDetail = document.getElementById('errorDetail');
            const loadingContainer = document.getElementById('loadingContainer');
            
            if (errorContainer && errorText && errorDetail && loadingContainer) {
                errorText.innerText = 'Error processing authentication';
                errorDetail.innerText = error.message || error.body?.message || 'Unknown error';
                errorContainer.style.display = 'block';
                loadingContainer.style.display = 'none';
            }
        }
    }
} 