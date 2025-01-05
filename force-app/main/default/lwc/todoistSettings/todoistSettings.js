import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import initiateAuth from '@salesforce/apex/TodoistAuthController.initiateAuth';
import isConnected from '@salesforce/apex/TodoistAuthController.isConnected';
import disconnect from '@salesforce/apex/TodoistAuthController.disconnect';
import handleOAuthCallback from '@salesforce/apex/TodoistAuthController.handleOAuthCallback';

export default class TodoistSettings extends LightningElement {
    @track isConnected = false;
    @track isLoading = true;
    @track error;
    
    connectedCallback() {
        this.checkConnectionStatus();
    }
    
    async checkConnectionStatus() {
        try {
            this.isLoading = true;
            this.isConnected = await isConnected();
            this.error = undefined;
        } catch (error) {
            this.error = error.body?.message || 'An error occurred while checking connection status';
        } finally {
            this.isLoading = false;
        }
    }
    
    async handleConnect() {
        try {
            this.isLoading = true;
            const authUrl = await initiateAuth();
            
            // Open the OAuth window
            const width = 600;
            const height = 700;
            const left = (screen.width/2)-(width/2);
            const top = (screen.height/2)-(height/2);
            
            window.open(
                authUrl,
                'Todoist Authorization',
                'width=' + width + ',height=' + height + ',left=' + left + ',top=' + top
            );
            
            // Listen for the OAuth callback message
            window.addEventListener('message', this.handleOAuthMessage.bind(this), false);
            
        } catch (error) {
            this.error = error.body?.message || 'An error occurred while initiating authentication';
            this.dispatchToast('Error', this.error, 'error');
        } finally {
            this.isLoading = false;
        }
    }
    
    async handleOAuthMessage(event) {
        // Verify the message origin for security
        // Replace with your actual Salesforce domain
        if (!event.origin.endsWith('.salesforce.com')) {
            return;
        }
        
        const { code, state } = event.data;
        if (code && state) {
            try {
                this.isLoading = true;
                await handleOAuthCallback({ code, state });
                await this.checkConnectionStatus();
                this.dispatchToast('Success', 'Successfully connected to Todoist', 'success');
            } catch (error) {
                this.error = error.body?.message || 'An error occurred during OAuth callback';
                this.dispatchToast('Error', this.error, 'error');
            } finally {
                this.isLoading = false;
            }
        }
    }
    
    async handleDisconnect() {
        try {
            this.isLoading = true;
            await disconnect();
            this.isConnected = false;
            this.error = undefined;
            this.dispatchToast('Success', 'Successfully disconnected from Todoist', 'success');
        } catch (error) {
            this.error = error.body?.message || 'An error occurred while disconnecting';
            this.dispatchToast('Error', this.error, 'error');
        } finally {
            this.isLoading = false;
        }
    }
    
    dispatchToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
} 