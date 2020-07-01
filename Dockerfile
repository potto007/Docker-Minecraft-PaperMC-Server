########################################################
############## We use a java base image ################
########################################################
FROM adoptopenjdk:8-openj9 AS build

LABEL maintainer="Paul Otto <paul@ottoops.com>"

ARG USER=minecraft
ARG UID=1000

ARG paperspigot_ci_url=https://papermc.io/api/v1/paper/1.16.1/latest/download
ENV PAPERSPIGOT_CI_URL=$paperspigot_ci_url

WORKDIR /opt/minecraft

# Download paperclip
ADD ${PAPERSPIGOT_CI_URL} paperclip.jar

# User
RUN groupadd --gid ${UID} ${USER} && \
    useradd --uid ${UID} --gid ${UID} --shell /bin/bash ${USER} && \
    chown ${UID}:${UID} /opt/minecraft -R

USER ${USER}

# Run paperclip and obtain patched jar
RUN timeout --signal=9 30 /opt/java/openjdk/bin/java -Dcom.mojang.eula.agree=true -jar /opt/minecraft/paperclip.jar; exit 0

# Copy built jar
RUN mv /opt/minecraft/cache/patched*.jar paperspigot.jar

########################################################
############## Running environment #####################
########################################################
FROM adoptopenjdk:8-openj9 AS runtime

# Working directory
WORKDIR /data

# Obtain runable jar from build stage
COPY --from=build /opt/minecraft/paperspigot.jar /opt/minecraft/paperspigot.jar

# Install and run rcon
ARG RCON_CLI_VER=1.4.8
ADD https://github.com/itzg/rcon-cli/releases/download/${RCON_CLI_VER}/rcon-cli_${RCON_CLI_VER}_linux_amd64.tar.gz /tmp/rcon-cli.tgz
RUN tar -x -C /usr/local/bin -f /tmp/rcon-cli.tgz rcon-cli && \
  rm /tmp/rcon-cli.tgz

# Volumes for the external data (Server, World, Config...)
VOLUME "/data"

# Expose minecraft port
EXPOSE 25565/tcp
EXPOSE 25565/udp

# Set memory size
ARG memory_size=3072
ENV MEMORYSIZE=$memory_size

# Set Java Flags
ARG java_flags="-Xgc:concurrentScavenge -Xgc:dnssExpectedTimeRatioMaximum=3 -Xgc:scvNoAdaptiveTenure -Xdisableexplicitgc -Dcom.mojang.eula.agree=true"
ENV JAVAFLAGS=$java_flags

WORKDIR /data

# Entrypoint with java optimisations
ENTRYPOINT /opt/java/openjdk/bin/java -jar -Xms${MEMORYSIZE}M -Xmx${MEMORYSIZE}M -Xmns$(($MEMORYSIZE /2))M -Xmnx$(($MEMORYSIZE * 4 / 5))M $JAVAFLAGS /opt/minecraft/paperspigot.jar --nojline nogui
