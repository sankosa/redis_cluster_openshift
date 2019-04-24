#! /usr/bin/env python

import sys, re, os, logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("redis_pre_run")

master = ""
if len(sys.argv) > 1:
    master = sys.argv[1]

filename = "/redis-conf/redis.conf"

# opening file in append mode in order to add servers connection configuration
f = open(filename, "a");

cluster_name = os.environ["CLUSTER_NAME"].upper()
pod_namespace = os.environ["POD_NAMESPACE"]
master_ip = os.environ["MASTER_IP"]
my_ip = os.environ["MY_IP"]

for key in os.environ.keys():
    matchobj = re.match("REDIS_"+cluster_name.replace("-", "_")+"_NODE([0-9]*)_SERVICE_HOST", key, re.M|re.I)
    if matchobj:
        # env variable name REDIS_<cluster_name>_NODE<serverid>_SERVICE_HOST
        envhost = matchobj.group()
        # get the serverid
        serverid = matchobj.group(1)
        
        if serverid:
            logger.info("%s = %s", key, os.environ[key])
            
            if str(serverid) == os.environ['REDIS_NODE'] and str(serverid) == "1":
                if master_ip.strip() != "" and master_ip.strip() != os.environ[key].strip():
                    line = "slaveof {0} {1}\n".format(master_ip, "6379")
                else:
                    # for the master, the configuration needs to be 0.0.0.0
                    line = "bind 0.0.0.0\n"
            elif str(serverid) == "1":
                # otherwise the master specific service address
                master_name = "redis-{0}-node1.{1}.svc".format(cluster_name, pod_namespace)
                line = "slaveof {0} {1}\n".format(master_name, "6379")
            else:
                line=""
                
            logger.info("write line %s", line)    
            f.write(line)     
        
f.close()
