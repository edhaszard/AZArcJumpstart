#!/bin/bash

# <--- Change the following environment variables according to your Azure service principal name --->

# export subscriptionId='<Your Azure subscription ID>'
# export appId='<Your Azure service principal name>'
# export password='<Your Azure service principal password>'
# export tenantId='<Your Azure tenant ID>'
# export resourceGroup='<Azure resource group name>'
# export arcClusterName='<Azure Arc Cluster Name>'
# export k8sExtensionName='<OSM extension name' #default: 'osm'

export subscriptionId='ebb856bd-cdcb-4e79-92bd-02911c47395f'
export appId='9df28080-4024-4114-8320-4b6b2bbbbd3d'
export password='2TXSUqXpC121s4m0Hd4qJD7h5_TuWl_t4y'
export tenantId='72f988bf-86f1-41af-91ab-2d7cd011db47'
export resourceGroup='arc-capi-azure'
export arcClusterName='arc-capi-azure'
export k8sOSMExtensionName='osm'
export k8sMonitorExtensionName='azuremonitor-containers'
export capiWorkLoadClusterName='arc-capi-azure'
export osmVersion=0.8.3
export system=$(uname -s)

export bookStoreNameSpace="bookstore"
export bookbuyerNameSpace="bookbuyer"
export bookthiefNameSpace="bookthief"
export bookwarehouseNameSpace="bookwarehouse"

export bookBuyerLocalPort="8080"
export bookStoreLocalPort="8081"
export bookThiefLocalPort="8083"

# Installing Helm 3
echo "Installing Helm 3"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Installing Azure CLI & Azure Arc Extensions
echo "Installing Azure CLI"
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

echo "Clear cached helm Azure Arc Helm Charts"
rm -rf ~/.azure/AzureArcCharts

echo "Checking if you have up-to-date Azure Arc AZ CLI 'connectedk8s' extension..."
az extension show --name "connectedk8s" &> extension_output
if cat extension_output | grep -q "not installed"; then
az extension add --name "connectedk8s"
rm extension_output
else
az extension update --name "connectedk8s"
rm extension_output
fi
echo ""

echo "Checking if you have up-to-date Azure Arc AZ CLI 'k8s-extension' extension..."
az extension show --name "k8s-extension" &> extension_output
if cat extension_output | grep -q "not installed"; then
az extension add --name "k8s-extension"
rm extension_output
else
az extension update --name "k8s-extension"
rm extension_output
fi
echo ""

echo "Login to Az CLI using the service principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

echo "Create OSM Kubernetes extension instance"
az k8s-extension create --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --extension-type Microsoft.openservicemesh --scope cluster --release-train pilot --name $k8sOSMExtensionName --release-namespace arc-osm-system --version $osmVersion

echo "Create Azure Monitor k8s extension instance"
az k8s-extension create --name $k8sMonitorExtensionName --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers

echo "verify OSM component instllation"
kubectl get pods -n arc-osm-system

#Setup OSM cli 

# remove older copies of OSM binaries
rm -rf /usr/local/bin/osm

# download OSM binaries
curl -L https://github.com/openservicemesh/osm/releases/download/${osmVersion}/osm-${osmVersion}-${system}-amd64.tar.gz | tar -vxzf -

./${system}-amd64/osm version

#copy the OSM binary to local bin folder
sudo cp ./linux-amd64/osm /usr/local/bin/osm

#display current osm version
osm version

# Create the Bookstore Application Namespaces
kubectl create namespace $bookStoreNameSpace
kubectl create namespace $bookbuyerNameSpace
kubectl create namespace $bookthiefNameSpace
kubectl create namespace $bookwarehouseNameSpace

# Onboard the Namespaces to the OSM Mesh and enable sidecar injection on the namespaces
osm namespace add $bookStoreNameSpace
osm namespace add $bookbuyerNameSpace
osm namespace add $bookthiefNameSpace
osm namespace add $bookwarehouseNameSpace

# Enable metrics for pods belonging to app namespaces
osm metrics enable --namespace "$bookStoreNameSpace,$bookbuyerNameSpace,$bookthiefNameSpace,$bookwarehouseNameSpace"

# update the namespaces to be monitored first in the yaml file below
kubectl apply -f container-azm-ms-osmconfig.yaml

# Create the Kubernetes resources for the bookstore demo applications
kubectl apply -f https://raw.githubusercontent.com/openservicemesh/osm/main/docs/example/manifests/apps/bookbuyer.yaml
kubectl apply -f https://raw.githubusercontent.com/openservicemesh/osm/main/docs/example/manifests/apps/bookthief.yaml
kubectl apply -f https://raw.githubusercontent.com/openservicemesh/osm/main/docs/example/manifests/apps/bookstore.yaml
kubectl apply -f https://raw.githubusercontent.com/openservicemesh/osm/main/docs/example/manifests/apps/bookwarehouse.yaml

# Checkpoint: What Got Installed?
kubectl get svc --all-namespaces
kubectl get deployment --all-namespaces

# port forward UI apps
# bookThiefPod="$(kubectl get pods --selector app=bookthief -n "$bookthiefNameSpace" --no-headers | grep 'Running' | awk 'NR==1{print $1}')"
# kubectl port-forward "$bookThiefPod" -n "$bookthiefNameSpace" "$bookThiefLocalPort":14001

# bookBuyerPod="$(kubectl get pods --selector app=bookthief -n "$bookbuyerNameSpace" --no-headers | grep 'Running' | awk 'NR==1{print $1}')"
# kubectl port-forward "$bookBuyerPod" -n "$bookbuyerNameSpace" "$bookBuyerLocalPort":14001

# bookStorePod="$(kubectl get pods --selector app=bookthief -n "$bookStoreNameSpace" --no-headers | grep 'Running' | awk 'NR==1{print $1}')"
# kubectl port-forward "$bookStorePod" -n "$bookStoreNameSpace" "$bookStoreLocalPort":14001
