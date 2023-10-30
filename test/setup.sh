#!/usr/bin/env bash
set -aeuo pipefail

echo "Running setup.sh"
echo "Installing transient Configuration dependencies"
cat <<EOF | "${KUBECTL}" apply -f -
---
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: cofiguration-aws-database
spec:
  package: xpkg.upbound.io/upbound/configuration-aws-database:v0.1.0
---
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: cofiguration-aws-eks
spec:
  package: xpkg.upbound.io/upbound/configuration-aws-eks:v0.1.0
EOF

echo "Waiting until all configurations are healthy/installed..."
"${KUBECTL}" wait configuration.pkg --all --for=condition=Healthy --timeout 5m
"${KUBECTL}" wait configuration.pkg --all --for=condition=Installed --timeout 5m

echo "Creating cloud credential secret..."
"${KUBECTL}" -n upbound-system create secret generic aws-creds --from-literal=credentials="${UPTEST_CLOUD_CREDENTIALS}" \
    --dry-run=client -o yaml | "${KUBECTL}" apply -f -

echo "Waiting until all installed provider packages are healthy..."
"${KUBECTL}" wait provider.pkg --all --for condition=Healthy --timeout 5m

echo "Waiting for all pods to come online..."
"${KUBECTL}" -n upbound-system wait --for=condition=Available deployment --all --timeout=5m

echo "Waiting for all XRDs to be established..."
"${KUBECTL}" wait xrd --all --for condition=Established

echo "Creating a default provider config..."
cat <<EOF | "${KUBECTL}" apply -f -
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    secretRef:
      key: credentials
      name: aws-creds
      namespace: upbound-system
    source: Secret
EOF
