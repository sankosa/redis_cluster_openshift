#! /usr/bin/env python

import re, os, logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("redis_pre_run")

master_ip = os.environ["MASTER_IP"]
filename = "/redis-conf/sentinel.conf"
cluster_name = os.environ["CLUSTER_NAME"].upper()
quorum = os.environ["QUORUM"]
pod_namespace = os.environ["POD_NAMESPACE"]

# opening file in append mode in order to add servers connection configuration
f = open(filename, "a");

for key in os.environ.keys():
    matchobj = re.match("REDIS_"+cluster_name.replace("-", "_")+"_NODE([0-9]*)_SERVICE_HOST", key, re.M|re.I)
    if matchobj:
        # env variable name REDIS_<cluster_name>_NODE<serverid>_SERVICE_HOST
        envhost = matchobj.group()
        # get the serverid
        serverid = matchobj.group(1)
        
        if serverid:
            logger.info("%s = %s", key, os.environ[key])
            
            if str(serverid) == "1":
                master_name = "redis-{0}-node1.{1}.svc".format(cluster_name.lower(), pod_namespace)
                line = "sentinel monitor redis-cluster {0} {1} {2}\n".format(master_name, "6379", quorum)
            else:
                line=""
                
            logger.info("write line %s", line)    
            f.write(line)     
        
f.close()
