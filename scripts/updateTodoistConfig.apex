Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
customMetadata.fullName = 'Todoist_Config.Default';
customMetadata.label = 'Default';

Metadata.CustomMetadataValue authEndpoint = new Metadata.CustomMetadataValue();
authEndpoint.field = 'Auth_Endpoint__c';
authEndpoint.value = 'https://todoist.com/oauth/authorize';

Metadata.CustomMetadataValue tokenEndpoint = new Metadata.CustomMetadataValue();
tokenEndpoint.field = 'Token_Endpoint__c';
tokenEndpoint.value = 'https://todoist.com/oauth/access_token';

Metadata.CustomMetadataValue clientId = new Metadata.CustomMetadataValue();
clientId.field = 'Client_Id__c';
clientId.value = 'e5abe760526e4f6eb73521871cabff69';

Metadata.CustomMetadataValue clientSecret = new Metadata.CustomMetadataValue();
clientSecret.field = 'Client_Secret__c';
clientSecret.value = 'b5f09cb1fc0540afbea2b0f9c1dae80a';

Metadata.CustomMetadataValue redirectUri = new Metadata.CustomMetadataValue();
redirectUri.field = 'Redirect_URI__c';
redirectUri.value = 'https://gmailcomdev266-dev-ed.develop.lightning.force.com/apex/TodoistOAuthCallback';

customMetadata.values = new List<Metadata.CustomMetadataValue>{
    authEndpoint, tokenEndpoint, clientId, clientSecret, redirectUri
};

Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
mdContainer.addMetadata(customMetadata);

Id jobId = Metadata.Operations.enqueueDeployment(mdContainer, null); 