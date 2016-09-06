#!/usr/bin/env bash

VMHOSTNAME=$1
CONSUL_CONFIG=$2
CONSUL_EXTRA_CONFIGS=$3
CONSUL_UI=$4
TIMEZONE="Australia/Melbourne"

echo -e "*** Start $VMHOSTNAME provisioning script"

# Variables
DBNAME=wordpress
DBUSER=root
DBPASSWD=root
DBDIRPATH=/var/lib/mysql_vagrant
if [ $VMHOSTNAME == "db1.local" ]
then 
    DBCONFIG_FILE=/vagrant/config/db-files/my-master1.cnf
else 
    DBCONFIG_FILE=/vagrant/config/db-files/my-master2.cnf
fi 
MASTER1IP=192.168.100.41
MASTER2IP=192.168.100.42
SSH_USER='vagrant'
SSH_PASS='vagrant'
HAPROXYHOST=192.168.100.21


# Update dependencies and upgrade the system
#if [ ! -f /var/log/0_upgrade_system ]
#then
#    echo -e "==> 0. Update dependencies and upgrade the system"
#    echo Updating linux
#    sudo apt-get update && sudo apt-get -y upgrade
#
#	touch /var/log/0_upgrade_system
#else
#    echo -e "==> 0. System upgrade is already done"
#fi

# Set the Server Timezone to Australia/Melbourne
if [ ! -f /var/log/1_setup_timezone ]
then
	echo -e "==> 1. Setting timezone"
	echo $TIMEZONE > /etc/timezone
	sudo dpkg-reconfigure -f noninteractive tzdata

	touch /var/log/1_setup_timezone
else
    echo -e "==> 1. Timezone is already setup"
fi

# Enable Ubuntu Firewall and allow SSH, Consul agent and MySQL Ports
if [ ! -f /var/log/2_setup_firewall ]
then
	echo -e "==> 2. Setup firewall"
	yes y | sudo ufw enable
	sudo ufw allow 22
	sudo ufw allow 3306
	sudo ufw allow 8300/tcp
	sudo ufw allow 8301/tcp
	sudo ufw allow 8301/udp
	sudo ufw allow 8302/tcp
	sudo ufw allow 8302/udp
	sudo ufw allow 8400/tcp
	sudo ufw allow 8500/tcp
	sudo ufw allow 8600/tcp
	sudo ufw allow 53/udp
    sudo ufw status verbose

	touch /var/log/2_setup_firewall
else
    echo -e "==> 2. Firewall is already setup"
fi

# Add consul user
if [ ! -f /var/log/3_setup_consul_user ]
then
    echo -e "==> 3. Add consul user"
    sudo adduser --disabled-password --gecos "" consul

	touch /var/log/3_setup_consul_user
else
    echo -e "==> 3. Consul user is already added"
fi


# Install necessary packages
if [ ! -f /var/log/4_install_packages ]
then
    echo -e "==> 4. Install necessary packages"
    sudo apt-get install -y unzip

    touch /var/log/4_install_packages
else
    echo -e "==> 4. Packages are already installed"
fi

# Copy an upstart script to /etc/init so the Consul agent will be restarted if we restart the virtual machine.
if [ ! -f /var/log/5_copy_upstart_script ]
then
    echo -e "==> 5. Copy a Consul upstart script to /etc/init, so the Consul agent will be restarted if the virtual machine is restarted"
    sudo cp /vagrant/config/common-files/consul-upstart.conf /etc/init/consul.conf

    touch /var/log/5_copy_upstart_script
else
    echo -e "==> 5. The Consul upstart script is already copied"
fi


# Get the Consul Zip file and extract it.
if [ ! -f /var/log/6_install_consul_agent ]
then
    echo -e "==> 6. Get the Consul agent zip file and install it"
    sudo mkdir -p /tmp/consul
    cd /tmp/consul
    sudo wget https://releases.hashicorp.com/consul/0.6.4/consul_0.6.4_linux_amd64.zip -O consul.zip --quiet
    unzip consul.zip
    sudo chmod +x consul
    sudo mv consul /usr/bin/consul

    touch /var/log/6_install_consul_agent
else
    echo -e "==> 6. Consul agent is already installed"
