import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createTask from '@salesforce/apex/TodoistTaskController.createTask';

export default class TodoistTaskCreate extends LightningElement {
    @track taskContent = '';
    @track taskDescription = '';
    @track taskDueDate = '';
    @track taskPriority = '4';
    @track isLoading = false;
    @track error;

    get priorityOptions() {
        return [
            { label: 'Priority 1 (Highest)', value: '1' },
            { label: 'Priority 2', value: '2' },
            { label: 'Priority 3', value: '3' },
            { label: 'Priority 4 (Normal)', value: '4' }
        ];
    }

    handleContentChange(event) {
        this.taskContent = event.target.value;
    }

    handleDescriptionChange(event) {
        this.taskDescription = event.target.value;
    }

    handleDueDateChange(event) {
        this.taskDueDate = event.target.value;
    }

    handlePriorityChange(event) {
        this.taskPriority = event.target.value;
    }

    async handleCreateTask() {
        if (!this.taskContent) {
            this.dispatchToast('Error', 'Task title is required', 'error');
            return;
        }

        try {
            this.isLoading = true;
            this.error = undefined;

            await createTask({
                content: this.taskContent,
                description: this.taskDescription,
                dueDate: this.taskDueDate,
                priority: this.taskPriority
            });

            this.dispatchToast('Success', 'Task created in Todoist', 'success');
            this.resetForm();
        } catch (error) {
            this.error = error.body?.message || 'An error occurred while creating the task';
            this.dispatchToast('Error', this.error, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    resetForm() {
        this.taskContent = '';
        this.taskDescription = '';
        this.taskDueDate = '';
        this.taskPriority = '4';
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