# Use the official Kafka image (with KRaft support)
FROM apache/kafka:3.7.0

# Copy your configs
COPY server.properties /opt/kafka/config/server.properties
COPY start-kafka.sh /opt/kafka/start-kafka.sh

RUN chmod +x /opt/kafka/start-kafka.sh

EXPOSE 9092

# Run Kafka in KRaft mode
CMD ["/opt/kafka/start-kafka.sh"]
