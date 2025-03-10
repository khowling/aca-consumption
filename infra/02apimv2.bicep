
param publisherEmail string = 'name@mail.com'
param publisherName string = 'name'
param name string
param location string
param subnetId string





resource apiManagementService 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  // Service Name can contain only letters, numbers and hyphens. The first character must be a letter and last character must be a letter or a number.
  name: 'apim${replace(name, '-', '')}'
  location: location
  sku: {
    name: 'Standardv2'
    capacity: 1
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName

    virtualNetworkType: 'External'
    virtualNetworkConfiguration: {
      subnetResourceId: subnetId
    }

  }
}

