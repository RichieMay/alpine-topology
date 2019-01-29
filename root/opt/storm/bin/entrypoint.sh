#!/bin/sh
ZK_SERVICE=${ZK_SERVICE:-"zookeeper/zk"}
KAFKA_SERVICE=${KAFKA_SERVICE:-"kafka/broker"}
STORM_DATA_DIR=${STORM_DATA_DIR:-${SERVICE_HOME}"/data"}
STORM_NIMBUS_SERVICE=${STORM_NIMBUS_SERVICE:-"storm/nimbus"}

#stack service
get_service_addr()
{
    metadata_url="http://rancher-metadata/latest"
    containers_path=`printf "/stacks/%s/services/%s/containers" $1 $2`
    containers_indexs=`curl -s $metadata_url$containers_path|awk -F '=' '{print $1}'`
    for index in $containers_indexs; do
        ip=`curl -s $metadata_url$containers_path/$index/primary_ip`
        echo $ip
    done
}

#stack service
get_service_containers_name()
{
    metadata_url="http://rancher-metadata/latest"
    containers_path=`printf "/stacks/%s/services/%s/containers" $1 $2`
    containers_name=`curl -s $metadata_url$containers_path|awk -F '=' '{print $2}'`
    echo $containers_name
}

gen_storm_zookeeper_servers()
{
    for zookeeper in $*; do
        echo " - \"$zookeeper\"\n"
    done
}

gen_storm_nimbus_servers()
{
    for nimbus in $*; do
        if [ -z $nimbus_seeds ]; then
            nimbus_seeds="[\"$nimbus\""
        else
            nimbus_seeds=$nimbus_seeds",\"$nimbus\""
        fi
    done
    echo "$nimbus_seeds]"
}

gen_kafka_servers()
{
    kafka_port=9092
    for kafka in $*; do
        if [ -z $kafkas ]; then
            kafkas="$kafka:$kafka_port"
        else
            kafkas=$kafkas",$kafka:$kafka_port"
        fi
    done
    echo "$kafkas"
}

gen_storm_conf() 
{
cat << EOF > ${SERVICE_CONF}
storm.zookeeper.servers: 
 $(echo -e $1)
nimbus.seeds: $2
storm.local.dir: "$STORM_DATA_DIR"
supervisor.slots.ports:
    - 6700
    - 6701
    - 6702
    - 6703
storm.zookeeper.port: 2181
ui.port: 8080
logviewer.port: 8081
worker.childopts: "$JVM_OPTS"
EOF
}

zookeepers=$(get_service_addr $(echo ${ZK_SERVICE//'/'/' '}))
zk_servers=$(gen_storm_zookeeper_servers $zookeepers)

nimbuses_hostname=$(get_service_containers_name $(echo ${STORM_NIMBUS_SERVICE//'/'/' '}))
nimbus_servers=$(gen_storm_nimbus_servers $nimbuses_hostname)

gen_storm_conf "$zk_servers" "$nimbus_servers"

kafka_servers=$(get_service_addr $(echo ${KAFKA_SERVICE//'/'/' '}))
bootstrap_servers=$(gen_kafka_servers $kafka_servers)

case $1 in
    pusher)
        nohup bin/storm jar topology/iot-data-storm-pusher-1.0.0.jar com.sefon.ApplicationLoader --bootstrap-servers=$bootstrap_servers >/dev/null 2>&1 &
    ;;
    controller)
        nohup bin/storm jar topology/iot-data-storm-controller-1.0.0.jar com.sefon.ApplicationLoader --bootstrap-servers=$bootstrap_servers >/dev/null 2>&1 &
    ;;
    *)
        echo "usage: [pusher|controller]"
    ;;
esac

wait
