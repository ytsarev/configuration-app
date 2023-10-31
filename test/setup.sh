#!/usr/bin/env bash
set -aeuo pipefail

echo "Running setup.sh"

echo "Waiting until all configurations are healthy/installed..."
"${KUBECTL}" wait configuration.pkg --all --for=condition=Healthy --timeout 5m
"${KUBECTL}" wait configuration.pkg --all --for=condition=Installed --timeout 5m

echo "Waiting until all installed provider packages are healthy..."
"${KUBECTL}" wait provider.pkg --all --for condition=Healthy --timeout 5m

echo "Waiting for all pods to come online..."
"${KUBECTL}" -n upbound-system wait --for=condition=Available deployment --all --timeout=5m

echo "Waiting for all XRDs to be established..."
"${KUBECTL}" wait xrd --all --for condition=Established

echo "Setting up helm provider config pointing to the local cluster..."
SA=$("${KUBECTL}" -n upbound-system get sa -o name | grep provider-helm | sed -e 's|serviceaccount\/|upbound-system:|g')
"${KUBECTL}" create clusterrolebinding provider-helm-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}"
cat <<EOF | "${KUBECTL}" apply -f -
apiVersion: helm.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: uptest
spec:
  credentials:
    source: InjectedIdentity
EOF

echo "Setting up fake mariadb connection secret..."
cat <<EOF | "${KUBECTL}" apply -f -
apiVersion: v1
data:
  endpoint: Y29uZmlndXJhdGlvbi1hcHAtZGF0YWJhc2UtbWFyaWFkYi1xdGNnbS1xNXMyNC5jeGFsMWxvbXpuYmEudXMtd2VzdC0yLnJkcy5hbWF6b25hd3MuY29tOjMzMDY=
  host: Y29uZmlndXJhdGlvbi1hcHAtZGF0YWJhc2UtbWFyaWFkYi1xdGNnbS1xNXMyNC5jeGFsMWxvbXpuYmEudXMtd2VzdC0yLnJkcy5hbWF6b25hd3MuY29t
  password: b3hIbzZZOTZQMDJHWERwMm9kejZDYTcyREY2
  username: bWFzdGVydXNlcg==
kind: Secret
metadata:
  name: configuration-app-mariadb
  namespace: default
EOF
