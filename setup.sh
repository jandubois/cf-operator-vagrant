server=http://127.0.0.1:8080
name=$(kubectl get sa --namespace kube-system default -o json | jq -r .secrets[0].name)

ca=$(kubectl get secret/$name --namespace kube-system -o jsonpath='{.data.ca\.crt}')
token=$(kubectl get secret/$name --namespace kube-system -o jsonpath='{.data.token}' | base64 -d)
namespace=$(kubectl get secret/$name --namespace kube-system -o jsonpath='{.data.namespace}' | base64 -d)

echo "
apiVersion: v1
kind: Config
clusters:
- name: default-cluster
  cluster:
    certificate-authority-data: ${ca}
    server: ${server}
contexts:
- name: default-context
  context:
    cluster: default-cluster
    namespace: default
    user: default-user
current-context: default-context
users:
- name: default-user
  user:
    token: ${token}
" > ~/.kube/config
