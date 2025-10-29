# Use lightweight base image
FROM openjdk:17-slim

ENV KAFKA_VERSION=4.1.0
ENV SCALA_VERSION=2.13
ENV KAFKA_HOME=/opt/kafka
ENV PATH=$PATH:$KAFKA_HOME/bin

# Install curl and dns tools (for Render networking)
RUN apt-get update && apt-get install -y curl dnsutils && apt-get clean

# Download and extract Kafka
WORKDIR /tmp
RUN curl -O https://dlcdn.apache.org/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz && \
    tar -xzf kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz && \
    mv kafka_${SCALA_VERSION}-${KAFKA_VERSION} ${KAFKA_HOME} && \
    rm kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz

WORKDIR ${KAFKA_HOME}

# Create KRaft config file manually (since it's missing)
RUN mkdir -p $KAFKA_HOME/config/kraft && \
    echo 'process.roles=broker,controller' > $KAFKA_HOME/config/kraft/server.properties && \
    echo 'node.id=1' >> $KAFKA_HOME/config/kraft/server.properties && \
    echo 'controller.quorum.voters=1@localhost:9093' >> $KAFKA_HOME/config/kraft/server.properties && \
    echo 'listeners=PLAINTEXT://:9092,CONTROLLER://:9093' >> $KAFKA_HOME/config/kraft/server.properties && \
    echo 'inter.broker.listener.name=PLAINTEXT' >> $KAFKA_HOME/config/kraft/server.properties && \
    echo 'controller.listener.names=CONTROLLER' >> $KAFKA_HOME/config/kraft/server.properties && \
    echo 'log.dirs=/opt/kafka/data' >> $KAFKA_HOME/config/kraft/server.properties && \
    echo 'num.network.threads=3' >> $KAFKA_HOME/config/kraft/server.properties && \
    echo 'num.io.threads=8' >> $KAFKA_HOME/config/kraft/server.properties && \
    echo 'socket.send.buffer.bytes=102400' >> $KAFKA_HOME/config/kraft/server.properties && \
    echo 'socket.receive.buffer.bytes=102400' >> $KAFKA_HOME/config/kraft/server.properties && \
    echo 'socket.request.max.bytes=104857600' >> $KAFKA_HOME/config/kraft/server.properties && \
    echo 'offsets.topic.replication.factor=1' >> $KAFKA_HOME/config/kraft/server.properties && \
    echo 'transaction.state.log.replication.factor=1' >> $KAFKA_HOME/config/kraft/server.properties && \
    echo 'transaction.state.log.min.isr=1' >> $KAFKA_HOME/config/kraft/server.properties && \
    echo 'group.initial.rebalance.delay.ms=0' >> $KAFKA_HOME/config/kraft/server.properties

# Entry script for Render
RUN echo '#!/bin/bash\nset -e\n\
if [ ! -f "$KAFKA_HOME/data/meta.properties" ]; then\n\
  echo "Formatting Kafka storage..."\n\
  CLUSTER_ID=$($KAFKA_HOME/bin/kafka-storage.sh random-uuid)\n\
  $KAFKA_HOME/bin/kafka-storage.sh format --ignore-formatted --cluster-id=$CLUSTER_ID --config $KAFKA_HOME/config/kraft/server.properties\n\
fi\n\
if [ -n "$RENDER_EXTERNAL_URL" ]; then\n\
  HOST=$(echo $RENDER_EXTERNAL_URL | sed "s~http[s]*://~~g")\n\
  sed -i \"s|advertised.listeners=.*|advertised.listeners=PLAINTEXT://$HOST:9092|g\" $KAFKA_HOME/config/kraft/server.properties || echo \"advertised.listeners=PLAINTEXT://$HOST:9092\" >> $KAFKA_HOME/config/kraft/server.properties\n\
else\n\
  sed -i \"s|advertised.listeners=.*|advertised.listeners=PLAINTEXT://localhost:9092|g\" $KAFKA_HOME/config/kraft/server.properties || echo \"advertised.listeners=PLAINTEXT://localhost:9092\" >> $KAFKA_HOME/config/kraft/server.properties\n\
fi\n\
exec $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/kraft/server.properties\n' > /usr/local/bin/start-kafka.sh && chmod +x /usr/local/bin/start-kafka.sh

EXPOSE 9092
CMD ["start-kafka.sh"]
