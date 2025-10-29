FROM openjdk:17-jdk-slim

ENV KAFKA_VERSION=4.1.0
ENV SCALA_VERSION=2.13
ENV KAFKA_HOME=/opt/kafka
ENV PATH="$KAFKA_HOME/bin:$PATH"

# Limit JVM memory to avoid OOM on Render
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

# Create Kafka startup script for KRaft mode (Render-compatible)
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "Preparing Kafka configuration..."\n\
mkdir -p $KAFKA_HOME/config/kraft\n\
\n\
# Base KRaft config\n\
cat <<EOT > $KAFKA_HOME/config/kraft/server.properties\n\
process.roles=broker,controller\n\
node.id=1\n\
controller.listener.names=CONTROLLER\n\
listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093\n\
listener.security.protocol.map=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT\n\
log.dirs=$KAFKA_HOME/data\n\
num.partitions=1\n\
offsets.topic.replication.factor=1\n\
transaction.state.log.replication.factor=1\n\
transaction.state.log.min.isr=1\n\
auto.create.topics.enable=true\n\
controller.quorum.voters=1@kafkaservice-vop4.onrender.com:9093\n\
advertised.listeners=PLAINTEXT://kafkaservice-vop4.onrender.com:9092\n\
EOT\n\
\n\
echo "Formatting storage if needed..."\n\
if [ ! -f "$KAFKA_HOME/data/meta.properties" ]; then\n\
  mkdir -p $KAFKA_HOME/data\n\
  $KAFKA_HOME/bin/kafka-storage.sh format --ignore-formatted --standalone \\\n\
    --cluster-id=$($KAFKA_HOME/bin/kafka-storage.sh random-uuid) \\\n\
    --config $KAFKA_HOME/config/kraft/server.properties\n\
fi\n\
\n\
echo "Starting Kafka..."\n\
exec $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/kraft/server.properties\n' > /usr/local/bin/start-kafka.sh && \
    chmod +x /usr/local/bin/start-kafka.sh

# Expose Kafka port
EXPOSE 9092

# Start Kafka when container launches
CMD ["/usr/local/bin/start-kafka.sh"]
