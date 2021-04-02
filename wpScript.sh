#!/bin/bash

source wpConfig 

# Uing Sourced Arguments 

echo -e "\nTarget Directory is $targetDirectory"
echo -e "\nProjectName is $projectName"
echo -e "\nDatabaseName is $dbName"
echo -e "\nWebURL is $webUrl"
echo -e "\nTarget Repository URL is $repositoryUrl"

# Setting up DB

sudo mysql -u root -pkesc@118 -e "CREATE DATABASE $dbName;"
sudo mysql -u root -pkesc@118 -e "GRANT ALL PRIVILEGES ON $dbName. * TO '$dbUser'@'localhost';"
sudo mysql -u root -pkesc@118 -e "FLUSH PRIVILEGES;"

# Cloning base WP directory from GITHUB in Target Directory

cd $targetDirectory

git clone $repositoryUrl

cd $projectName 

# Setting up base WP 

mv .env.example .env

# Change the webUrl and DB credentials in .env file
sed -i "s/WP_SITEURL=/WP_SITEURL=http:\/\/$webUrl/" .env
sed -i "s/WP_HOME=/WP_HOME=http:\/\/$webUrl/" .env
sed -i "s/DB_USER=/DB_USER=$dbUser/" .env
sed -i "s/DB_PASS=/DB_PASS=$dbPassword/" .env
sed -i "s/DB_NAME=/DB_NAME=$dbName/" .env

# Composer Install
composer install

# vendor/wp-cli/wp-cli/bin/wp core download --path=public
vendor/wp-cli/wp-cli/bin/wp core download --path=public

# If need to assign TargetDirectory ownership to another user
# sudo chown -R cc:www-data $targetDirectory/$projectName

# Setting up NGINX config

# Creating a site-available config for WP setup

echo -e "
server {

    	listen 80;
        server_name $webUrl;
	root $targetDirectory/$projectName/public;
	index index.php index.html index.htm index.nginx-debian.html;

	access_log      /var/log/nginx/$webUrl.access.log;
	error_log       /var/log/nginx/$webUrl.com.error.log;
	client_max_body_size 10240M;
	add_header X-Frame-Options "SAMEORIGIN";
	
	location ~* \.(css|js|ico|gif|jpeg|jpg|webp|png|svg|eot|otf|woff|woff2|ttf|ogg)$ {
		expires max;
		fastcgi_hide_header Set-Cookie;
	}

	location / {
		try_files \$uri \$uri/ /index.php?\$query_string;
	}

	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass unix:/run/php/php7.4-fpm.sock;
	}
	
	location ~ /\.ht {
		deny all;
	}

}" | sudo tee -a /etc/nginx/sites-available/$projectName

# Create symlink
sudo ln -s /etc/nginx/sites-available/$projectName /etc/nginx/sites-enabled/$projectName

# Reload NGINX config
sudo service nginx reload

# Setting up SSL using Certbot
sudo certbot --nginx -n --redirect -d $webUrl
