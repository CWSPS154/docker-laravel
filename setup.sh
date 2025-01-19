#!/bin/bash

# Function to handle errors and execute rollback
handle_error() {
  echo "An error occurred during setup. Rolling back changes..."
  chmod +x bin/rollback && ./bin/rollback
  exit 1
}

# Function to setup Laravel configurations
laravel_configure() {
  echo "Setting up your Laravel configurations."
  chmod +x bin/configure && ./bin/configure
  if [ $? -ne 0 ]; then
    echo "Laravel configuration failed."
    handle_error
  fi
}

# Function to run Artisan commands
run_artisan() {
  local cmd=$1
  echo "Running Artisan command: $cmd"
  chmod +x bin/cli && ./bin/cli $cmd
  if [ $? -ne 0 ]; then
    echo "Artisan command failed: $cmd"
    handle_error
  fi
}

# Ensure all scripts in the bin directory have executable permissions
chmod +x bin/*

# Check if Docker is installed
if ! [ -x "$(command -v docker)" ]; then
  echo "Error: Docker is not installed." >&2
  exit 1
fi

# Check if Docker Compose is installed
if ! [ -x "$(command -v docker-compose)" ]; then
  echo "Error: Docker Compose is not installed." >&2
  exit 1
fi

# Ensure the user is part of the docker group
if ! groups $USER | grep &>/dev/null '\bdocker\b'; then
  echo "Adding user to the docker group..."
  sudo usermod -aG docker $USER
  newgrp docker
fi

# Check for available ports
./bin/check-ports || handle_error

# Load environment variables from compose/.env
if [ ! -f compose/.env ]; then
  echo "Error: compose/.env file not found."
  handle_error
fi

set -a
source compose/.env
set +a

# Check if the src folder already exists
if [ -d "src" ]; then
  echo "Directory src already exists."
  read -p "Do you want to delete the existing src folder and create a new project? (y/n): " choice
  if [ "$choice" == "y" ]; then
    sudo rm -rf src
    mkdir -p src

    # Change ownership of src directory to current user
    sudo chown -R $USER:$USER src

    # Grant write permissions to src directory
    sudo chmod -R 775 src

    # Navigate into the src directory
    cd src

    # Create Laravel project using Docker
    docker run --rm -u $(id -u):$(id -g) -v $(pwd):/app composer create-project --prefer-dist laravel/laravel . || handle_error

    # Navigate back to the project root directory
    cd ..

    # Change ownership of src directory to current user
    sudo chown -R $USER:$USER src

    # Grant write permissions to src directory
    sudo chmod -R 775 src

  else
    echo "Skipping project installation."
  fi
else
  # Create directory for the Laravel project
  mkdir -p src

  # Change ownership of src directory to current user
  sudo chown -R $USER:$USER src

  # Grant write permissions to src directory
  sudo chmod -R 775 src

  # Navigate into the src directory
  cd src

  # Create Laravel project using Docker
  docker run --rm -u $(id -u):$(id -g) -v $(pwd):/app composer create-project --prefer-dist laravel/laravel . || handle_error

  # Navigate back to the project root directory
  cd ..

  # Change ownership of src directory to current user
  sudo chown -R $USER:$USER src

  # Grant write permissions to src directory
  sudo chmod -R 775 src
fi

# Create the docker-compose template file dynamically
mkdir -p compose
cat <<EOF > compose/docker-compose.yml
version: '3.8'

services:
  app:
    build:
      context: ..
      dockerfile: ./Dockerfile
    container_name: laravel_app
    restart: unless-stopped
    working_dir: /var/www/html
    volumes:
      - ../:/var/www/html
      - ../docker/php/local.ini:/usr/local/etc/php/conf.d/local.ini
    depends_on:
      - db
    networks:
      - laravel
    command: >
      sh -c "php-fpm"

  web:
    image: nginx:alpine
    container_name: laravel_web
    restart: unless-stopped
    ports:
      - "\$WEB_PORT:80"
    volumes:
      - ../:/var/www/html
      - ../docker/nginx/conf.d:/etc/nginx/conf.d
    depends_on:
      - app
    networks:
      - laravel

  db:
    image: mysql:8.0
    container_name: laravel_db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: \$DB_ROOT_PASSWORD
      MYSQL_DATABASE: \$DB_DATABASE
      MYSQL_USER: \$DB_USERNAME
      MYSQL_PASSWORD: \$DB_PASSWORD
    volumes:
      - dbdata:/var/lib/mysql
    ports:
      - "\$DB_PORT:3306"
    networks:
      - laravel

networks:
  laravel:
    driver: bridge

volumes:
  dbdata:
EOF

# Copy the example environment file and update the environment variables
if [ ! -f src/.env ]; then
  cp src/.env.example src/.env || handle_error
fi

# Ensure the .env file has write permissions for the current user
sudo chmod 777 src/.env

# Disable BuildKit for Docker
unset DOCKER_BUILDKIT

# Build and start the Docker containers
docker-compose -f compose/docker-compose.yml up --build -d || handle_error

# Set permissions from within the container
docker-compose -f compose/docker-compose.yml exec -u root app sh -c "chown -R www-data:www-data /var/www/html/src && chmod -R 775 /var/www/html/src/storage && chmod -R 775 /var/www/html/src/bootstrap/cache" || handle_error

# Laravel Configuration
laravel_configure || handle_error

# Generate application key
run_artisan "key:generate" || handle_error

echo "Setup complete. Your Laravel application is now running."
echo "You can access it at http://${DOMAIN}:${WEB_PORT}"