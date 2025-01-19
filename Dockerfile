# Use the latest official PHP image as the base image
FROM php:8.3-fpm

# Set working directory
WORKDIR /var/www/html

# Install system dependencies
RUN apt-get update && apt-get install -y \
    bash \
    git \
    unzip \
    libpq-dev \
    libicu-dev \
    libzip-dev \
    curl \
    procps \
    libonig-dev \
    libxml2-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
    libgd-dev \
    jpegoptim optipng pngquant gifsicle \
    libwebp-dev \
    xdg-utils \
    links \
    ffmpeg

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-configure gd --enable-gd --with-freetype --with-jpeg --with-webp
RUN docker-php-ext-install pdo pdo_mysql intl zip pcntl exif mbstring bcmath soap gd

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy application source code
COPY . /var/www/html

# Set permissions for Laravel directories
RUN chown -R www-data:www-data /var/www/html/src \
    && chmod -R 775 /var/www/html/src/storage \
    && chmod -R 775 /var/www/html/src/bootstrap/cache

# Change current user to www-data
USER www-data

# Set permissions for Laravel storage and cache folders
RUN chown -R www-data:www-data src/storage src/bootstrap/cache src/.env
RUN chmod -R 775 src/storage src/bootstrap/cache

# Expose port 9000 and start php-fpm server
EXPOSE 9000
CMD ["php-fpm"]