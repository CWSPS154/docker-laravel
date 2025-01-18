# Docker Laravel

## Prerequisites

- Docker
- Docker Compose

## Setup Instructions

1. Clone the repository:
   ```bash
   git clone https://github.com/CWSPS154/docker-laravel.git
   cd docker-laravel
   cp .env.example .env and update your domain and ports
   ```
2. Run the setup script:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   chmod +x bin/*
   ```
3. Access the application:
   - Laravel App: http://localhost:${WEB_PORT}

## Setup Custom Domain

To set up a custom domain with SSL, run the following command:

```bash
./bin/setup-domain your-custom-domain.com
```

Replace your-custom-domain.com with your actual domain name. This will update the Nginx configuration, obtain SSL certificates from Let's Encrypt, and restart the Nginx container.

## Common Commands

- Start the containers:

```bash
./bin/start
```

- Stop the containers:

```bash
./bin/stop
```

- Run Laravel Artisan commands:

```bash
./bin/cli migrate
```

## Troubleshooting

- #### Permission Issues:

  Ensure that the storage and cache directories have the correct permissions:

  ```bash
  ./bin/cli sh -c "chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache"
  ```

- #### Database Connection Issues:
  Verify that the database credentials in the .env file match the settings in compose/docker-compose.yml.
- #### Ensure your user is part of the docker group:
  ```bash
  sudo usermod -aG docker $USER
  newgrp docker
  ```
