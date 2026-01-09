FROM maven:3.9.12-eclipse-temurin-25-alpine

# Create a non-root user, but copy files and prepare directories as root first
ARG CONTAINER_UID=1000
ARG CONTAINER_GID=1000

RUN addgroup -g "${CONTAINER_GID}" container || true \
 && adduser -D -u "${CONTAINER_UID}" -G container -h /home/container container

# Copy entrypoint and make it executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
 && mkdir -p /home/container/artifacts \
 && chown -R container:container /home/container /entrypoint.sh

# Default envs (can be overridden at runtime)
ENV HOME=/home/container \
    PLUGIN_PATHS=/home/container \
    OUT_DIR=/home/container/artifacts \
    MAVEN_OPTS=-Xmx512m \
    MAVEN_SETTINGS=""

WORKDIR /home/container
USER container

ENTRYPOINT ["/entrypoint.sh"]
