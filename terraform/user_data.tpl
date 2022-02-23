#!/bin/bash

# Vars
DB_USER=${db_username}
DB_PASSWORD=${db_password}
DB_NAME=${db_name}
DB_HOST=${db_host}
EFS=${efs}
IP=$(curl http://checkip.amazonaws.com)
URL=${url}

# DB_USER="db_admin"
# DB_PASSWORD="db_password"
# DB_NAME="db_wordpress"
# DB_HOST="mysql.cp43es25ty4l.eu-central-1.rds.amazonaws.com:3306"
# EFS="fs-0849437a601d1fdaf"
# IP=$(curl http://checkip.amazonaws.com)
# URL="LoadBalancer-2099297614.eu-central-1.elb.amazonaws.com"



mount_efs(){
	mount -t efs $EFS:/ /var/www/html
	#edit fstab
	cat <<EOF >>/etc/fstab
$EFS:/   /var/www/html   efs   defaults,_netdev  0  0
EOF
}

install_php(){
	# Install php7.4 and imagick
	amazon-linux-extras enable php7.4
	yum clean metadata
	yum install -y php php-{pear,cgi,common,curl,mbstring,gd,mysqlnd,gettext,bcmath,json,xml,fpm,intl,zip,imap,devel} gcc ImageMagick ImageMagick-devel ImageMagick-perl
	yes '' | pecl install imagick
	chmod 755 /usr/lib64/php/modules/imagick.so
	cat <<EOF >>/etc/php.d/20-imagick.ini
extension=imagick
EOF

systemctl restart php-fpm.service
}

install_packages(){
	# Install Apache and efs-utils
	yum update -y
	yum install -y httpd amazon-efs-utils 
}

check_installed_wp(){
	if [ ! -f /var/www/html/wp-config.php ];
	then
		install_wp
	fi
}

install_wp(){
	install_php
	# Download latest version
	find /var/www -type d -exec chmod 2775 {} \;
	find /var/www -type f -exec chmod 0664 {} \;
	curl https://wordpress.org/latest.tar.gz | sudo -u apache tar zx --strip-components=1 -C /var/www/html/
	
	# Create config	
	cd /var/www/html
	cp wp-config-sample.php wp-config.php
	sed -i "s/localhost/${DB_HOST}/g" wp-config.php
	sed -i "s/database_name_here/${DB_NAME}/g" wp-config.php
	sed -i "s/username_here/${DB_USER}/g" wp-config.php
	sed -i "s/password_here/${DB_PASSWORD}/g" wp-config.php
	cat <<EOF >>/var/www/html/wp-config.php
define( 'FS_METHOD', 'direct' );
define('WP_MEMORY_LIMIT', '128M');
EOF

	# Install via cli
	wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -O /usr/local/sbin/wp 
	chmod +x /usr/local/sbin/wp 
	sudo -u apache /usr/local/sbin/wp core install --url=http://${URL} --title='Andrei Shcheglov AWS Task' --admin_user='admin' --admin_password='${DB_PASSWORD}' --admin_email='admin@wp.aws'
	sudo -u apache /usr/local/sbin/wp post create --post_type=post --post_status=publish --post_title="My first post by ${IP}"
}

configure_apache(){
	# Enable .htaccess
	sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride None/AllowOverride all/' /etc/httpd/conf/httpd.conf

	# Enable and restart service
	systemctl enable  httpd.service
	systemctl restart httpd.service
}


start(){
	install_packages
	mount_efs
	check_installed_wp
	configure_apache
}


start
