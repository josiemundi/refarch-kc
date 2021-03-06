#!/usr/bin/env bash

# Script we are executing
echo -e " \e[32m@@@ Executing script: \e[1;33mrunContainerConsumer.sh \e[0m"

## Variables

# Get the absolute path for this file
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
# Get the absolute path for the refarch-kc project
MAIN_DIR=`echo ${SCRIPTPATH} | sed 's/\(.*refarch-kc\).*/\1/g'`

# Read arguments
if [[ $# -ne 3 ]];then
    echo "Not enough arguments have been provided for the producer. Using the defaults:"
    echo "- Kafka environment --> LOCAL"
    echo "- Kafka topic name --> containers"
    echo "- Container ID --> c_1"
    kcenv=LOCAL
    cid="c_1"
    topic_name="containers"
else
    echo "Producer values:"
    echo "- Kafka environment --> $1"
    echo "- Kafka topic name --> $3"
    echo "- Container ID --> $2"
    kcenv=$1
    cid=$2
    topic_name=$3
fi

# Check if the ibmcase/python docker image exists
EXISTS="$(docker images | awk '{print $1 ":" $2}' | grep ibmcase-python:test)"
if [ -z "${EXISTS}" ]
then
    echo -e "The ibmcase/python docker image does not exist. Creating such image..."
    docker build -f ${MAIN_DIR}/docker/docker-python-tools -t ibmcase-python:test ${MAIN_DIR}/docker
fi

# Set environment variables
source ${MAIN_DIR}/scripts/setenv.sh $kcenv

if [ "OCP" == "${kcenv}" ]; then
    add_cert_to_container_command=" -e PEM_CERT=/certs/${PEM_FILE} -v ${CA_LOCATION}:/certs"
else
    attach_to_network="--network=docker_default"
fi

# Run the container consumer
# We are running the ConsumeContainer.py python script into a python enabled container
# Attached to the same docker_default docker network as the other components
# We also pass to the python consumer the Container ID we want it to poll for
docker run  -e KAFKA_BROKERS=$KAFKA_BROKERS \
            -e KAFKA_APIKEY=$KAFKA_APIKEY \
            -e KAFKA_ENV=$KAFKA_ENV \
            ${add_cert_to_container_command} \
            -v ${MAIN_DIR}:/refarch-kc \
            ${attach_to_network} \
            --rm \
            -ti ibmcase-python:test bash \
            -c "cd /refarch-kc/itg-tests/ContainersPython && \
                export PYTHONPATH=\${PYTHONPATH}:/refarch-kc/itg-tests && python ConsumeContainers.py $cid $topic_name"