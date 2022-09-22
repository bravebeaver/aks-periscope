module github.com/Azure/aks-periscope

// 1.16 required for go:embed (used for testing resources)
go 1.16

require (
	github.com/Azure/azure-storage-blob-go v0.14.0
	github.com/Azure/go-autorest/autorest/adal v0.9.14 // indirect
	github.com/docker/docker v20.10.14+incompatible
	github.com/google/uuid v1.2.0
	github.com/hashicorp/go-multierror v1.1.1
	helm.sh/helm/v3 v3.6.3
	k8s.io/api v0.22.3
	k8s.io/apimachinery v0.22.3
	k8s.io/cli-runtime v0.21.3
	k8s.io/client-go v0.22.3
	k8s.io/kubectl v0.21.0
	k8s.io/metrics v0.21.0
	rsc.io/letsencrypt v0.0.3 // indirect
)
