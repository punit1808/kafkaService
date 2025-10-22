FROM openjdk:17-jdk-slim

ENV KAFKA_VERSION=3.7.1
ENV SCALA_VERSION=2.13
ENV KAFKA_HOME=/opt/kafka

RUN apt-get update && apt-get install -y wget supervisor && apt-get clean
RUN wget https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz && \
    tar -xzf kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz -C /opt && \
    mv /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION} ${KAFKA_HOME} && \
    rm kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz

# Configure broker for external access
RUN echo "listeners=PLAINTEXT://0.0.0.0:9092" >> /opt/kafka/config/server.properties && \
    echo "advertised.listeners=PLAINTEXT://0.0.0.0:9092" >> /opt/kafka/config/server.properties

# Use supervisor to manage both Zookeeper and Kafka
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
EXPOSE 2181 9092

CMD ["/usr/bin/supervisord"]
