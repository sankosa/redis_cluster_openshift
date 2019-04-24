#!/bin/bash

set -e

echo "BUILD_VERSION: $BUILD_VERSION"
echo "BUILD_COMMIT: $OPENSHIFT_BUILD_COMMIT"
echo "BUILD_REFERENCE: $OPENSHIFT_BUILD_REFERENCE"

export PORT=6379
export CLUSTER_NAME=${CLUSTER_NAME:-cluster}
export MASTER_IP=$(redis-cli -h sentinel-${CLUSTER_NAME} -p 26379 SENTINEL get-master-addr-by-name redis-cluster | sed 's,\r$,,' | head -n 1)
export MY_IP=$(awk 'END{print $1}' /etc/hosts)
function launchexporter() {
    exec /opt/redis-exporter/redis_exporter -redis.addr redis://${HOSTNAME}:6379
}

function launchnode() {
    CFG=/redis-conf/redis.conf

    if [ -r /redis-conf/redis.conf ];then
        echo "Using redis.conf from configmap"
    else
        echo “Copy redis.conf from templates”
        cp /redis-templates/redis.conf /redis-conf/
        if [[ "${DISABLE_AUTO_SAVE}" == "true" ]]; then
          echo "disable autosaving"
          sed -i -e '/^save/s/^#*/#/' /redis-conf/redis.conf
        fi
    fi

    # check if redis sentinel is alive
    redis-cli --raw -h sentinel-${CLUSTER_NAME:-cluster} -p 26379 SENTINEL masters
    if [ $? -gt 0 ];then
        exit 1
    fi

    # self healing if we are node 1 and master is down
    if [ "${REDIS_NODE}" == "1" ];then
        MASTER_STATUS=$(redis-cli --raw -h sentinel-${CLUSTER_NAME:-cluster} -p 26379 SENTINEL master redis-cluster | grep -A1 flags | grep master | tr -d '[:space:]')
        if [ "${MASTER_STATUS}" != "master" ];then
            /peer-finder -service=sentinel-${CLUSTER_NAME:-cluster}
            PEERS=$(cat /tmp/peers)
                for PEER in $PEERS
                do
                    if [[ "${PEER}" == *"${HOSTNAME}"* ]]; then
                        echo "ignore self"
                    else
                        echo "handle ${PEER}"
                        redis-cli -h ${PEER} -p 26379 SENTINEL REMOVE redis-cluster
                        CLUSTER_NAME_VAR=$(echo ${CLUSTER_NAME:-cluster} | sed 's/-/_/g')
                        REDIS_ENV_KEY=$(echo "REDIS_${CLUSTER_NAME_VAR}_NODE${REDIS_NODE}_SERVICE_HOST" |  tr "[:lower:]" "[:upper:]")

                        echo "monitor ${!REDIS_ENV_KEY}"
                        redis-cli -h ${PEER} -p 26379 SENTINEL MONITOR redis-cluster ${!REDIS_ENV_KEY} ${PORT} ${QUORUM}
                    fi
                done

            export MASTER_IP=$(redis-cli -h sentinel-${CLUSTER_NAME} -p 26379 SENTINEL get-master-addr-by-name redis-cluster | sed 's,\r$,,' | head -n 1)
        fi
    fi

    python /redis_pre_run.py
    CLUSTER_NAME_VAR=$(echo ${CLUSTER_NAME:-cluster} | sed 's/-/_/g')
    REDIS_ENV_KEY=$(echo "REDIS_${CLUSTER_NAME_VAR}_NODE${REDIS_NODE}_SERVICE_HOST" |  tr "[:lower:]" "[:upper:]")
    echo "slave-announce-ip ${!REDIS_ENV_KEY}" >> ${CFG}
    exec redis-server ${CFG} --protected-mode no
}

function launchsentinel() {
    CFG=/redis-conf/sentinel.conf

    python /sentinel_pre_run.py

    cat /redis-templates/sentinel.conf >> ${CFG}

    exec redis-sentinel ${CFG} --protected-mode no
}

if [[  "${RECOVERY_MODE}" == "true" ]]; then
   echo "Running in Recovery Mode."
   while true; do sleep 1000; done
elif [[ "${SENTINEL}" == "true" ]]; then
  launchsentinel
elif [[ "${EXPORTER}" == "true" ]]; then
  launchexporter
else
  launchnode
fi
