FROM php:8.3-apache

# Install and enable mysqli for MySQL connectivity
RUN docker-php-ext-install mysqli && docker-php-ext-enable mysqli

# Enable Apache rewrite module
RUN a2enmod rewrite

# Increase upload sizes for video analysis
RUN echo "upload_max_filesize = 128M" > /usr/local/etc/php/conf.d/uploads.ini && \
    echo "post_max_size = 128M" >> /usr/local/etc/php/conf.d/uploads.ini && \
    echo "memory_limit = 256M" >> /usr/local/etc/php/conf.d/uploads.ini

WORKDIR /var/www/html/reed

