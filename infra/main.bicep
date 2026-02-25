targetScope = 'resourceGroup'

@description('The base name for all resources.')
param resourceBaseName string = 'adf-lab'

@description('The location for all resources.')
param location string = resourceGroup().location

@description('The URL of the API endpoint to call.')
param apiUrl string = 'https://httpbin.org/post'

var adfName = '${resourceBaseName}-adf'
var storageAccountName = '${resourceBaseName}sa'

module storage 'modules/storage.bicep' = {
  name: 'storage-deployment'
  params: {
    storageAccountName: storageAccountName
    location: location
  }
}

module adf 'modules/adx.bicep' = {
  name: 'adf-deployment'
  params: {
    adfName: adfName
    location: location
    storageAccountName: storageAccountName
    apiUrl: apiUrl
    storageUri: storage.outputs.storageUri
  }
}

output adfName string = adfName
output storageAccountName string = storageAccountName
