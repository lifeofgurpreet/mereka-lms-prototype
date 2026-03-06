# RKE2 unblock snapshot 20260219T2023
## 2026-02-19T20:23:39Z rke2 unblock snapshot
## apps in argocd
NAME                           SYNC STATUS   HEALTH STATUS
argocd-config-dev              Synced        Healthy
authentik-local                OutOfSync     Missing
bbi-applicationsets-dev        Synced        Healthy
calcom-staging-rke2            Synced        Healthy
cert-manager-dev-rke2          Synced        Healthy
cie-dev                        Unknown       Healthy
cie-staging                    Unknown       Healthy
external-secrets-dev-rke2      Synced        Healthy
ingress-nginx-dev-rke2         OutOfSync     Healthy
kyverno-dev-rke2               Synced        Healthy
kyverno-local                  OutOfSync     Healthy
listmonk-staging-rke2          Synced        Healthy
mereka-admin-dev               OutOfSync     Healthy
mereka-admin-staging-rke2      Synced        Healthy
mereka-app-dev                 OutOfSync     Healthy
mereka-app-staging-rke2        Synced        Healthy
mereka-auth-dev                OutOfSync     Healthy
mereka-auth-staging-rke2       Synced        Healthy
mereka-backend-dev             OutOfSync     Healthy
mereka-backend-staging-rke2    Synced        Healthy
mereka-checkout-dev            OutOfSync     Healthy
mereka-checkout-staging-rke2   Synced        Healthy
mereka-dev-bootstrap-rke2      Synced        Healthy
mereka-lms-local               Unknown       Healthy
mereka-web-dev                 OutOfSync     Healthy
mereka-web-staging-rke2        Synced        Healthy
metrics-server-dev-rke2        Synced        Healthy
monitoring-crds-dev-rke2       Unknown       Healthy
monitoring-dev-rke2            Synced        Healthy
n8n-staging-rke2               Synced        Healthy
nonprod-guardrails-dev-rke2    Synced        Healthy
twentycrm-staging-rke2         Synced        Healthy
velero-dev-rke2                Synced        Healthy
zoom-rtms-dev                  Synced        Degraded
zoom-rtms-staging              Synced        Degraded
## describe argocd app
Name:         mereka-lms-local
Namespace:    argocd
Labels:       app=mereka-lms
              deployment-type=kustomize
              env=local
Annotations:  argocd.argoproj.io/manifest-generate-paths: apps/mereka-lms/overlays/profiles/dev;apps/mereka-lms/base
API Version:  argoproj.io/v1alpha1
Kind:         Application
Metadata:
  Creation Timestamp:  2026-02-19T13:37:49Z
  Finalizers:
    resources-finalizer.argocd.argoproj.io
  Generation:  162
  Owner References:
    API Version:           argoproj.io/v1alpha1
    Block Owner Deletion:  true
    Controller:            true
    Kind:                  ApplicationSet
    Name:                  bbi-kustomize-apps
    UID:                   f904bb08-abbb-4eaa-a69c-001446dc11bc
  Resource Version:        1368289
  UID:                     5a33fdf0-9c40-4917-855b-a6faf282430c
Spec:
  Destination:
    Namespace:  mereka-lms
    Server:     https://kubernetes.default.svc
  Ignore Differences:
    Json Pointers:
      /spec/storageClassName
      /spec/volumeName
      /spec/volumeMode
      /status
    Kind:   PersistentVolumeClaim
    Group:  networking.k8s.io
    Json Pointers:
      /metadata/annotations
    Kind:   Ingress
    Group:  apps
    Json Pointers:
      /spec/replicas
    Kind:   Deployment
  Project:  default
  Source:
    Path:             apps/mereka-lms/overlays/profiles/dev
    Repo URL:         https://github.com/Biji-Biji-Initiative/bbi-infrastructure.git
    Target Revision:  main
  Sync Policy:
    Automated:
      Prune:      true
      Self Heal:  true
    Retry:
      Backoff:
        Duration:      10s
        Factor:        2
        Max Duration:  5m
      Limit:           5
    Sync Options:
      CreateNamespace=true
      RespectIgnoreDifferences=true
      ServerSideApply=true
      ApplyOutOfSyncOnly=true
Status:
  Conditions:
    Last Transition Time:  2026-02-19T20:00:37Z
    Message:               Failed to load target state: failed to generate manifest for source 1 of 1: rpc error: code = Unknown desc = Manifest generation error (cached): `kustomize build <path to cached source>/apps/mereka-lms/overlays/profiles/dev --load-restrictor LoadRestrictionsNone` failed exit status 1: # Warning: 'patchesJson6902' is deprecated. Please use 'patches' instead. Run 'kustomize edit fix' to update your Kustomization automatically.
Error: accumulating resources: accumulation err='accumulating resources from '../../local': read <path to cached source>/apps/mereka-lms/overlays/local: is a directory': recursed accumulation of path '<path to cached source>/apps/mereka-lms/overlays/local': accumulating resources: accumulation err='accumulating resources from '../../base': read <path to cached source>/apps/mereka-lms/base: is a directory': recursed accumulation of path '<path to cached source>/apps/mereka-lms/base': accumulating resources: accumulation err='accumulating resources from 'https://github.com/Biji-Biji-Initiative/mereka-lms.git//deploy/k8s/base?ref=main': URL is a git repository': hit 27s timeout running '/usr/bin/git submodule update --init --recursive'
    Type:                ComparisonError
  Controller Namespace:  argocd
  Health:
    Last Transition Time:  2026-02-19T13:38:50Z
    Status:                Healthy
  Reconciled At:           2026-02-19T20:22:38Z
  Resource Health Source:  appTree
  Source Hydrator:
  Summary:
  Sync:
    Compared To:
      Destination:
        Namespace:  mereka-lms
        Server:     https://kubernetes.default.svc
      Ignore Differences:
        Json Pointers:
          /spec/storageClassName
          /spec/volumeName
          /spec/volumeMode
          /status
        Kind:   PersistentVolumeClaim
        Group:  networking.k8s.io
        Json Pointers:
          /metadata/annotations
        Kind:   Ingress
        Group:  apps
        Json Pointers:
          /spec/replicas
        Kind:  Deployment
      Source:
        Path:             apps/mereka-lms/overlays/profiles/dev
        Repo URL:         https://github.com/Biji-Biji-Initiative/bbi-infrastructure.git
        Target Revision:  main
    Revision:             main
    Status:               Unknown
Events:                   <none>
## externalsecret namespace
## pods namespace
## errors
No resources found in mereka-lms namespace.
No resources found in mereka-lms namespace.
## repo-server connectivity
Defaulted container "argocd-repo-server" out of: argocd-repo-server, copyutil (init)
fatal: could not read Username for 'https://github.com': No such device or address
command terminated with exit code 128
