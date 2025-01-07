import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import initiateAuth from '@salesforce/apex/TodoistAuthController.initiateAuth';
import handleOAuthCallback from '@salesforce/apex/TodoistAuthController.handleOAuthCallback';
import isConnected from '@salesforce/apex/TodoistAuthController.isConnected';
import disconnect from '@salesforce/apex/TodoistAuthController.disconnect';

export default class TodoistSettings extends LightningElement {
    @track connected = false;
    @track loading = true;
    @track error = null;

    connectedCallback() {
        this.checkConnectionStatus();
        // Check if we're returning from OAuth
        const urlParams = new URLSearchParams(window.location.search);
        const code = urlParams.get('code');
        const state = urlParams.get('state');
        
        console.log('URL Parameters:', { code: code ? 'present' : 'missing', state: state ? 'present' : 'missing' });
        
        if (code && state) {
            console.log('Handling OAuth callback');
            this.handleOAuthCallback(code, state);
        }
    }

    async checkConnectionStatus() {
        try {
            this.loading = true;
            this.error = null;
            this.connected = await isConnected();
            console.log('Connection status:', this.connected);
        } catch (error) {
            console.error('Error checking connection:', error);
            this.error = this.getErrorMessage(error);
            this.showError('Error checking connection status', this.error);
        } finally {
            this.loading = false;
        }
    }

    async handleConnect() {
        try {
            this.loading = true;
            this.error = null;
            console.log('Initiating auth...');
            const authUrl = await initiateAuth();
            console.log('Auth URL:', authUrl);
            
            if (!authUrl) {
                throw new Error('No auth URL returned');
            }

            // Redirect to Todoist auth page
            console.log('Redirecting to:', authUrl);
            window.location.assign(authUrl);
        } catch (error) {
            console.error('Error in handleConnect:', error);
            this.error = this.getErrorMessage(error);
            this.showError('Error initiating authentication', this.error);
        } finally {
            this.loading = false;
        }
    }

    async handleOAuthCallback(code, state) {
        try {
            this.loading = true;
            this.error = null;
            console.log('Processing OAuth callback');
            await handleOAuthCallback(code, state);
            await this.checkConnectionStatus();
            this.showSuccess('Successfully connected to Todoist');
            // Clear the URL parameters
            window.history.replaceState({}, document.title, window.location.pathname);
        } catch (error) {
            console.error('Error in handleOAuthCallback:', error);
            this.error = this.getErrorMessage(error);
            this.showError('Error completing authentication', this.error);
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
            this.showSuccess('Successfully disconnected from Todoist');
        } catch (error) {
            console.error('Error disconnecting:', error);
            this.error = this.getErrorMessage(error);
            this.showError('Error disconnecting', this.error);
        } finally {
            this.loading = false;
        }
    }

    getErrorMessage(error) {
        console.error('Raw error:', error);
        if (error.body && error.body.message) {
            return error.body.message;
        }
        if (error.message) {
            return error.message;
        }
        if (typeof error === 'string') {
            return error;
        }
        return 'An unknown error occurred';
    }

    showSuccess(title, message = '') {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant: 'success'
        }));
    }

    showError(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant: 'error',
            mode: 'sticky'
        }));
    }
}