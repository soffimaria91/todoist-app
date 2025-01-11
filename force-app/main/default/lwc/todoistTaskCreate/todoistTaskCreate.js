import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import createTask from '@salesforce/apex/TodoistTaskController.createTask';

export default class TodoistTaskCreate extends LightningElement {
    @api recordId;
    subject = '';
    dueDate = null;
    priority = '1'; // Default to Priority 4 (Low) which maps to p1 in Todoist

    get priorityOptions() {
        return [
            { label: 'Priority 1 (Urgent)', value: '4' },
            { label: 'Priority 2 (High)', value: '3' },
            { label: 'Priority 3 (Medium)', value: '2' },
            { label: 'Priority 4 (Low)', value: '1' }
        ];
    }

    handleSubjectChange(event) {
        this.subject = event.target.value;
    }

    handleDueDateChange(event) {
        this.dueDate = event.target.value;
    }

    handlePriorityChange(event) {
        this.priority = event.target.value;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleSave() {
        if (!this.subject) {
            this.showToast('Error', 'Subject is required', 'error');
            return;
        }

        createTask({ 
            subject: this.subject, 
            dueDate: this.dueDate,
            priority: this.priority,
            relatedToId: this.recordId 
        })
            .then(() => {
                this.showToast('Success', 'Task created in Todoist', 'success');
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
} 