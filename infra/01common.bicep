
param location string
param name string

// create vnet

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: '${name}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
  }
}

@batchSize(1)
resource subnets 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = [for (sn, index) in [api_sub, aca_sub, pg_sub, pe_sub]: {
  parent: vnet
  name: sn.name
  properties: sn.properties
}]


output vnetId string = vnet.id


// create APIM subnet
// create nsg - APIM v2 requires NSG
resource apinsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${name}-apim-nsg'
  location: location
  properties: {
    /*
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
      */
  }
}


var api_sub = {
  name: 'apim'
  properties: {
    addressPrefix:  '10.0.20.0/23'
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

output apimSubnetId string = subnets[0].id


// https://learn.microsoft.com/en-us/azure/container-apps/networking?tabs=workload-profiles-env%2Cazure-cli#subnet
// If you use your own VNet, you need to provide a subnet that is dedicated exclusively to the Container App environment you deploy.
// /27 is the minimum subnet size required for virtual network integration. 
// Container Apps automatically reserves 12 IP addresses for integration with the subnet + Consumption plan for 1 IP address per 10 replicas.
var aca_sub = {
  name: 'acaenv'
  properties: {
    addressPrefix: '10.0.22.0/27'
    delegations: [
      {
        name: 'AcaEnv'
        properties: {
          serviceName: 'Microsoft.App/environments'
        }
      }
    ]
    networkSecurityGroup: {
      id: acansg.id
    }
  }
}

// create nsg - APIM v2 requires NSG
resource acansg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${name}-aca-nsg'
  location: location
  properties: {
  }
}


output acaSubnetId string = subnets[1].id


//Minimum: /28, enough for a single Azure Database for PostgreSQL flexible server with high-availability
param PgsubNetAddressPrefix string = '10.0.23.0/28'



// https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-networking-private
// virtual network injection : only Azure Database for PostgreSQL flexible servers can use that subnet.
// A single Azure Database for PostgreSQL flexible server with high-availability features uses four addresses
// The smallest CIDR range you can specify for the subnet is /28
var pg_sub = {
  name: 'pg'
  properties: {
    addressPrefix: PgsubNetAddressPrefix
    delegations: [
      {
        name: 'DBforPostgreSQL'
        properties: {
          serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
        }
      }
    ]
    networkSecurityGroup: {
      id: pgnsg.id
    }
  }
}

// create NSG
// PostGres requires outbound rule to AzureActiveDirectory
resource pgnsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${name}-pg-nsg'
  location: location
  properties: {
    
    securityRules: [
      {
        name: 'EntraIDInBound'
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
        name: 'EntraIDOutBound'
        properties: {
          access: 'Allow'
          description: 'ApiManagementOutBound'
          destinationAddressPrefix: 'AzureActiveDirectory'
      
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

output pgSubnetId string = subnets[2].id


// Trying to add the subnets within the bicep modules doesnt work, as cannot create subnet within the vnet resource in different rg
// ERROR "A resource's computed scope must match that of the Bicep file for it to be deployable"

// Basic doesnt support private link, need to go premium
// https://docs.microsoft.com/en-us/azure/container-registry/container-registry-private-link

param PEsubNetAddressPrefix string = '10.0.25.0/28'
// https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-networking-private
// virtual network injection : only Azure Database for PostgreSQL flexible servers can use that subnet.
// A single Azure Database for PostgreSQL flexible server with high-availability features uses four addresses
// The smallest CIDR range you can specify for the subnet is /28
// disable private endpoint network policies
var pe_sub  = {
  name: 'privateends'
  properties: {
    addressPrefix: PEsubNetAddressPrefix
    privateEndpointNetworkPolicies: 'Disabled'
  }
}



// create private endpoint
resource pe 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${replace(name, '-', '')}-pe'
  location: location
  properties: {
    subnet: {
      id: subnets[3].id
    }
    privateLinkServiceConnections: [
      {
        name: 'privatelink'
        properties: {
          privateLinkServiceId: acr.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
}

// create private dns zone
resource peDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.azurecr.io'
  location: 'global'
  
  // create vnet link
  resource vnetLink 'virtualNetworkLinks' = {
    name: name
    location: 'global'
    properties: {
      virtualNetwork: {
        id: vnet.id
      }
      registrationEnabled: false
    }
  }
}

// create container registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: '${replace(name, '-', '')}acr'
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}


