## Parametrized build
# Code Server main version
ARG CODESERVER=4.97.1-rc.1


# Get NVM
FROM curlimages/curl AS nvm
ENV  NVM_VERSION=v0.40.1
RUN curl --silent -o /tmp/nvm.sh https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh

FROM curlimages/curl AS mongosh
ARG TARGETPLATFORM
ARG BUILDPLATFORM
# linux/amd64,linux/arm64
ENV MONGOSH_VERSION=2.2.3
ENV MONGO_ARCH=arm64
WORKDIR /mongosh
# x64 : https://downloads.mongodb.com/compass/mongosh-2.3.3-linux-x64.tgz
# arm64 https://downloads.mongodb.com/compass/mongosh-2.3.3-linux-arm64.tgz
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; \
    then export  MONGO_ARCH=arm64 \
    else export MONGO_ARCH=x64; \
    fi \
    && echo "Downloading Mongosh ${MONGO_ARCH}" \
    && curl --silent -o /mongosh/mongosh.tgz https://downloads.mongodb.com/compass/mongosh-${MONGOSH_VERSION}-linux-${MONGO_ARCH}.tgz
RUN tar -zxvf /mongosh/mongosh.tgz 
RUN rm -rf /mongosh/mongosh.tgz 

# Prepare Docker cli install package manager key 
FROM curlimages/curl AS dockercli
RUN curl --silent -o /tmp/docker.asc https://download.docker.com/linux/ubuntu/gpg 

####################################################################
# Code server starts here
####################################################################
FROM ghcr.io/coder/code-server:${CODESERVER_VERSION}-ubuntu
ARG WITH_PACKAGES=python3
# Node config
ENV NVM_DIR=/home/coder/.nvm
ENV NODE_VERSION=23.1.0

### Root section 
USER root
SHELL ["/bin/bash", "-c"]

# Register apt for docker
RUN mkdir -p /etc/apt/keyrings && \
    chmod 0755 -R /etc/apt/keyrings && \
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
COPY --from=dockercli /tmp/docker.asc /etc/apt/keyrings/docker.asc

# Install packages
#apt-get update
# chmod a+r /etc/apt/keyrings/docker.asc && \
RUN apt-get update && \
    apt-get install -y ca-certificates curl zip unzip docker-ce-cli ${WITH_PACKAGES}  && \
    rm -rf /var/lib/apt/lists/*
# docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
# Install NVM script 
COPY --from=nvm /tmp/nvm.sh /tmp/nvm.sh
RUN chown -R coder:coder /tmp/nvm.sh  && chmod +x /tmp/nvm.sh

# Install mongosh
COPY --from=mongosh /mongosh/ /usr/share/mongosh/
RUN ln -s /usr/share/mongosh/bin/* /usr/local/bin/


### User space operations
USER coder
WORKDIR /home/coder

#sdkman
RUN curl -s "https://get.sdkman.io" | bash > /dev/null
RUN source "/home/coder/.sdkman/bin/sdkman-init.sh" && sdk install java && sdk install quarkus > /dev/null

# Install NVM for user
RUN /tmp/nvm.sh && rm -f /tmp/nvm.sh 
# install node and npm
RUN source $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

ENV NODE_PATH=$NVM_DIR/v$NODE_VERSION/lib/node_modules
ENV PATH=$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH





