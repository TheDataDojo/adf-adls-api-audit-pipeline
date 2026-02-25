param adfName string
param location string
param storageAccountName string
param apiUrl string
param storageUri string

resource adf 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: adfName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
}

resource adfPipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  parent: adf
  name: 'ProcessPersonRecords'
  properties: {
    activities: [
      {
        name: 'ForEachPerson'
        type: 'ForEach'
        dependsOn: []
        userProperties: []
        typeProperties: {
          items: {
            value: '@pipeline().parameters.inputData'
            type: 'Expression'
          }
          isSequential: true
          activities: [
            {
              name: 'PostToApi'
              type: 'WebActivity'
              dependsOn: []
              policy: {
                timeout: '0.00:10:00'
                retry: 0
                retryIntervalInSeconds: 30
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                url: {
                  value: '@pipeline().parameters.apiUrl'
                  type: 'Expression'
                }
                method: 'POST'
                body: {
                  value: '@json(item())'
                  type: 'Expression'
                }
              }
            },
            {
              name: 'AppendToAuditFile'
              type: 'WebActivity'
              dependsOn: [
                {
                  activity: 'PostToApi'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              policy: {
                timeout: '0.00:10:00'
                retry: 0
                retryIntervalInSeconds: 30
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                url: {
                  value: '@concat(pipeline().parameters.storageUri, \'/audit/\', pipeline().RunId, \'/audit.jsonl?comp=appendblock&position=0\')'
                  type: 'Expression'
                }
                method: 'PATCH'
                body: {
                  value: '@json(concat(\'{\"fullPayload\":\', string(item()), \',\"timestamp\":\"\', utcNow(), \'\",\"pipelineRunId\":\"\', pipeline().RunId, '\",\"activityRunId\":\"\', activity('PostToApi').ActivityRunId, '\",\"httpStatusCode\":\', activity('PostToApi').output.StatusCode, \',\"operation\":\"Unknown\"}\'))'
                  type: 'Expression'
                }
                headers: [
                  {
                    name: 'x-ms-version'
                    value: '2021-06-08'
                  }
                ]
                authentication: {
                  type: 'MSI'
                  resource: 'https://storage.azure.com/'
                }
              }
            }
          ]
        }
      }
    ]
    parameters: {
      inputData: {
        type: 'array'
      }
      apiUrl: {
        type: 'string'
        defaultValue: apiUrl
      }
      storageUri: {
        type: 'string'
        defaultValue: storageUri
      }
    }
    annotations: []
  }
}

resource storageBlobDataContributorRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e7a58add09c9' // Storage Blob Data Contributor
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, adf.name, storageBlobDataContributorRole.id)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: storageBlobDataContributorRole.id
    principalId: adf.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
