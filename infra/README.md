
#  AZ CLI 



### AZ CLI (one by ony) Setup Environment

UniqueEnv=kh02
ProjectName=acascale
location=westeurope
rgName=${ProjectName}-${UniqueEnv}
AcrName=${ProjectName}${UniqueEnv}
VnetName=${ProjectName}-${UniqueEnv}
export AcaEnvName=${ProjectName}-${UniqueEnv}-internal

Create Resource Group and Network

```
az group create -n $rgName -l $location

VNET_ID=$(az network vnet create -g $rgName -l $location -n $VnetName \
  --address-prefixes 10.0.0.0/16 \
  --query "newVNet.id" -o tsv)
```

###  Deploy API Management

API Managmement network requirements: [here](https://learn.microsoft.com/en-us/azure/api-management/integrate-vnet-outbound)
* The virtual network must be in the same region and Azure subscription as the API Management instance.
* The subnet used for virtual network integration can only be used by a single API Management instance
* Recommended: /24 (256 addresses)
* A network security group must be associated with the subnet.
* The subnet needs to be delegated to the Microsoft.Web/serverFarms service.


API Management - not v2 not supported by cli yet, so using bicep
```

az deployment group create -g $rgName --template-file infra/apimv2.bicep \
  --parameters name=$rgName location=$location vnetName=$VnetName
```


### Build container
```
ACRSERVER=$(az acr create --name $AcrName -g $rgName -l $location \
  --sku Basic \
  --public-network-enabled true \
  --query "loginServer" -o tsv)

az acr build -r $AcrName --image express-api:0.0.1 --file ./express-api/Dockerfile express-api
```

### Deploy ACA

Create Environment, Environment is a secure boundary around one or more container apps. 2 Types of Environments 'workload profile' and 'consumption', we will use 'workload profile'

Run serverless apps with support for scale-to-zero and pay only for resources your apps use with the consumption profile. Workload profiles environments support both the Consumption and Dedicated plans 

[docs](https://learn.microsoft.com/en-us/azure/container-apps/networking?tabs=workload-profiles-env%2Cazure-cli#subnet) When using an external environment with external ingress, inbound traffic routes through the infrastructure’s public IP rather than through your subnet.  Consumption workload profile: Each IP address may be shared among multiple replicas. When planning for how many IP addresses are required for your app, plan for 1 IP address per 10 replicas.

```
ACA_SNID=$(az network vnet subnet create -n aca -g $rgName \
  --address-prefixes 10.0.0.0/23 \
  --delegations Microsoft.App/environments \
  --vnet-name $VnetName \
  --query "id" -o tsv)


ACA_DOMAIN=($(az containerapp env create -g $rgName -n $AcaEnvName -l $location\
  --enable-workload-profiles \
  --infrastructure-subnet-resource-id $ACA_SNID \
  --internal-only true \
  --query "[properties.defaultDomain,properties.staticIp]" -o tsv))

# Create Zone to allow APIM gateway to resolve apps FQDN
az network private-dns zone create -n ${ACA_DOMAIN[0]} -g $rgName

az network private-dns link vnet create -n linkvnet -g $rgName \
 -z ${ACA_DOMAIN[0]} -e 1 --virtual-network $VNET_ID

az network private-dns record-set a create -n aca -g $rgName  -z ${ACA_DOMAIN[0]}

az network private-dns record-set a add-record -n '*' -g $rgName  -z ${ACA_DOMAIN[0]} -a ${ACA_DOMAIN[1]}
                                             
```

Optional, add another plan

[docs](https://learn.microsoft.com/en-us/cli/azure/containerapp/env/workload-profile?view=azure-cli-latest#az-containerapp-env-workload-profile-add-examples) Plan == nodepool (Every Env has a Consumption workload profile by default)
 * "Dedicated-D4" - 4core / 16GiB) (D8 / D16 / D32-128 / E4-32)
 * Dedicated-NC24-A100 / Dedicated-NC48-A100
 * "Consumption" - 4 core 8Gib.
```
az containerapp env workload-profile add -g $rgName  -n $AcaEnvName \
  --workload-profile-name Dedicated \
  --workload-profile-type Dedicated-D4 
```


###  Give ACA Env an User Management Identity to Pull images from ACA

[info here](https://learn.microsoft.com/en-us/azure/container-apps/managed-identity-image-pull?tabs=bash&pivots=console)
```
IDENTITY_ID=$(az identity create -n $AcaEnvName -g $rgName \
  --query "id"  -o tsv)

# Assign UMI ACRPull on ACR
az role assignment create \
  --assignee-object-id $(az identity show --ids $IDENTITY_ID --query "principalId" -o tsv) \
  --assignee-principal-type ServicePrincipal \
  --role acrpull  \
  --scope $(az acr show -n $AcrName --query "id" -o tsv)
```
