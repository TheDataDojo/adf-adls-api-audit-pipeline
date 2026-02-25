targetScope = 'resourceGroup'

@description('The base name for all resources.')
param resourceBaseName string = 'adflab'

@description('The location for all resources.')
param location string = resourceGroup().location

@description('The URL of the API endpoint to call. Defaults to httpbin.org for lab use.')
param apiUrl string = 'https://httpbin.org/post'

var adfName = '${resourceBaseName}-adf'
var storageAccountName = '${toLower(resourceBaseName)}sa'

// ── Storage Account (ADLS Gen2) ──────────────────────────────────────────────
resource storage 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: storageAccountName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: { isHnsEnabled: true }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' = {
  parent: storage
  name: 'default'
}

resource inputContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  parent: blobService
  name: 'inputs'
}

resource auditContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  parent: blobService
  name: 'audit'
}

// ── Azure Data Factory ───────────────────────────────────────────────────────
resource adf 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: adfName
  location: location
  identity: { type: 'SystemAssigned' }
}

// ── RBAC: Storage Blob Data Contributor on the storage account ───────────────
resource storageBlobDataContributorRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e7a58add09c9'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, adf.name, storageBlobDataContributorRole.id)
  scope: storage
  properties: {
    roleDefinitionId: storageBlobDataContributorRole.id
    principalId: adf.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ── Nested deployment: ADF linked services, datasets, and pipeline ───────────
// The factory.json template is loaded from the same repo so forks only need
// to update the raw URL below to point to their own fork.
resource adfArtifacts 'Microsoft.Resources/deployments@2021-04-01' = {
  name: 'adf-artifacts-deployment'
  resourceGroup: resourceGroup().name
  dependsOn: [ adf, roleAssignment ]
  properties: {
    mode: 'Incremental'
    templateLink: {
      uri: 'https://raw.githubusercontent.com/TheDataDojo/adf-adls-api-audit-pipeline/master/adf/factory.json'
    }
    parameters: {
      factoryName: { value: adfName }
      storageUri: { value: storage.properties.primaryEndpoints.dfs }
      apiUrl: { value: apiUrl }
    }
  }
}

output adfName string = adfName
output storageAccountName string = storageAccountName
output storageUri string = storage.properties.primaryEndpoints.dfs
