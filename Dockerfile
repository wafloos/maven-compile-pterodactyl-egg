FROM maven:3.9.12-eclipse-temurin-25-alpine

# Allow overridable build-time UID/GID for the runtime user
ARG CONTAINER_UID=1000
ARG CONTAINER_GID=1000

# Install su-exec for simple re-exec as an unprivileged user when PUID/PGID are supplied
RUN apk add --no-cache su-exec \
 && addgroup -g "${CONTAINER_GID}" container || true \
 && adduser -D -u "${CONTAINER_UID}" -G container -h /home/container container \
 && mkdir -p /home/container /home/container/artifacts \
 && chown -R container:container /home/container

# Copy entrypoint and make executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Default envs. OUT_DIR is empty by default (no copying) to leave artifacts in project/target/
ENV HOME=/home/container \
    PLUGIN_PATHS=/home/container/* \
    PLUGIN_DIR= \
    OUT_DIR= \
    MAVEN_OPTS=-Xmx512m \
    MAVEN_SETTINGS= \
    KEEP_ALIVE=false \
    PUID= \
    PGID=

WORKDIR /home/container
USER container

ENTRYPOINT ["/entrypoint.sh"]
