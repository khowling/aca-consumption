

targetScope = 'subscription'
param location string = 'westeurope'

@description('Unique prefix name of the project')
param name string 

// common-rg - Networking / monitoring etc (inline with workload LZ)
//
resource rgCommon 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: '${name}-common'
  location: location
}

module modCommon './01common.bicep' = {
  name: 'common'
  scope: rgCommon
  params: {
    location: location
    name: name
  }
}

// access-rg - for Proxy to all downstream APIs 
//
resource rgAccess 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: '${name}-apim'
  location: location
}

module modApim './02apimv2.bicep' = {
  name: 'apim'
  scope: rgAccess
  params: {
    location: location
    name: name
    subnetId: modCommon.outputs.apimSubnetId
  }
}


// access-rg - for Proxy to all downstream APIs 
//
resource rgAppDomain1 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: '${name}-app-domain1'
  location: location
}

module modDomain1Pg './03pgflex.bicep' = {
  name: 'app-domain1-pg'
  scope: rgAppDomain1
  params: {
    location: location
    administratorLogin: 'pgadmin'
    administratorLoginPassword: 'P@ssw0rd'
    name: name
    vnetId: modCommon.outputs.vnetId
    subnetId: modCommon.outputs.pgSubnetId
  }
}

module modDomain1ACA './03acaenv.bicep' = {
  name: 'app-domain1-aca'
  scope: rgAppDomain1
  params: {
    location: location
    name: name
    vnetId: modCommon.outputs.vnetId
    subnetId: modCommon.outputs.acaSubnetId
  }
}
