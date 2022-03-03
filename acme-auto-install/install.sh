read -p "Which namespace to install into " ACME_NAMESPACE
read -p "Value for Secrets? " ACME_SECRET

kubectl -n ${ACME_NAMESPACE} create secret generic cart-redis-pass --from-literal=password=${ACME_SECRET}
kubectl -n ${ACME_NAMESPACE} apply -f yaml/cart-redis-total.yaml
kubectl -n ${ACME_NAMESPACE} apply -f yaml/cart-total.yaml
kubectl -n ${ACME_NAMESPACE} create secret generic catalog-mongo-pass --from-literal=password=${ACME_SECRET}
kubectl -n ${ACME_NAMESPACE} create -f yaml/catalog-db-initdb-configmap.yaml
kubectl -n ${ACME_NAMESPACE} apply -f yaml/catalog-db-total.yaml
kubectl -n ${ACME_NAMESPACE} apply -f yaml/catalog-total.yaml
kubectl -n ${ACME_NAMESPACE} apply -f yaml/payment-total.yaml
kubectl -n ${ACME_NAMESPACE} create secret generic order-postgres-pass --from-literal=password=${ACME_SECRET}
kubectl -n ${ACME_NAMESPACE} apply -f yaml/order-db-total.yaml
kubectl -n ${ACME_NAMESPACE} apply -f yaml/order-total.yaml
kubectl -n ${ACME_NAMESPACE} create secret generic users-mongo-pass --from-literal=password=${ACME_SECRET}
kubectl -n ${ACME_NAMESPACE} create secret generic users-redis-pass --from-literal=password=${ACME_SECRET}
kubectl -n ${ACME_NAMESPACE} create -f yaml/users-db-initdb-configmap.yaml
kubectl -n ${ACME_NAMESPACE} apply -f yaml/users-db-total.yaml
kubectl -n ${ACME_NAMESPACE} apply -f yaml/users-redis-total.yaml
kubectl -n ${ACME_NAMESPACE} apply -f yaml/users-total.yaml
kubectl -n ${ACME_NAMESPACE} apply -f yaml/frontend-total.yaml
kubectl -n ${ACME_NAMESPACE} apply -f yaml/point-of-sales-total.yaml
