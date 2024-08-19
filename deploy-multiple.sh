#!/bin/bash

CSV_FILE=$1
OUTPUT_FILE="docker-compose.generated.yml"
LOGS_DIR="./logs"
PORT=8080  # Initial port
SERVICE_NB=1

# Create the logs directory if it doesn't exist
mkdir -p $LOGS_DIR

# Start the YAML file
cat <<EOF > $OUTPUT_FILE
version: "3.4"

x-common: &common
  restart: unless-stopped
  volumes:
    - ./data/.opencanary.conf:/root/.opencanary.conf
    # uncomment below if running Samba
    # - /var/log/samba-audit.log:/var/log/samba-audit.log
  image: "opencanary"
networks:
  my_custom_network:
    external: false
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.1.0/24

services:
EOF

# Read the CSV and append services
while IFS=, read -r IP_ADDRESS MAC_ADDRESS || [ -n "$IP_ADDRESS" ]; do
  SERVICE_NAME="opencanary${SERVICE_NB}"
  LOG_FILE="${LOGS_DIR}/${SERVICE_NAME}.log"
  
  cat <<EOF >> $OUTPUT_FILE
  $SERVICE_NAME:
    <<: *common
    image: "opencanary"
    container_name: $SERVICE_NAME
    mac_address: "$MAC_ADDRESS"
    networks:
      my_custom_network:
        ipv4_address: $IP_ADDRESS
    build:
      context: .
      dockerfile: Dockerfile.latest
    ports:
      - "${PORT}:80"

EOF
  SERVICE_NB=$((SERVICE_NB + 1)) # increment service number
  PORT=$((PORT + 1)) # Increment the port for each service
done < <(tail -n +2 "$CSV_FILE")

echo "Docker Compose file generated at $OUTPUT_FILE"

docker-compose -f docker-compose.generated.yml up -d --build --force-recreate
