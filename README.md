
#  Example Azure using ACA Containers with API Management 

This repo contains a node/express demo app that implements a simple API, and a OpenAPI spec that can be imported into API Management.

This readme is a step-by-step set of 'az' cli commands to deploy a API Management, A set of internal ACA Environments, and builds and deploys the apps & adds the apps API to API Management.



## Deploy Infra

If you have an account with subscription scope you can deploy the full example with one command, if (more likley) you have just resource group scope, you can deploy the individual bicep files into a single resource group.

###  BICEP Subscription Scope
```
location="westeurope"
uniqueName=$(printf '%05x' $RANDOM)
deployname="${uniqueName}-acascale"

az deployment sub create -n $deployname -l $location \
  --template-file infra/main.bicep \
  --parameters name=$deployname location=$location
```



Follow the 
[deploy code (bunpg-api)](bunpg-api/README.md)

export ACRNAME=${uniqueName}acascaleacr
az acr build -r $ACRNAME --image bun-api:0.0.1 ./bunpg-api

IDENTITY_ID=$(az identity show -n ${deployname}-acaenv-identity -g ${deployname}-app-domain1 --query "id"  -o tsv)

## Need to Intergrate DNS with ACR!!; this adds A records!
https://learn.microsoft.com/en-us/azure/container-registry/container-registry-private-link#confirm-endpoint-configuration
03f3bacascaleacr A 10 10.0.25.5 False
03f3bacascaleacr.westeurope.data A 10 10.0.25.4 False

az containerapp create -g ${deployname}-app-domain1 -n bun-api \
  --environment ${deployname}-acaenv \
  --target-port 3000 --ingress external \
  --workload-profile-name "Consumption" \
  --registry-server $ACRNAME.azurecr.io \
  --registry-identity $IDENTITY_ID \
  --image $ACRNAME.azurecr.io/bun-api:0.0.1 \
  --env-vars A_PGUSER=${deployname}-acaenv-identity   A_PGNAME=${deployname} \
  --min-replicas 1  --max-replicas 2 \
  --cpu 0.5 --memory 1.0Gi





### Create App

[info here](https://learn.microsoft.com/en-us/azure/container-apps/environment)

When multiple container apps are in the same environment, they share the same virtual network and write logs to the same logging destination may share compute resources 

```
az containerapp delete -g $rgName -n app1



### Scalling

HTTP:  Every 15 seconds, the number of concurrent requests is calculated as the number of requests in the past 15 seconds divided by 15 (req/sec)Polling interval == 30 seconds for Custom (CPU etc), NOT HTTP
```
az containerapp revision copy -g $rgName -n app1 \
  --cpu 0.25 --memory 0.5Gi \
  --min-replicas 1  --max-replicas 5 \
  --scale-rule-name azure-http-rule \
  --scale-rule-type http --scale-rule-http-concurrency 20 # 20 req/sec
```



### Onboard into APIM

because of [this](https://stackoverflow.com/questions/53521346/azure-api-management-import-open-api-from-internal-service), need to run up the file locally

```
npm start
curl localhost:3000/api-docs/openapi.json > openapi.json
az apim api import -g $rgName --service-name $rgName \
  --display-name express-api \
  --service-url https://app1.${ACA_DOMAIN[0]} \
  --specification-path ./openapi.json --specification-format OpenApiJson --path express-api
 ```

Swagger file is here > 
https://app1.${ACA_DOMAIN[0]}/api-docs/openapi.json


##  Getting the Status

```
az containerapp replica list -g $rgName -n "${ACA_APP}2" --query "[].{runningState:properties.runningState}"  -o tsv
```

#  View running replicas
az containerapp replica list -g $rgName -n "${ACA_APP}2"

# Contious
while true; do  echo $(az containerapp replica list -g $rgName -n "${ACA_APP}2" --query "[].{runningState:properties.runningState}" -o tsv 2>/dev/null);  sleep 2;  done

# -c = number of requests at a time
# -n = total number of requests
bin/siege -c 100 -t 120s   https://app12.salmonwater-a9923e1b.uksouth.azurecontainerapps.io/posts/1