fi


# Make the Consul directory.
if [ ! -f /var/log/7_set_consul_configuration_directory ]
then
    echo -e "==> 7. Create the Consul configuration directory and consul log file"
    sudo mkdir /etc/consul.d
    sudo chmod a+w /etc/consul.d
    sudo mkdir -p /var/consul
    # Set consul user to own /var/consul directory
    sudo chown consul:consul /var/consul
    sudo chmod a+w /var/consul
    # Create empty file /var/log/consul.log
    sudo touch /var/log/consul.log
    sudo chmod 777 /var/log/consul.log

    touch /var/log/7_set_consul_configuration_directory
else
    echo -e "==> 7. Consul configuration directory is already created"
fi


# Copy the server configuration.
echo -e "==> 8. Copy the Consul configurations"
sudo cp $CONSUL_CONFIG /etc/consul.d/config.json
sudo cp $CONSUL_EXTRA_CONFIGS/* /etc/consul.d/
sudo chmod a+wrx $CONSUL_EXTRA_CONFIGS/*.*

# Start Consul agent
echo -e "==> 9. Start Consul agent"
sudo service consul restart


# Install MySQL
if [ ! -f /var/log/10_install_mysql_packages ]
then
    echo -e "==> 10. Install MySQL specific packages and settings - mysql-server mysql-client"
    sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $DBPASSWD"
    sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $DBPASSWD"
    sudo apt-get -y install mysql-server mysql-client

    touch /var/log/10_install_mysql_packages
else
    echo -e "==> 10. MySQL packages are already installed"
fi

# Define a function that returns true once mysql can connect.
mysql_ready() {
    sudo mysqladmin ping --host=localhost --user=$DBUSER --password=$DBPASSWD > /dev/null 2>&1
}


# setup MySQL
if [ ! -f /var/log/11_setup_mysql ]
then
    echo -e "==> 11. Setup MySQL server"

    # Move initial database file to persistent directory
    echo -e "==> 11-1. Move initial database file to persistent directory"
	# Stop MySQL server
	sudo service mysql stop

    # Set ownership mysql to DB data path
	sudo chown -R mysql:mysql $DBDIRPATH
	# Delete all files in DB data path
	sudo rm -rf $DBDIRPATH/*
	# Copy initial database contents to persistent DB data path
	sudo cp -r -p /var/lib/mysql/* $DBDIRPATH

    # Make backup for initial database
	sudo mv /var/lib/mysql /var/lib/mysql.bak

	# Notify AppArmor with new DB data path
	echo "alias /var/lib/mysql/ -> $DBDIRPATH," | sudo tee -a /etc/apparmor.d/tunables/alias
	# Reload apparmor
	sudo /etc/init.d/apparmor reload

    # Copy database config file to MySQL configuration folder
	sudo cp $DBCONFIG_FILE /etc/mysql/conf.d/my_override.cnf

	# Restart MySQL
	sudo service mysql start

    CHECK_CNT=1
    MAX_CHECK_TRY=5
    while !(mysql_ready)
    do
       sleep 10s
       echo -e "==> 11-2. ($CHECK_CNT/$MAX_CHECK_TRY) Waiting for MySQL Connection... Check again after 10 secs..."
       CHECK_CNT=$(($CHECK_CNT+1))
       if [ $CHECK_CNT == $MAX_CHECK_TRY ]
       then
            echo -e "==> 11.2 Cannot connect MySQL. Something went wrong. Access the instance and check the log"
            exit -1
       fi
    done
    echo -e "==> 11-3. MySQL is connected. Proceed to next step"

	echo -e "==> 11-4. Setting up MySQL DB and root user"
	sudo mysql -uroot -p$DBPASSWD -e "CREATE DATABASE IF NOT EXISTS $DBNAME"
	sudo mysql -uroot -p$DBPASSWD -e "GRANT ALL PRIVILEGES ON $DBNAME.* TO '$DBUSER'@'localhost' IDENTIFIED BY '$DBPASSWD'"

	# Set up root user's host to be accessible from any remote
	echo -e "==> 11-5. Set up root user's host to be accessible from any remote"
	sudo mysql -uroot -p$DBPASSWD -e 'USE mysql; UPDATE `user` SET `Host`="%" WHERE `User`="root" AND `Host`="localhost"; DELETE FROM `user` WHERE `Host` != "%" AND `User`="root"; FLUSH PRIVILEGES;'

	# Create replication user in master machine
	echo -e "==> 11-6. Create replication user"
	mysql -uroot -p$DBPASSWD -e "CREATE USER 'repl'@'%' IDENTIFIED BY 'mysqluser';GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';FLUSH PRIVILEGES;"

	# Create haproxy user in master machine
	echo -e "==> 11-7. Create HAProxy user"
 	mysql -uroot -p$DBPASSWD -e "INSERT INTO mysql.user (Host,User) values ('$HAPROXYHOST','haproxy_check'); FLUSH PRIVILEGES;"
  	mysql -uroot -p$DBPASSWD -e "GRANT ALL PRIVILEGES ON *.* TO 'haproxy_root'@'$HAPROXYHOST' IDENTIFIED BY 'password' WITH GRANT OPTION; FLUSH PRIVILEGES;"
 
    echo -e "==> 11.8 Restart MySQL server"
    sudo service mysql restart

	touch /var/log/11_setup_mysql
else
     echo -e "==> 11. MySQL server is already setup"
    # If already initialized, then just restart MySQL server
    sudo service mysql start

    CHECK_CNT=1
    MAX_CHECK_TRY=5
    while !(mysql_ready)
    do
       sleep 10s
       echo -e "==> 11-1. ($CHECK_CNT/$MAX_CHECK_TRY) Waiting for MySQL Connection... Check again after 10 secs..."
       CHECK_CNT=$(($CHECK_CNT+1))
       if [ $CHECK_CNT == $MAX_CHECK_TRY ]
       then
            echo -e "==> 11.1 Cannot connect MySQL. Something went wrong. Access the instance and check the log"
            exit -1
       fi
    done
    echo -e "==> 11-2. MySQL is connected. Proceed to next step"
fi



if [ ! -f /var/log/12_install_dnsmasq ]
then
    echo -e "==> 12. Install and configure dnsmasq"

    sudo apt-get install dnsmasq -y

    sudo cat /vagrant/config/consul-template-files/dnsmasq.conf >> /etc/dnsmasq.conf
    sudo cat /vagrant/config/consul-template-files/resolve.conf > /etc/resolv.conf

    touch /var/log/12_install_dnsmasq
else
    echo -e "==> 12. dnsmasq is already installed and configured"
fi

echo -e "==> 13. Start dnsmasq"
sudo service dnsmasq restart


# Setup replication for db2.local
if [ $VMHOSTNAME == "db2.local" ]
then
    echo -e "==> 14. Setting up MySQL replication"

    echo -e "==> 14-1. Install sshpass to access SSH to MySQL server 1"
    sudo apt-get install -y sshpass


    # Check slave is up or not
    IS_HOST_AVAILABLE=false
    CHECK_CNT=1
    MAX_CHECK_TRY=5
    while ! $IS_HOST_AVAILABLE
    do
        echo -e "==> 14-2. ($CHECK_CNT/$MAX_CHECK_TRY) Checking MySQL server 1 connection"
        SLAVE_ALIVE=$(ping -s 64 "$MASTER1IP" -c 1 | grep packet | awk '{print $(NF-4)}')
        if [ $SLAVE_ALIVE == "0%" ]
        then
            echo -e "==> 14-2-1. MySQL server 1 is accessible!"

            IS_MYSQL_SETUP=false
            CHECK_CNT2=1
            MAX_CHECK_TRY2=5
            while ! $IS_MYSQL_SETUP
            do
                echo -e "==> 14-2-2. Confirm MySQL is setup or not in MySQL server 1"
                FILE_SETUP_MYSQL=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no $SSH_USER@$MASTER1IP "[ -f /var/log/11_setup_mysql ] && echo \"Found\" || echo \"Not found\"")

                if [ $FILE_SETUP_MYSQL == "Found" ]
                then
                    echo -e "==> 14-2-3. Found MySQL setup file in MySQL server 1. Proceed to next step"
                    IS_MYSQL_SETUP=true
                    IS_HOST_AVAILABLE=true
                else
                    echo -e "==> 14-2-3. MySQL seems not yet configured in MySQL server 1; checking after 10 secs..."

                    sleep 10
                    CHECK_CNT2=$(($CHECK_CNT2+1))
                    if [ $CHECK_CNT2 == $MAX_CHECK_TRY2 ]
                    then
                        echo -e "==> 14-2-4. MySQL server 2 cannot access to server 1. Something went wrong. Please access the instance and check the log..."
                        exit -1
                    fi
                fi
            done
        else
            echo -e "==> 14-2-1. MySQL server 1 is not accessible; checking after 10 secs..."
            sleep 10

            CHECK_CNT=$(($CHECK_CNT+1))
            if [ $CHECK_CNT == $MAX_CHECK_TRY ]
            then
                echo -e "==> 14-2-2. MySQL server 1 seems not yet alive. Something went wrong. Please access the instance and check the log..."
                exit -1
            fi
        fi
    done


    echo -e "==> 14-3. Dump wordpress database from MySQL server 1"
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no $SSH_USER@$MASTER1IP "mysqldump -uroot -p$DBPASSWD --opt wordpress > /vagrant/data/wordpress.sql"

    echo -e "==> 14-4. Import wordpress database to MySQL server 2"
    mysql -uroot -p$DBPASSWD wordpress < /vagrant/data/wordpress.sql

    # Get log file and position from master server 1
    echo -e "==> 14-5. Get current log file and position in MySQL server 1"
    CURRENT_LOGINFO=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no $SSH_USER@$MASTER1IP "mysql -uroot -p$DBPASSWD --execute='SHOW MASTER STATUS' -AN")


    CURRENT_LOG=`echo $CURRENT_LOGINFO | awk '{print $1}'`
    CURRENT_POS=`echo $CURRENT_LOGINFO | awk '{print $2}'`

    echo -e "==> 14-5-1. Got current log file $CURRENT_LOG in MySQL server 1"
    echo -e "==> 14-5-1. Got current log position $CURRENT_POS in MySQL server 1"

    echo -e "==> 14-6. Change master host to MySQL server 1 log file and position in MySQL server 2 machine"
    mysql -uroot -p$DBPASSWD -e "SLAVE STOP;CHANGE MASTER TO MASTER_HOST='$MASTER1IP', MASTER_USER='repl', MASTER_PASSWORD='mysqluser', MASTER_LOG_FILE='$CURRENT_LOG', MASTER_LOG_POS=$CURRENT_POS;START SLAVE;"

    echo -e "==> 14-7. Get current log file and position in MySQL server 2"
    CURRENT_LOGINFO=$(mysql -uroot -p$DBPASSWD --execute='SHOW MASTER STATUS' -AN)
    CURRENT_LOG=`echo $CURRENT_LOGINFO | awk '{print $1}'`
    CURRENT_POS=`echo $CURRENT_LOGINFO | awk '{print $2}'`

    echo -e "==> 14-7-1. Got current log file $CURRENT_LOG in MySQL server 2"
    echo -e "==> 14-7-1. Got current log position $CURRENT_POS in MySQL server 2"

    echo -e "==> 14-8. Change master host to MySQL server 2 log file and position in MySQL server 1 machine"
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no $SSH_USER@$MASTER1IP "mysql -uroot -p$DBPASSWD -e \"SLAVE STOP;CHANGE MASTER TO MASTER_HOST='$MASTER2IP', MASTER_USER='repl', MASTER_PASSWORD='mysqluser', MASTER_LOG_FILE='$CURRENT_LOG', MASTER_LOG_POS=$CURRENT_POS;START SLAVE;\""

    if [ ! -f /var/log/setup_replication_test ]
    then
        echo -e "==> 14-8. Test replication"
        mysql -uroot -p$DBPASSWD -e "USE $DBNAME;CREATE TABLE test_table(id INT NOT NULL AUTO_INCREMENT, PRIMARY KEY(id), username VARCHAR(30) NOT NULL);INSERT INTO test_table (username) VALUES ('foo');INSERT INTO test_table (username) VALUES ('bar');"

        touch /var/log/setup_replication_test
    fi
fi