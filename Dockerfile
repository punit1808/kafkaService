FROM apache/kafka:4.1.0.

# Copy your configs
COPY server.properties /opt/kafka/config/server.properties
COPY --chmod=755 start-kafka.sh /opt/kafka/start-kafka.sh

EXPOSE 9092

# Run Kafka in KRaft mode
CMD ["/opt/kafka/start-kafka.sh"]
