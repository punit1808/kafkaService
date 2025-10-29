# Base image with Java (Kafka requires Java 17+)
FROM openjdk:17-jdk-slim

# Set environment variables
ENV KAFKA_VERSION=4.1.0
ENV SCALA_VERSION=2.13
ENV KAFKA_HOME=/opt/kafka
ENV PATH="$KAFKA_HOME/bin:$PATH"

# Install dependencies
RUN apt-get update && apt-get install -y curl bash net-tools dnsutils jq && rm -rf /var/lib/apt/lists/*

# Download and extract the official *binary* Kafka tarball (not source)
WORKDIR /tmp
RUN curl -O https://downloads.apache.org/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz && \
    tar -xzf kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz && \
    mv kafka_${SCALA_VERSION}-${KAFKA_VERSION} $KAFKA_HOME && \
    rm kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz

WORKDIR $KAFKA_HOME

# Expose Kafka broker port
EXPOSE 9092

# Create startup script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "Starting ZooKeeper..."\n\
$KAFKA_HOME/bin/zookeeper-server-start.sh $KAFKA_HOME/config/zookeeper.properties &\n\
sleep 5\n\
\n\
echo "Starting Kafka Broker..."\n\
if [ -n "$RENDER_EXTERNAL_URL" ]; then\n\
  HOST=$(echo $RENDER_EXTERNAL_URL | sed "s~http[s]*://~~g")\n\
  sed -i "s|#listeners=PLAINTEXT://:9092|listeners=PLAINTEXT://0.0.0.0:9092|g" $KAFKA_HOME/config/server.properties\n\
  echo "advertised.listeners=PLAINTEXT://$HOST:9092" >> $KAFKA_HOME/config/server.properties\n\
else\n\
  sed -i "s|#listeners=PLAINTEXT://:9092|listeners=PLAINTEXT://0.0.0.0:9092|g" $KAFKA_HOME/config/server.properties\n\
  echo "advertised.listeners=PLAINTEXT://localhost:9092" >> $KAFKA_HOME/config/server.properties\n\
fi\n\
\n\
$KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties\n' > /usr/local/bin/start-kafka.sh && \
    chmod +x /usr/local/bin/start-kafka.sh

# Default command
CMD ["/usr/local/bin/start-kafka.sh"]
