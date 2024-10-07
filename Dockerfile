# syntax=docker/dockerfile:1

FROM python:3.11-slim-bullseye AS base

ARG GID=1001
ARG UID=1001

# Update and install dependencies in one layer to keep the image size small
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y jq && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure that the GID and UID are free, if not, increment to find a free one
RUN if getent group ${GID} > /dev/null 2>&1; then \
      GID_CANDIDATE=$((GID + 1)); \
      while getent group $GID_CANDIDATE > /dev/null 2>&1; do \
        GID_CANDIDATE=$((GID_CANDIDATE + 1)); \
      done; \
      GID=${GID_CANDIDATE}; \
    fi; \
    if getent passwd ${UID} > /dev/null 2>&1; then \
      UID_CANDIDATE=$((UID + 1)); \
      while getent passwd $UID_CANDIDATE > /dev/null 2>&1; do \
        UID_CANDIDATE=$((UID_CANDIDATE + 1)); \
      done; \
      UID=${UID_CANDIDATE}; \
    fi; \
    groupadd -g ${GID} docker-user && \
    useradd -m -s /bin/bash -u ${UID} -g ${GID} docker-user && \
    echo "docker-user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Set the working directory and add the application code
WORKDIR /home/docker-user/amides
ADD ./amides /home/docker-user/amides

# Setup the Python environment
RUN python -m venv /home/docker-user/amides/venv
ENV PATH="/home/docker-user/amides/venv/bin:$PATH"

# Ensure the docker-user owns their home directory and change to that user
RUN chown -R docker-user:docker-user /home/docker-user/amides
USER docker-user

# Install Python dependencies
RUN pip install --upgrade pip && \
    pip install -r requirements_dev.txt && \
    pip install tox && \
    pip install -e .

# Make scripts executable
RUN chmod +x experiments.sh classification.sh rule_attribution.sh tainted_training.sh classification_other_types.sh