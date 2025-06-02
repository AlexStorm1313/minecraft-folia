FROM fedora:latest

LABEL name="AlexStorm1313/minecraft-folia" \
    vendor="AlexStorm1313" \
    version="0.0.1" \
    release="1" \
    summary="Minecraft Folia" \
    description="minecraft Folia"

# Enable RPMFusion & copr & flatpak
RUN dnf -y update && \
    dnf -y install \
    curl \
    jq \
    java-latest-openjdk && \
    dnf -y clean all


# User and permissions, a.k.a. userspace
ARG USER=folia
ARG UID=1001
ARG GID=0
ARG HOME_DIR=/home/${USER}

# Add the user
RUN groupadd ${USER} && \
    useradd -g ${USER} ${USER}

# Specify Folia version and source
ARG VERSION=latest
ARG BASE_URL=https://api.papermc.io/v2/projects/folia

# Copy the download script
COPY <<'EOF' ${HOME_DIR}/download_folia.sh
#!/bin/bash
VERSION=${VERSION}
BASE_URL=${BASE_URL}

echo "Checking version: $VERSION $BASE_URL"

if [ "$VERSION" == "latest" ]; then
    echo "Fetching latest version..."
    VERSION=$(curl -s "$BASE_URL" | jq -r '.versions | .[-1]')
    echo "Latest version found: $VERSION"
fi

echo "Fetching latest build for version $VERSION..."
LATEST_BUILD=$(curl -s "$BASE_URL/versions/$VERSION" | jq -r '.builds | .[-1]')
echo "Latest build found: $LATEST_BUILD"

echo "Downloading Folia $VERSION build $LATEST_BUILD..."
echo "URL: $BASE_URL/versions/$VERSION/builds/$LATEST_BUILD/downloads/folia-$VERSION-$LATEST_BUILD.jar"
curl -o "${HOME_DIR}/server.jar" -L "$BASE_URL/versions/$VERSION/builds/$LATEST_BUILD/downloads/folia-$VERSION-$LATEST_BUILD.jar"

if [ $? -eq 0 ]; then
    echo "Download Folia Version ($VERSION) Build ($LATEST_BUILD) - SUCCESS"
    ls -la ${HOME_DIR}/server.jar
else
    echo "An error occurred while downloading Folia. Please try again or recreate the container."
    exit 1
fi
EOF

# Make the script executable and execute
RUN chmod +x ${HOME_DIR}/download_folia.sh && \
    ${HOME_DIR}/download_folia.sh

# Set working directory
WORKDIR ${HOME_DIR}

VOLUME ${HOME_DIR}

# Changing ownership and user rights to support following use-cases:
# 1) running container on OpenShift, whose default security model
#    is to run the container under random UID, but GID=0
# 2) for working root-less container with UID=1001, which does not have
#    to have GID=0
# 3) for default use-case, that is running container directly on operating system,
#    with default UID and GID (1001:0)
# Supported combinations of UID:GID are thus following:
# UID=1001 && GID=0
# UID=<any>&& GID=0
# UID=1001 && GID=<any>
RUN chown -R ${UID}:${GID} ${HOME_DIR} && \
    chmod -R g=u ${HOME_DIR}

# Set fixed non-root user for compatibility with Podman/Docker and Kubernetes
USER ${UID}

ENV MIN_RAM=512M
ENV MAX_RAM=1G
ENV JAVA_FLAGS="--add-modules=jdk.incubator.vector -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20"
ENV FOLIA_FLAGS="--nojline"
ENV MINECRAFT_EULA=false

# Start Folia
ENTRYPOINT [ "/bin/bash", "-c", "exec java -Xms${MIN_RAM} -Xmx${MAX_RAM} ${JAVA_FLAGS} -Dcom.mojang.eula.agree=${MINECRAFT_EULA} -jar ${HOME}/server.jar ${FOLIA_FLAGS} --nogui" ]