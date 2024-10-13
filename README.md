# Iteration 01: the manual way

Create a directory to store our files:

```bash
mkdir dbbackup
```

Create a database:

```bash
docker run --name mysql-demo -e MYSQL_ROOT_PASSWORD=admin -e MYSQL_DATABASE=mydatabase -p 3306:3306 -d mysql:latest
```

Seed the database with some dummy data:

```sql
-- seed.sql
CREATE DATABASE IF NOT EXISTS mydatabase;
USE mydatabase;
CREATE TABLE IF NOT EXISTS employees (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    position VARCHAR(100),
    salary INT
);

INSERT INTO employees (name, position, salary) VALUES 
('Alice', 'Engineer', 70000),
('Bob', 'Manager', 85000),
('Charlie', 'Analyst', 60000);

```

```bash
mysql -h 127.0.0.1 -u root -padmin < seed.sql
```

Ensure that we have the data in the DB:

```bash
mysql -h 127.0.0.1 -u root -padmin
select * from mydatabase.employees
```

Dump the database (take backup)

```bash
mkdir backups
mysqldump -h 127.0.0.1 -u root -padmin mydatabase > "backups/mydatabase_backup_$(date +%F_%T).sql"
```

View the result:

```bash
ls -l backups
cat backups/file_name.sql
```



# Iteration 02: Create the script

First, we need to create an environment file so that we can securely save the database credentials:

```bash
# .env
DB_HOST="127.0.0.1"
DB_USER="root"
MYSQL_PWD="admin"
DB_NAME="mydatabase"
```



```bash
#!/bin/bash

# Load environment variables from .env file
set -a
[ -f .env ] && . .env
set +a

# Configuration
BACKUP_DIR="backups"
TIMESTAMP=$(date +"%F_%T")

# Check if backup directory exists, if not create it
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
fi

# Perform the backup
mysqldump -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" > "$BACKUP_DIR/${DB_NAME}_backup_$TIMESTAMP.sql"

# Check if the backup was successful
if [ $? -eq 0 ]; then
    echo "$BACKUP_DIR/${DB_NAME}_backup_$TIMESTAMP.sql"
else
    echo "Backup failed!"
    exit 1
fi
```

## Test execution

```bash
chmod +x backup.sh
./backup.sh
```

### Test failure handling

```bash
# Change the password to something that does not work and try the script again, it should fail
```

# Iteration 03: Create unit tests

## We can use Bash Automated Testing System (BATS) which can be installed using Home Brew:

```bash
brew install bats
```

### You can read about it through this link https://bats-core.readthedocs.io/en/stable/ which will be in the description.

## Then create a test file:

```bash
# test.bats
#!/usr/bin/env bats

# Configuration for testing
BACKUP_DIR="backups"
DB_NAME="mydatabase"

# Test 1: Check if backup directory exists
@test "Backup directory exists" {
  run bash -c "[ -d \"$BACKUP_DIR\" ]"
  [ "$status" -eq 0 ]
}

# Test 2: Check if backup file is created and non-empty
@test "Backup file is created and is non-empty" {
  run bash ./backup.sh
  BACKUP_FILE=$output
  [ "$status" -eq 0 ] && [ -f $BACKUP_FILE ] && [ "$(wc -c < $BACKUP_FILE)" -gt 0 ]
}
```

# Iteration 04: Dockerize the solution

## Create a Dockerfile with the following contents:

```dockerfile
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

# Entry point to run the BATS tests
ENTRYPOINT ["/usr/bin/bash"]
```

## Build the Docker image

```bash
docker build -t dbbackup:latest .
```

Try running the container without supplying the environment variables:

```bash
docker run --network="host" -v $(pwd)/backups:/usr/src/app/backups -it dbbackup:latest backup.sh
```

You will find that it is asking for the password which means that it didn't pickup the environment variables since we didn't supply the `.env` file, but we can supply environment variables to Docker as follows:

