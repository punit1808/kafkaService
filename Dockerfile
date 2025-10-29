FROM openjdk:17-jdk-slim

ENV KAFKA_VERSION=4.1.0
ENV SCALA_VERSION=2.13
ENV KAFKA_HOME=/opt/kafka
ENV PATH="$KAFKA_HOME/bin:$PATH"

# Install dependencies
RUN apt-get update && apt-get install -y curl dnsutils && rm -rf /var/lib/apt/lists/*

# Download and extract Kafka
WORKDIR /tmp
RUN curl -O https://dlcdn.apache.org/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz && \
    tar -xzf kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz && \
    mv kafka_${SCALA_VERSION}-${KAFKA_VERSION} ${KAFKA_HOME} && \
    rm kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz

WORKDIR $KAFKA_HOME

# Create start script for KRaft mode
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "Preparing Kafka config..."\n\
mkdir -p $KAFKA_HOME/config/kraft\n\
cp $KAFKA_HOME/config/server.properties $KAFKA_HOME/config/kraft/server.properties\n\
\n\
# Configure KRaft single-node mode\n\
cat <<EOT >> $KAFKA_HOME/config/kraft/server.properties\n\
process.roles=broker,controller\n\
node.id=1\n\
controller.listener.names=CONTROLLER\n\
listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://:9093\n\
controller.quorum.voters=1@localhost:9093\n\
log.dirs=$KAFKA_HOME/data\n\
EOT\n\
\n\
echo "Initializing Kafka storage (if needed)..."\n\
if [ ! -f "$KAFKA_HOME/data/meta.properties" ]; then\n\
  mkdir -p $KAFKA_HOME/data\n\
  $KAFKA_HOME/bin/kafka-storage.sh format --ignore-formatted --standalone \\\n\
    --cluster-id=$($KAFKA_HOME/bin/kafka-storage.sh random-uuid) \\\n\
    --config $KAFKA_HOME/config/kraft/server.properties\n\
fi\n\
\n\
echo "Starting Kafka (KRaft standalone mode)..."\n\
if [ -n "$RENDER_EXTERNAL_URL" ]; then\n\
  HOST=$(echo $RENDER_EXTERNAL_URL | sed "s~http[s]*://~~g")\n\
  sed -i "s|advertised.listeners=.*|advertised.listeners=PLAINTEXT://$HOST:9092|g" $KAFKA_HOME/config/kraft/server.properties || echo "advertised.listeners=PLAINTEXT://$HOST:9092" >> $KAFKA_HOME/config/kraft/server.properties\n\
else\n\
  sed -i "s|advertised.listeners=.*|advertised.listeners=PLAINTEXT://localhost:9092|g" $KAFKA_HOME/config/kraft/server.properties || echo "advertised.listeners=PLAINTEXT://localhost:9092" >> $KAFKA_HOME/config/kraft/server.properties\n\
fi\n\
\n\
exec $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/kraft/server.properties\n' > /usr/local/bin/start-kafka.sh && \
    chmod +x /usr/local/bin/start-kafka.sh

EXPOSE 9092
CMD ["/usr/local/bin/start-kafka.sh"]
