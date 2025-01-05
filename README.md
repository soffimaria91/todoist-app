# Todoist Integration for Salesforce

This Salesforce managed package integrates Todoist task management functionality into Salesforce. It allows users to connect their Todoist accounts and create tasks directly from Salesforce.

## Features

- OAuth 2.0 authentication with Todoist
- Create Todoist tasks from Salesforce
- Secure token storage and management
- Automatic token refresh

## Installation

1. Deploy the package to your Salesforce org
2. Set up a Todoist OAuth application and configure the credentials in the `Todoist_Config__mdt` Custom Metadata Type
3. Add the "Todoist Integration User" permission set to users who need access
4. Access the app through the App Launcher

## Components

- **Custom Objects:**
  - `Todoist_Settings__c`: Stores user authentication data
  - `Todoist_Config__mdt`: Stores OAuth configuration

- **Apex Classes:**
  - `TodoistAuthService`: Handles OAuth flow and token management
  - `TodoistAuthController`: Controller for authentication UI
  - `TodoistAPIService`: Service for Todoist API operations
  - `TodoistTaskController`: Controller for task operations

- **Lightning Components:**
  - `todoistSettings`: Manages Todoist connection
  - `todoistTaskCreate`: Interface for creating tasks

## Development

This project is developed using Salesforce DX. To start developing:

1. Clone this repository
2. Authorize your dev hub: `sf org login web -d -a DevHub`
3. Create a scratch org: `sf org create scratch -f config/project-scratch-def.json -a TodoistDev`
4. Push the code: `sf project deploy start`

## Configuration

1. Create a Todoist OAuth application at https://developer.todoist.com
2. Configure the following in your Todoist app:
   - Redirect URI: Your Salesforce domain URL
   - Scopes needed: task:add, data:read, data:read_write
3. Update the `Todoist_Config__mdt` record with your OAuth credentials

## License

MIT License
