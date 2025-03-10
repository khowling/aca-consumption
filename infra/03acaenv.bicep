param name string
param location string
param acasuffix string = '01'

param vnetId string
param subnetId string


// create user managed identtiy
resource acaenvIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: '${name}-acaenv-identity'
  location: location
}

// create azure container apps environment
resource acaenv 'Microsoft.App/managedEnvironments@2024-10-02-preview' = {
  name: '${name}-acaenv'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${acaenvIdentity.id}': {}
    }
  }
  properties: { 
    publicNetworkAccess: 'Disabled'
    vnetConfiguration: {
      infrastructureSubnetId: subnetId
      internal: true
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}


// create private dns zone
resource acaDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: '${location}.azurecontainerapps.io'
  location: 'global'
  
  // create vnet link
  resource vnetLink 'virtualNetworkLinks' = {
    name: name
    location: 'global'
    properties: {
      virtualNetwork: {
        id: vnetId
      }
      registrationEnabled: false
    }
  }

  // create privatedns zone A record
  resource acaDnsRecord 'A' = {
    name: '*'
    properties: {
      ttl: 3600
      aRecords: [
        {
          ipv4Address: acaenv.properties.staticIp
        }
      ]
    }
  }
}






