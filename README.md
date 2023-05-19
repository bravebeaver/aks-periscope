# AKS Periscope

[![CI](https://github.com/Azure/aks-periscope/actions/workflows/ci-pipeline.yaml/badge.svg?branch=master)](https://github.com/Azure/aks-periscope/actions/workflows/ci-pipeline.yaml)
[![codecov](https://codecov.io/gh/Azure/aks-periscope/branch/master/graph/badge.svg)](https://codecov.io/gh/Azure/aks-periscope)
[![GoDoc](https://godoc.org/github.com/Azure/aks-periscope?status.svg)](https://godoc.org/github.com/Azure/aks-periscope)
[![Go Report Card](https://goreportcard.com/badge/github.com/Azure/aks-periscope)](https://goreportcard.com/report/github.com/Azure/aks-periscope)
[![CodeQL](https://github.com/Azure/aks-periscope/actions/workflows/codeql-analysis.yml/badge.svg?branch=master)](https://github.com/Azure/aks-periscope/actions/workflows/codeql-analysis.yml)

Quick troubleshooting for your Azure Kubernetes Service (AKS) cluster.

![Icon](https://user-images.githubusercontent.com/33297523/69174241-4075a980-0ab6-11ea-9e33-76afc588e7fb.png)

## Table of contents

1. [Overview](#overview)
2. [Data Privacy and Collection](#data-privacy-and-collection)
3. [Compatibility](#compatibility)
4. [Current Feature Set](#current-feature-set)
5. [User Guide](#user-guide)
   1. [Prerequisites](#prerequisites)
   1. [Raw Kustomize](#kustomize-deployment)
   1. [Azure CLI Kollect Command](#using-azure-command-line-tool)
   1. [VS Code AKS Extension](#using-vs-code-aks-extension)
6. [Programming Guide](#programming-guide)
   1. [Automated Tests](#automated-tests)
7. [Dependent Consuming Tools and Working Contract](#dependent-consuming-tools-and-working-contract)
8. [Debugging Guide](#debugging-guide)
9. [Contributing](#contributing)

## Overview

Hopefully most of the time, your AKS cluster is running happily and healthy. However, when things do go wrong, AKS customers need a tool to help them diagnose and collect the logs necessary to troubleshoot the issue. It can be difficult to collect the appropriate node and pod logs to figure what's wrong, how to fix the problem, or even to pass on those logs to others to help.

AKS Periscope allows AKS customers to run initial diagnostics and collect and export the logs (such as into an Azure Blob storage account) to help them analyze and identify potential problems or easily share the information to support to help with the troubleshooting process with a simple az aks kollect command. These cluster issues are often caused by incorrect cluster configuration, such as networking or permission issues. This tool will allow AKS customers to run initial diagnostics and collect logs and custom analyses that helps them identify the underlying problems.

![Architecture](https://user-images.githubusercontent.com/33297523/64900285-f5b65c00-d644-11e9-9a52-c4345d1b1861.png)

Raw Logs and metrics from an AKS cluster are collected and basic diagnostic signals are generated by analyzing these raw data.

## Data Privacy and Collection

AKS Periscope runs on customer's agent pool nodes and collects VM and container level data. It is important that the customer is aware and gives consent before the tool is deployed/information shared. Microsoft guidelines can be found in the link below:

https://azure.microsoft.com/en-us/support/legal/support-diagnostic-information-collection/

## Compatibility

AKS Periscope can run on both Linux and Windows nodes, but there are some [functional differences between Windows and Linux behaviour](./docs/windows-vs-linux.md).

## Current Feature Set

Periscope collects the following logs and metrics:

1. Container logs (by default all containers in the `kube-system` namespace. Can be configured to take other namespace/containers).
2. Docker and Kubelet system service logs.
3. Network outbound connectivity, include checks for internet, API server, Tunnel, Azure Container Registry and Microsoft Container Registry.
4. Node IP Tables.
5. All node level logs (by default cluster provision log and cloud init log. Can be configured to take other logs).
6. VM and Kubernetes cluster level DNS settings.
7. Describe Kubernetes objects (by default all pods/services/deployments in the `kube-system` namespace. Can be configured to take other namespace/objects).
8. Kubelet command arguments.
9. System performance (kubectl top nodes and kubectl top pods).

## User Guide

You can deploy Periscope to your cluster in different ways, depending on your preferred working environment and the degree of control over precisely how it needs to be run.

### Prerequisites

Whichever method you choose to deploy Periscope, you will need to have [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) **version 1.21** or later installed on your system.

### Kustomize Deployment

This approach gives you the most control, allowing you to inspect and override the configuration of all Kubernetes resources deployed to your cluster, as well as choosing a specific release.

The [`Kustomize`](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/) tool deploys resources defined in a directory containing a `kustomization.yaml` file. To deploy Periscope, a minimal file might look like this:

```yaml
resources:
- https://github.com/azure/aks-periscope//deployment/base?ref=<RELEASE_TAG>

# Optional feature components, uncomment if applicable:
# - win-hpc: only useful if the cluster contains Windows nodes
# components:
# - https://github.com/Azure/aks-periscope//deployment/components/win-hpc?ref=<RELEASE_TAG>

images:
- name: periscope-linux
  newName: mcr.microsoft.com/aks/periscope
  newTag: <IMAGE_TAG>
- name: periscope-windows
  newName: mcr.microsoft.com/aks/periscope
  newTag: <IMAGE_TAG>

secretGenerator:
- name: azureblob-secret
  behavior: replace
  literals:
  - AZURE_BLOB_ACCOUNT_NAME=<STORAGE_ACCOUNT_NAME>
  - AZURE_BLOB_CONTAINER_NAME=<CONTAINER_NAME>
  - AZURE_BLOB_SAS_KEY=<SAS_KEY>

# Commented-out config values are the defaults. Uncomment to change.
configMapGenerator:
- name: diagnostic-config
  behavior: merge
  literals:
  - DIAGNOSTIC_RUN_ID=<RUN_ID>
  # - DIAGNOSTIC_CONTAINERLOGS_LIST=kube-system # space-separated namespaces
  # - DIAGNOSTIC_KUBEOBJECTS_LIST=kube-system/pod kube-system/service kube-system/deployment # space-separated list of namespace/resource-type[/resource]
  # - DIAGNOSTIC_NODELOGS_LIST_LINUX="/var/log/azure/cluster-provision.log /var/log/cloud-init.log" # space-separated log file locations
  # - DIAGNOSTIC_NODELOGS_LIST_WINDOWS="C:\AzureData\CustomDataSetupScript.log" # space-separated log file locations
  # - COLLECTOR_LIST="" # space-separated list containing any of 'connectedCluster' (enables helm/pods-containerlogs, disables iptables/kubelet/nodelogs/pdb/systemlogs/systemperf), 'OSM' (enables osm/smi), 'SMI' (enables smi).
```

All placeholders in angled brackets (`<`/`>`) need to be substituted for the relevant values:

- `RELEASE_TAG`: The [Periscope release](https://github.com/Azure/aks-periscope/tags) to use.
- `IMAGE_TAG`: The [Docker image tag](https://mcr.microsoft.com/en-us/product/aks/periscope/tags) to use.
- `STORAGE_ACCOUNT_NAME`: The Azure storage account for Periscope to upload diagnostics to.
- `CONTAINER_NAME`: The blob container within the storage account for Periscope to upload diagnostics to.
- `SAS_KEY`: An [Account SAS](https://docs.microsoft.com/en-us/azure/storage/common/storage-sas-overview#account-sas) including preceding `?` with [parameters](https://docs.microsoft.com/en-us/rest/api/storageservices/create-account-sas#specify-the-account-sas-parameters):
  - `ss`: `b` (Service: blob)
  - `srt`: `sco` (Resource types: service, container and object)
  - `sp`: `rlacw` (Permissions: read, list, add, create, write)
- `RUN_ID`: The identifier for a particular 'run' of Periscope, by convention a timestamp formatted as `YYYY-MM-DDThh-mm-ssZ`. This will become the topmost container within `CONTAINER_NAME`.

You can then deploy Periscope by running:

```sh
kubectl apply -k <path-to-kustomize-directory>
```

To re-run without deleting and recreating resources, you can update the `RUN_ID` value in the ConfigMap. Depending on the expiry of the SAS token, you may need to update the `AZURE_BLOB_SAS_KEY` value in the Secret first:

```sh
# Update SAS token (if expired)
sas=...
kubectl patch secret -n aks-periscope azureblob-secret -p="{\"data\":{\"AZURE_BLOB_SAS_KEY\": \"$(echo -n ?$sas | base64 -w 0)\"}}"

# Update DIAGNOSTIC_RUN_ID
runId=$(date -u '+%Y-%m-%dT%H-%M-%SZ')
kubectl patch configmap -n aks-periscope diagnostic-config -p="{\"data\":{\"DIAGNOSTIC_RUN_ID\": \"$runId\"}}"
```

### Using Azure Command-Line tool

AKS Periscope can be deployed by using Azure Command-Line tool (CLI). The steps are:

0. If CLI extension aks-preview has been installed previously, uninstall it first.

   ```sh
   az extension remove --name aks-preview
   ```

1. Install CLI extension aks-preview.

   ```sh
   az extension add --name aks-preview
   ```

2. Run `az aks kollect` command to collect metrics and diagnostic information, and upload to an Azure storage account. Use `az aks kollect -h` to check command details. Some useful examples are also listed below:

   1. Using storage account name and a shared access signature token with write permission

      ```sh
      az aks kollect \
      -g MyResourceGroup \
      -n MyManagedCluster \
      --storage-account MyStorageAccount \
      --sas-token "MySasToken"
      ```

   2. Using the resource id of a storage account resource you own.

      ```sh
      az aks kollect \
      -g MyResourceGroup \
      -n MyManagedCluster \
      --storage-account "MyStorageAccountResourceId"
      ```

   3. Using a [pre-setup storage account](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/diagnostic-logs-stream-log-store) in diagnostics settings for your managed cluster.

      ```sh
      az aks kollect \
      -g MyResourceGroup \
      -n MyManagedCluster
      ```

   4. Customize the container logs to collect. Its value can be either all containers in a namespace, for example, kube-system, or a specific container in a namespace, for example, kube-system/tunnelfront.

      ```sh
      az aks kollect \
      -g MyResourceGroup \
      -n MyManagedCluster \
      --container-logs "mynamespace1/mypod1 myns2"
      ```

   5. Customize the kubernetes objects to collect. Its value can be either all objects of a type in a namespace, for example, kube-system/pod, or a specific object of a type in a namespace, for example, kube-system/deployment/tunnelfront.

      ```sh
      az aks kollect \
      -g MyResourceGroup \
      -n MyManagedCluster \
      --kube-objects "mynamespace1/service myns2/deployment/deployment1"
      ```

   6. Customize the node log files to collect.

      ```sh
      az aks kollect \
      -g MyResourceGroup \
      -n MyManagedCluster \
      --node-logs "/var/log/azure-vnet.log /var/log/azure-vnet-ipam.log"
      ```

After export, they will also be stored in Azure Blob Storage in a container named with the cluster's API Server FQDN. A zip file is also created for easy download.

### Using VS Code AKS Extension

AKS Periscope can also be deployed by using the [VS Code AKS extension](https://marketplace.visualstudio.com/items?itemName=ms-kubernetes-tools.vscode-aks-tools).

You first need to configure your cluster's diagnostic settings to use a storage account [as explained here](https://github.com/Azure/vscode-aks-tools#configuring-storage-account). You can then right-click on the cluster and select `Run AKS Periscope` to run the tool and upload the result. The results can be downloaded directly from VS Code. For more detail how this feature works [please refer here](https://github.com/Azure/vscode-aks-tools#aks-periscope).

## Programming Guide

To locally build this project from the root of this repository:

```sh
CGO_ENABLED=0 GOOS=linux go build -mod=mod github.com/Azure/aks-periscope/cmd/aks-periscope
```

### Automated Tests

See [this guide](./docs/testing.md) for running automated tests in a CI or development environment.

### Manual Testing

You can build and run Periscope locally in a `Kind` cluster using the ['dev' Kustomize overlay notes](./deployment/overlays/dev/README.md).

To build and push a Docker image to an external registry (GHCR or ACR), and then deploy that to any (local or cloud-hosted) cluster, please refer to the ['dynamic-image' Kustomize overlay notes](./deployment/overlays/dynamic-image/README.md#ghcr).

## Dependent Consuming Tools and Working Contract

Dependent tools need access to an immutable, versioned Periscope resource definition. We provide two ways to obtain this:

1. [Deprecated] Build the `external` overlay using instructions [here](./deployment/overlays/external/README.md) and include the output as a static resource in consuming tools. This will require runtime string substitution to configure appropriately for any given deployment, before being deployed using `kubectl -f`.
2. Build a `Kustomize` overlay at runtime, referencing `https://github.com/azure/aks-periscope//deployment/base?ref={RELEASE_TAG}` as the base, and the appropriate MCR image tags for that release, as well as all configuration and secrets. This can then be deployed using `kubectl -k`. Example:

```yaml
resources:
- https://github.com/azure/aks-periscope//deployment/base?ref={RELEASE_TAG}
images:
- name: periscope
  newName: mcr.microsoft.com/aks/periscope
  newTag: "{IMAGE_TAG}"
secretGenerator:
- name: azureblob-secret
  behavior: replace
  literals:
  - AZURE_BLOB_ACCOUNT_NAME={STG_ACCOUNT}
  - AZURE_BLOB_SAS_KEY=?{STG_SAS}
  - AZURE_BLOB_CONTAINER_NAME={STG_CONTAINER}
configMapGenerator:
- name: diagnostic-config
  behavior: merge
  literals:
  # Only specify those which should be overridden
  - DIAGNOSTIC_KUBEOBJECTS_LIST={KUBEOBJECTS_OVERRIDE}
```

## Debugging Guide

This section intends to add some tips for debugging pod logs using aks-periscope.

Scenario, where `user A` uses **expired** `sas-token` and converts into `base64` to be used in the deployment file.

In the scenario above, the `kubectl apply -k ./deployment/overlays/dev` will show no error but the output which will look like the one below.

```sh
❯ kubectl apply -k ./deployment/overlays/dev
namespace/aks-periscope created
serviceaccount/aks-periscope-service-account created
clusterrole.rbac.authorization.k8s.io/aks-periscope-role unchanged
clusterrolebinding.rbac.authorization.k8s.io/aks-periscope-role-binding unchanged
clusterrolebinding.rbac.authorization.k8s.io/aks-periscope-role-binding-view unchanged
daemonset.apps/aks-periscope created
secret/azureblob-secret created
configmap/diagnostic-config created
customresourcedefinition.apiextensions.k8s.io/diagnostics.aks-periscope.azure.github.com unchanged
```

To debug the `pod` logs in the `aks-periscope-dev` namespace deployed in the cluster:

- To get the pods in `aks-periscope-dev` namespace: `kubectl get pods -n aks-periscope-dev`
- To check the logs in each of the deployed pods: `kubectl logs <name-of-pod> -n aks-periscope-dev`

Feel free to contact aksperiscope@microsoft.com or open an issue with any feedback or questions about AKS Periscope. This is currently a work in progress, but look out for more capabilities to come!

## Contributing

This project welcomes contributions and suggestions. Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

[programming guide](docs/programmingguide.md): docs/programmingguide.md
[appendix](docs/appendix.md): docs/appendix.md
