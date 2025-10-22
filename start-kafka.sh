#!/bin/bash
set -e

KAFKA_HOME="/opt/kafka"

# Check if meta.properties exists (KRaft metadata initialized)
if [ ! -f "/tmp/kraft-combined-logs/meta.properties" ]; then
  echo "Initializing KRaft metadata..."
  CLUSTER_ID=$($KAFKA_HOME/bin/kafka-storage.sh random-uuid)
  $KAFKA_HOME/bin/kafka-storage.sh format \
    -t $CLUSTER_ID \
    -c $KAFKA_HOME/config/server.properties
fi

echo "Starting Kafka in KRaft mode..."
exec $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties
