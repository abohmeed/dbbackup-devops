# Base image
FROM ubuntu:20.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    mysql-client \
    bats \
    && apt-get clean

# Create working directory
WORKDIR /usr/src/app

# Copy the backup and BATS test scripts into the container
COPY backup.sh test.bats ./

# Make the backup script executable
RUN chmod +x backup.sh

# Create the backup directory inside the container
RUN mkdir backups