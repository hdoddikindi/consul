#!/bin/sh
KUBE_TOKEN=`cat /var/run/secrets/kubernetes.io/serviceaccount/token`
NAMESPACE=`cat /var/run/secrets/kubernetes.io/serviceaccount/namespace`

CONSUL_SERVER_COUNT=${CONSUL_SERVER_COUNT:-3}
CONSUL_HTTP_PORT=${CONSUL_HTTP_PORT:-8500}
CONSUL_HTTPS_PORT=${CONSUL_HTTPS_PORT:-8243}
CONSUL_DNS_PORT=${CONSUL_DNS_PORT:-53}
CONSUL_SERVICE_HOST=${CONSUL_SERVICE_HOST:-"127.0.0.1"}
CONSUL_WEB_UI_ENABLE=${CONSUL_WEB_UI_ENABLE:-"true"}
CONSUL_SSL_ENABLE=${CONSUL_SSL_ENABLE:-"false"}

if [ ${CONSUL_SSL_ENABLE} == "true" ]; then
  if [ ! -z ${CONSUL_SSL_KEY} ] &&  [ ! -z ${CONSUL_SSL_CRT} ]; then
    echo ${CONSUL_SSL_KEY} > /etc/consul/ssl/consul.key
    echo ${CONSUL_SSL_CRT} > /etc/consul/ssl/consul.crt
  else
    openssl req -x509 -newkey rsa:2048 -nodes -keyout /etc/consul/ssl/consul.key -out /etc/consul/ssl/consul.crt -days 365 -subj "/CN=consul.kube-system.svc.cluster.local"
  fi
fi

export CONSUL_IP=`hostname -i`

if [ -z ${ENVIRONMENT} ] || [ -z ${MASTER_TOKEN} ] || [ -z ${GOSSIP_KEY} ]; then
  echo "Error: ENVIRONMENT, MASTER_TOKEN and GOSSIP_KEY environment vars must be set"
  exit 1
fi

LIST_IPS=`curl -sSk -H "Authorization: Bearer $KUBE_TOKEN" https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT/api/v1/namespaces/$NAMESPACE/pods | jq '.items[] | select(.status.containerStatuses[].name=="consul") | .status .podIP'`

echo "$LIST_IPS"

#basic test to see if we have ${CONSUL_SERVER_COUNT} number of containers alive
VALUE='0'

while [ $VALUE != ${CONSUL_SERVER_COUNT} ]; do
  echo "waiting 10s on all the consul containers to spin up"
  sleep 10
  LIST_IPS=`curl -sSk -H "Authorization: Bearer $KUBE_TOKEN" https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT/api/v1/namespaces/$NAMESPACE/pods | jq '.items[] | select(.status.containerStatuses[].name=="consul") | .status .podIP'`
  echo "$LIST_IPS"
  echo "$LIST_IPS" | sed -e 's/$/,/' -e '$s/,//' > tester
  VALUE=`cat tester | wc -l`
done

LIST_IPS_FORMATTED=`echo "$LIST_IPS" | sed -e 's/$/,/' -e '$s/,//'`
echo $LIST_IPS_FORMATTED

#sed "s,{{ENVIRONMENT}},${ENVIRONMENT}" -i /etc/consul/config.json
#sed "s,{{MASTER_TOKEN}},${MASTER_TOKEN}" -i /etc/consul/config.json
#sed "s,{{GOSSIP_KEY}},${GOSSIP_KEY}" -i /etc/consul/config.json
#sed "s,{{CONSUL_HTTP_PORT}},${CONSUL_HTTP_PORT}" -i /etc/consul/config.json
#sed "s,{{CONSUL_HTTPS_PORT}},${CONSUL_HTTPS_PORT}" -i /etc/consul/config.json

sed "s|{{LIST_PODIPST}}|$LIST_IPS_FORMATTED|" -i /etc/consul/config.json

cat /etc/consul/config.json

#cmd="consul agent -server -config-dir=/etc/consul -dc ${ENVIRONMENT} -bootstrap-expect ${CONSUL_SERVER_COUNT}"

#if [ ! -z ${CONSUL_DEBUG} ]; then
#  ls -lR /etc/consul
#  cat /etc/consul/config.json
#  echo "${cmd}"
#  sed -i "s,INFO,DEBUG," /etc/consul/config.json
#fi

consul agent -server -config-dir=/etc/consul -dc ${ENVIRONMENT} -bootstrap-expect ${CONSUL_SERVER_COUNT}
