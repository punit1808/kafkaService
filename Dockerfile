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
echo "Initializing Kafka storage (if needed)..."\n\
if [ ! -f "$KAFKA_HOME/data/meta.properties" ]; then\n\
  mkdir -p $KAFKA_HOME/data\n\
  $KAFKA_HOME/bin/kafka-storage.sh format --ignore-formatted --cluster-id=$($KAFKA_HOME/bin/kafka-storage.sh random-uuid) --config $KAFKA_HOME/config/kraft/server.properties\n\
fi\n\
\n\
echo "Starting Kafka (KRaft mode)..."\n\
if [ -n "$RENDER_EXTERNAL_URL" ]; then\n\
  HOST=$(echo $RENDER_EXTERNAL_URL | sed "s~http[s]*://~~g")\n\
  sed -i "s|#listeners=PLAINTEXT://:9092|listeners=PLAINTEXT://0.0.0.0:9092|g" $KAFKA_HOME/config/kraft/server.properties\n\
  echo "advertised.listeners=PLAINTEXT://$HOST:9092" >> $KAFKA_HOME/config/kraft/server.properties\n\
else\n\
  sed -i "s|#listeners=PLAINTEXT://:9092|listeners=PLAINTEXT://0.0.0.0:9092|g" $KAFKA_HOME/config/kraft/server.properties\n\
  echo "advertised.listeners=PLAINTEXT://localhost:9092" >> $KAFKA_HOME/config/kraft/server.properties\n\
fi\n\
\n\
exec $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/kraft/server.properties\n' > /usr/local/bin/start-kafka.sh && \
    chmod +x /usr/local/bin/start-kafka.sh

EXPOSE 9092
CMD ["/usr/local/bin/start-kafka.sh"]