```bash
docker run --network="host" \
-v $(pwd)/backups:/usr/src/app/backups \
-e DB_HOST=127.0.0.1 \
-e DB_USER=root \
-e DB_PASSWORD=admin \
-e DB_NAME=mydatabase \
-it dbbackup:latest /usr/bin/bash backup.sh
```

Make sure that we have the file created locally in the `backups` directory:

```bash
ls -ltr backups
```

We can also run the tests against our dummy database:

```bash
docker run --network="host" -v $(pwd)/backups:/usr/src/app/backups \
-e DB_HOST=127.0.0.1 \
-e DB_USER=root \
-e DB_PASSWORD=admin \
-e DB_NAME=mydatabase \
-it dbbackup:latest /usr/bin/bats test.bats
```

Once we are OK that our Docker image is working, we can publish it by pushing it to the Docker Hub:

```bash
docker tag dbbackup:latest afakharany/dbbackup:1.0.0
docker push afakharany/dbbackup:1.0.0
```

# Iteration 5: CI/CD

Create a directory for the CI/CD pipeline (we're using GitHub Actions):

```bash
mkdir -p github/workflows
```

In GitHub repository settings, make sure you add the following secrets:

* DOCKER_USERNAME
* DOCKER_PASSWORD

Create the pipeline file and add the following:

```yaml
name: CI/CD Pipeline for MySQL Backup Script

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
env: 
  DB_HOST: "127.0.0.1"
  DB_USER: "root"
  MYSQL_PWD: "password"
  DB_NAME: "mydatabase"

jobs:
  test:
    name: Run BATS Tests
    runs-on: ubuntu-latest

    services:
      mysql:
        image: mysql:latest
        env:
          MYSQL_ROOT_PASSWORD: password
        options: >-
          --health-cmd="mysqladmin ping --silent"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=5
        ports:
          - 3306:3306

    steps:
      # Step 1: Checkout the repository
      - name: Checkout code
        uses: actions/checkout@v4

      # Step 2: Install BATS and MySQL client
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y bats mysql-client

      - name: Create backups directory
        run: mkdir -p backups

        # Step 3: Wait for MySQL service to be ready
      - name: Wait for MySQL to be ready
        run: |
          for i in {1..30}; do
            if mysqladmin ping -h 127.0.0.1 --silent; then
              echo "MySQL is ready!"
              break
            fi
            echo "Waiting for MySQL..."
            sleep 5
          done

      # Step 4: Seed the database using the SQL script
      - name: Seed database
        run: mysql -h 127.0.0.1 -u root -ppassword < seed.sql

      # Step 5: Run the BATS tests
      - name: Run BATS tests
        run: bats test.bats

  build:
    name: Build and Push Docker Image
    runs-on: ubuntu-latest
    needs: test

    steps:
      # Step 1: Checkout the repository
      - name: Checkout code
        uses: actions/checkout@v4

      # Step 2: Set up Docker Buildx
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      # Step 3: Log in to Docker Hub
      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      # Step 4: Get commit hash and semantic version for tagging
      - name: Set up tags for Docker image
        id: vars
        run: |
          COMMIT_HASH=$(git rev-parse --short HEAD)
          echo "COMMIT_HASH=${COMMIT_HASH}" >> $GITHUB_ENV

          # Extract version from git tags (fallback to 0.1.0 if no tags are available)
          TAG_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.1.0")
          echo "TAG_VERSION=${TAG_VERSION}" >> $GITHUB_ENV

      # Step 5: Build and tag the Docker image
      - name: Build Docker image
        run: |
          docker build -t ${{ secrets.DOCKER_USERNAME }}/mysql-backup:${{ env.TAG_VERSION }} -t ${{ secrets.DOCKER_USERNAME }}/mysql-backup:${{ env.COMMIT_HASH }} .

      # Step 6: Push the Docker image to Docker Hub
      - name: Push Docker image
        run: |
          docker push ${{ secrets.DOCKER_USERNAME }}/mysql-backup:${{ env.TAG_VERSION }}
          docker push ${{ secrets.DOCKER_USERNAME }}/mysql-backup:${{ env.COMMIT_HASH }}
```
