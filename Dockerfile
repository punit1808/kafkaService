# Use official JDK base
FROM openjdk:17-slim

# Install dependencies
RUN apt-get update && apt-get install -y curl tar bash && rm -rf /var/lib/apt/lists/*

# Set Kafka version and home
ENV KAFKA_VERSION=4.1.0
ENV SCALA_VERSION=2.13
ENV KAFKA_HOME=/opt/kafka
WORKDIR $KAFKA_HOME

# Download Kafka
RUN curl -fsSL https://dlcdn.apache.org/kafka/${KAFKA_VERSION}/kafka-${SCALA_VERSION}-${KAFKA_VERSION}-src.tgz -o kafka.tgz && \
    tar -xzf kafka.tgz --strip 1 && \
    rm kafka.tgz

# Expose Kafka port
EXPOSE 9092

# Set Render public hostname dynamically
ENV KAFKA_ADVERTISED_LISTENER=PLAINTEXT://0.0.0.0:9092

# Startup script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "Starting Kafka in KRaft mode..."\n\
\n\
# Set node ID\n\
export KAFKA_NODE_ID=${HOSTNAME:-1}\n\
\n\
# Prepare directories\n\
mkdir -p /tmp/kraft-combined-logs\n\
\n\
# Format storage if not already formatted\n\
if [ ! -f /tmp/kraft-combined-logs/meta.properties ]; then\n\
  echo "Formatting KRaft storage..."\n\
  $KAFKA_HOME/bin/kafka-storage.sh format --ignore-formatted --config $KAFKA_HOME/config/kraft/server.properties --cluster-id=$(uuidgen)\n\
fi\n\
\n\
# Modify config dynamically\n\
sed -i \"s|^#listeners=.*|listeners=PLAINTEXT://0.0.0.0:9092|\" $KAFKA_HOME/config/kraft/server.properties\n\
sed -i \"s|^#advertised.listeners=.*|advertised.listeners=PLAINTEXT://${RENDER_EXTERNAL_HOSTNAME:-localhost}:9092|\" $KAFKA_HOME/config/kraft/server.properties\n\
sed -i \"s|^#process.roles=.*|process.roles=broker,controller|\" $KAFKA_HOME/config/kraft/server.properties\n\
sed -i \"s|^#controller.listener.names=.*|controller.listener.names=CONTROLLER|\" $KAFKA_HOME/config/kraft/server.properties\n\
sed -i \"s|^#listener.security.protocol.map=.*|listener.security.protocol.map=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT|\" $KAFKA_HOME/config/kraft/server.properties\n\
sed -i \"s|^#controller.quorum.voters=.*|controller.quorum.voters=1@localhost:9093|\" $KAFKA_HOME/config/kraft/server.properties\n\
sed -i \"s|^#log.dirs=.*|log.dirs=/tmp/kraft-combined-logs|\" $KAFKA_HOME/config/kraft/server.properties\n\
echo "socket.request.max.bytes=524288000" >> $KAFKA_HOME/config/kraft/server.properties\n\
\n\
# Start Kafka\n\
exec $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/kraft/server.properties\n' > /start-kafka.sh

RUN chmod +x /start-kafka.sh

CMD ["/start-kafka.sh"]
