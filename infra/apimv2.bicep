
param publisherEmail string = 'name@mail.com'
param publisherName string = 'name'
param name string
param location string
param vnetName string


// get existint vnet resource
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

// create subnet
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: 'apim'
  parent: vnet
  properties: {
    addressPrefix: '10.0.20.0/23'
    delegations: [
      {
        name: 'WebServerFarms'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
    networkSecurityGroup: {
      id: apinsg.id
    }
  }
}

// create nsg - APIM v2 requires NSG
resource apinsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${name}-nsg'
  location: location
  properties: {
    
    securityRules: [
      {
        name: 'InternetInBound'
        properties: {
          access: 'Allow'
          description: 'ApiManagementInBound'
          destinationAddressPrefix: '*'
  
          destinationPortRange: '*'
          direction: 'Inbound'
          priority: 1000
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
        }
        type: 'Inbound'
      }
      {
        name: 'InternetOutBound'
        properties: {
          access: 'Allow'
          description: 'ApiManagementOutBound'
          destinationAddressPrefix: '*'
      
          destinationPortRange: '*'
          direction: 'Outbound'
          priority: 1000
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
        }
        type: 'Outbound'
      }
    ]
  }
}


resource apiManagementService 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: name
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
      subnetResourceId: subnet.id
    }

  }
}

