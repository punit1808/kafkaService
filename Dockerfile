FROM openjdk:17-jdk-slim

ENV KAFKA_VERSION=4.1.0
ENV SCALA_VERSION=2.13
ENV KAFKA_HOME=/opt/kafka
ENV PATH="$KAFKA_HOME/bin:$PATH"

# Memory optimization for Render
ENV KAFKA_HEAP_OPTS="-Xmx512M -Xms256M"

# Install dependencies
RUN apt-get update && apt-get install -y curl dnsutils && rm -rf /var/lib/apt/lists/*

# Download and extract Kafka
WORKDIR /tmp
RUN curl -O https://dlcdn.apache.org/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz && \
    tar -xzf kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz && \
    mv kafka_${SCALA_VERSION}-${KAFKA_VERSION} ${KAFKA_HOME} && \
    rm kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz

WORKDIR $KAFKA_HOME

# Create startup script for Kafka in KRaft mode
RUN echo '#!/bin/bash
set -e

echo "Preparing Kafka configuration..."
mkdir -p $KAFKA_HOME/config/kraft

# Base single-node KRaft configuration
cat <<EOT > $KAFKA_HOME/config/kraft/server.properties
process.roles=broker,controller
node.id=1
controller.listener.names=CONTROLLER
listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
listener.security.protocol.map=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT
log.dirs=$KAFKA_HOME/data
num.partitions=1
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
auto.create.topics.enable=true
EOT

# Set advertised and controller addresses for Render
HOST="kafkaservice-vop4.onrender.com"
echo "controller.quorum.voters=1@$HOST:9093" >> $KAFKA_HOME/config/kraft/server.properties
echo "advertised.listeners=PLAINTEXT://$HOST:9092" >> $KAFKA_HOME/config/kraft/server.properties

echo "Formatting storage if needed..."
if [ ! -f "$KAFKA_HOME/data/meta.properties" ]; then
  mkdir -p $KAFKA_HOME/data
  $KAFKA_HOME/bin/kafka-storage.sh format --ignore-formatted --standalone \
    --cluster-id=$($KAFKA_HOME/bin/kafka-storage.sh random-uuid) \
    --config $KAFKA_HOME/config/kraft/server.properties
fi

echo "Starting Kafka on $HOST:9092 ..."
exec $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/kraft/server.properties
' > /usr/local/bin/start-kafka.sh && chmod +x /usr/local/bin/start-kafka.sh

EXPOSE 9092
CMD ["/usr/local/bin/start-kafka.sh"]
