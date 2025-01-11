import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import initiateAuth from '@salesforce/apex/TodoistAuthController.initiateAuth';
import connectWithToken from '@salesforce/apex/TodoistAuthController.connectWithToken';
import testConnection from '@salesforce/apex/TodoistAuthController.testConnection';
import isConnected from '@salesforce/apex/TodoistAuthController.isConnected';
import disconnect from '@salesforce/apex/TodoistAuthController.disconnect';

export default class TodoistSettings extends LightningElement {
    @track connected = false;
    @track loading = true;
    @track error = null;
    @track apiToken = '';

    get isTestDisabled() {
        return !this.apiToken || this.loading;
    }

    connectedCallback() {
        console.log('[TodoistSettings] Component initialized');
        
        // Check if we're returning from OAuth
        const urlParams = new URLSearchParams(window.location.search);
        const success = urlParams.get('success');
        
        if (success === 'true') {
            console.log('[TodoistSettings] Detected successful OAuth callback');
            // Clear the success parameter from the URL without refreshing
            const newUrl = window.location.pathname;
            window.history.replaceState({}, '', newUrl);
            
            // Show success message
            this.showSuccess('Successfully connected to Todoist');
        }
        
        this.checkConnectionStatus();
    }

    async handleConnect() {
        try {
            this.loading = true;
            this.error = null;
            console.log('[TodoistSettings] Initiating OAuth flow...');
            const authUrl = await initiateAuth();
            console.log('[TodoistSettings] Generated auth URL:', authUrl);
            console.log('[TodoistSettings] Current location:', window.location.href);
            console.log('[TodoistSettings] Attempting redirect...');
            
            // Force the redirect using window.open
            const redirectWindow = window.open(authUrl, '_self');
            if (!redirectWindow) {
                throw new Error('Failed to open redirect window. Please check your popup blocker settings.');
            }
            
            console.log('[TodoistSettings] Redirect initiated');
        } catch (error) {
            console.error('[TodoistSettings] Error initiating OAuth:', error);
            console.error('[TodoistSettings] Error details:', {
                message: error.message,
                body: error.body,
                stack: error.stack
            });
            this.error = this.getErrorMessage(error);
            this.showError('Error initiating authentication', this.error);
            this.loading = false;
        }
    }

    async checkConnectionStatus() {
        try {
            this.loading = true;
            this.error = null;
            console.log('[TodoistSettings] Checking connection status...');
            this.connected = await isConnected();
            console.log('[TodoistSettings] Connection status:', this.connected);
        } catch (error) {
            console.error('[TodoistSettings] Error checking connection:', error);
            console.error('[TodoistSettings] Error details:', {
                message: error.message,
                body: error.body,
                stack: error.stack
            });
            this.error = this.getErrorMessage(error);
            this.showError('Error checking connection status', this.error);
        } finally {
            this.loading = false;
        }
    }

    handleTokenChange(event) {
        this.apiToken = event.target.value;
    }

    async handleTokenConnect() {
        if (!this.apiToken) {
            this.showError('Error', 'Please enter a valid API token');
            return;
        }

        try {
            this.loading = true;
            this.error = null;
            console.log('[TodoistSettings] Connecting with token...');
            await connectWithToken({ token: this.apiToken });
            console.log('[TodoistSettings] Successfully connected with token');
            this.connected = true;
            this.showSuccess('Successfully connected to Todoist');
            await this.checkConnectionStatus();
        } catch (error) {
            console.error('[TodoistSettings] Error connecting with token:', error);
            this.error = this.getErrorMessage(error);
            this.showError('Error connecting to Todoist', this.error);
        } finally {
            this.loading = false;
        }
    }

    async handleTestConnection() {
        if (!this.apiToken) {
            this.showError('Error', 'Please enter a valid API token');
            return;
        }

        try {
            this.loading = true;
            this.error = null;
            console.log('[TodoistSettings] Testing connection...');
            const result = await testConnection({ token: this.apiToken });
            console.log('[TodoistSettings] Test connection result:', result);
            this.showSuccess('Connection test successful');
        } catch (error) {
            console.error('[TodoistSettings] Error testing connection:', error);
            this.error = this.getErrorMessage(error);
            this.showError('Connection test failed', this.error);
        } finally {
            this.loading = false;
        }
    }

    async handleDisconnect() {
        try {
            this.loading = true;
            this.error = null;
            await disconnect();
            this.connected = false;
            this.apiToken = '';
            this.showSuccess('Successfully disconnected from Todoist');
        } catch (error) {
            console.error('[TodoistSettings] Error disconnecting:', error);
            this.error = this.getErrorMessage(error);
            this.showError('Error disconnecting', this.error);
        } finally {
            this.loading = false;
        }
    }

    getErrorMessage(error) {
        console.log('[TodoistSettings] Getting error message for:', error);
        if (error.body && error.body.message) {
            console.log('[TodoistSettings] Using error.body.message:', error.body.message);
            return error.body.message;
        }
        if (error.message) {
            console.log('[TodoistSettings] Using error.message:', error.message);
            return error.message;
        }
        if (typeof error === 'string') {
            console.log('[TodoistSettings] Using error string:', error);
            return error;
        }
        console.log('[TodoistSettings] Using default error message');
        return 'An unknown error occurred';
    }

    showSuccess(title, message = '') {
        console.log('[TodoistSettings] Showing success toast:', { title, message });
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant: 'success'
        }));
    }

    showError(title, message) {
        console.log('[TodoistSettings] Showing error toast:', { title, message });
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant: 'error',
            mode: 'sticky'
        }));
    }
}