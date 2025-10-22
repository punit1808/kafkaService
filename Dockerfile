# Dockerfile
FROM docker.io/bitnami/kafka:3.7.0

# Expose Kafka ports
EXPOSE 9092 9093

# Set environment variables for basic Kafka setup
ENV KAFKA_CFG_ZOOKEEPER_CONNECT=zookeeper:2181
ENV ALLOW_PLAINTEXT_LISTENER=yes
ENV KAFKA_CFG_LISTENERS=PLAINTEXT://:9092
ENV KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092
