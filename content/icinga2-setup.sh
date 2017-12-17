#/bin/bash

/etc/init.d/mysql start

# Icinga2 related Database create and restore schema
echo "Setup Icinga Web 2 database"
mysql -u root -proot <<EOFMYSQL
CREATE DATABASE IF NOT EXISTS icinga2;
GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE VIEW, INDEX, EXECUTE ON icinga2.* TO 'icinga2'@'localhost' IDENTIFIED BY 'icinga2';
FLUSH PRIVILEGES;
EOFMYSQL
mysql -u root -proot icinga2 < /usr/share/icinga2-ido-mysql/schema/mysql.sql

mysql -u root -proot <<EOFMYSQL
CREATE DATABASE IF NOT EXISTS icingaweb2;
GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE VIEW, INDEX, EXECUTE ON icingaweb2.* TO 'icingaweb2'@'localhost' IDENTIFIED BY 'icingaweb2';
EOFMYSQL
mysql -u root -proot icingaweb2 < /usr/share/icingaweb2/etc/schema/mysql.schema.sql

password_hash=$(openssl passwd -1 "icingaadmin")
mysql -u root -proot <<EOFMYSQL
USE icingaweb2;
INSERT IGNORE INTO icingaweb_user (name, active, password_hash) VALUES ('icingaadmin', 1, '$password_hash');
EOFMYSQL

cat > /etc/icinga2/features-available/ido-mysql.conf  <<EOL
library "db_ido_mysql"

object IdoMysqlConnection "ido-mysql" {
  user = "icinga2"
  password = "icinga2"
  host = "localhost"
  database = "icinga2"
}
EOL

cat > /etc/icingaweb2/authentication.ini <<EOL
[icingaweb2]
backend = "db"
resource = "icingaweb_db"
EOL

cat > /etc/icingaweb2/config.ini <<EOL
[global]
show_stacktraces = "1"
config_backend = "db"
config_resource = "icingaweb_db"
module_path = "/etc/icingaweb2/userModules:/usr/share/icingaweb2/modules:/usr/local/share/icingaweb2/modules"

[logging]
log = "syslog"
level = "ERROR"
application = "icingaweb2"
facility = "user"
file = "/var/log/icingaweb2/icingaweb2.log"
EOL

cat > /etc/icingaweb2/groups.ini <<EOL
[icingaweb2]
backend = "db"
resource = "icingaweb_db"
EOL

cat > /etc/icingaweb2/resources.ini <<EOL
[icingaweb_db]
type = "db"
db = "mysql"
host = "localhost"
port = "3306"
dbname = "icingaweb2"
username = "icingaweb2"
password = "icingaweb2"
charset = "utf8"
persistent = "0"
use_ssl = "0"

[icinga_ido]
type = "db"
db = "mysql"
host = "localhost"
port = "3306"
dbname = "icinga2"
username = "icinga2"
password = "icinga2"
charset = "utf8"
persistent = "0"
use_ssl = "0"
EOL

cat > /etc/icingaweb2/roles.ini <<EOL
[Administrators]
users = "admin"
permissions = "*"
groups = "Administrators"
EOL

mkdir /etc/icingaweb2/modules/monitoring
cat > /etc/icingaweb2/modules/monitoring/backends.ini <<EOL
[icinga]
type                = "ido"
resource            = "icinga_ido"
EOL

cat > /etc/icingaweb2/modules/monitoring/commandtransports.ini <<EOL
[icinga]
transport           = "local"
path                = "/var/run/icinga2/cmd/icinga2.cmd"
EOL

cat > /etc/icingaweb2/modules/monitoring/config.ini <<EOL
[security]
protected_customvars = "*pw*,*pass*,community"
EOL

chmod 2770 /etc/icingaweb2
chown -R www-data:icingaweb2 /etc/icingaweb2

# Nginx configurations
mkdir /etc/nginx/default-site
cat /dev/null > /etc/nginx/default-site/icinga.conf
cat >  /etc/nginx/sites-available/default  <<EOL
server {
  listen 80 default;
  include /etc/nginx/default-site/*.conf;

  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log;
}

EOL

cat >  /etc/nginx/default-site/icinga.conf  <<EOL
location ~ ^/icinga/index\.php(.*)$ {
  # fastcgi_pass 127.0.0.1:9000;
  fastcgi_pass unix:/var/run/php/php7.0-fpm.sock;
  fastcgi_index index.php;
  include fastcgi_params;
  fastcgi_param SCRIPT_FILENAME /usr/share/icingaweb2/public/index.php;
  fastcgi_param ICINGAWEB_CONFIGDIR /etc/icingaweb2;
  fastcgi_param REMOTE_USER \$remote_user;
}

location ~ ^/icinga(.+)? {
  alias /usr/share/icingaweb2/public;
  index index.php;
  try_files \$1 \$uri \$uri/ /icinga/index.php\$is_args\$args;
}
EOL

ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

/etc/init.d/nginx restart
icinga2 feature enable ido-mysql command debug 

icingacli module enable setup
icingacli module enable monitoring

chown -R www-data:icingaweb2 enabledModules

if [ ! -f "/etc/icinga2/pki/$(hostname).key" ]; then
	icinga2 node setup --master
fi

icingacli setup config directory --group icingaweb2;

/etc/init.d/icinga2 restart

sed -i -e '$i \/etc/init.d/mysql start\n' /etc/rc.local
sed -i -e '$i \/etc/init.d/nginx start\n' /etc/rc.local
sed -i -e '$i \/etc/init.d/icinga2 start\n' /etc/rc.local
sed -i -e '$i \/etc/init.d/php7.0-fpm start\n' /etc/rc.local
chmod +x /etc/rc.local


