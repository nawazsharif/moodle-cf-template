#!/bin/bash
set -e

sudo apt update
# Install PHP 8.2
sudo dpkg -l | grep php | tee packages.txt
sudo add-apt-repository ppa:ondrej/php
sudo apt install php8.2 php8.2-cli mysql-server
sudo apt install php8.2-{gd,mysqli,soap,zip,bz2,curl,mbstring,intl,ldap,fpm,xml,json}

# Secure MySQL installation
sudo mysql_secure_installation


PHP_INI_PATH="/etc/php/8.2/fpm/php.ini"

sudo sed -i "s/^;*post_max_size = .*/post_max_size = 100M/" $PHP_INI_PATH
sudo sed -i "s/^;*upload_max_filesize = .*/upload_max_filesize = 100M/" $PHP_INI_PATH
sudo sed -i "s/^;*max_file_uploads = .*/max_file_uploads = 20/" $PHP_INI_PATH
MAX_INPUT_VARS=5000
sudo sed -i "s/^;*max_input_vars = .*/max_input_vars = $MAX_INPUT_VARS/" $PHP_INI_PATH
sudo systemctl restart php8.2-fpm

# Install Nginx
sudo apt install nginx

# Create Nginx configuration for Moodle
sudo tee /etc/nginx/conf.d/moodle.conf > /dev/null <<EOF
server {
	listen 80;
	listen [::]:80;

	root /var/www/html/moodle;

	# Add index.php to the list if you are using PHP
	index index.php index.html index.htm;

	server_name learning.stage.supermath.id;

	location / {
		try_files $uri $uri/ /index.php?$query_string;
	}

	location = /favicon.ico { access_log off; log_not_found off; }
	location = /robots.txt { access_log off; log_not_found off; }
	error_page 404 /index.php;
	location /dataroot/ {
		internal                   ;
		alias /var/www/moodledata/ ;
	}
	
	location ~ [^/]\.php(/|$) {
		fastcgi_split_path_info  ^(.+\.php)(/.+)$;
		#fastcgi_index            index.php;
		fastcgi_pass unix:/run/php/php-fpm.sock;
		include                  fastcgi_params;
		fastcgi_param   PATH_INFO       $fastcgi_path_info;
		fastcgi_param   SCRIPT_FILENAME $document_root$fastcgi_script_name;
	}
	
	location ~ /\.(?!well-known).* {
		deny all;
	}
	
	location ~ /\.ht {
		deny all;
	}
}
EOF

# Test Nginx configuration and reload
sudo nginx -t
sudo systemctl reload nginx

# Deploy Fresh Moodle
sudo mkdir /var/www/moodledata
sudo chmod -R 777 /var/www/moodledata
cd /var/www/html
sudo git clone https://github.com/moodle/moodle.git

sudo chown -R www-data:www-data /var/www/html/moodle

# Access Moodle Installer via web browser (http://moodle.example.com)
# Follow the Moodle installation wizard to set up your site
