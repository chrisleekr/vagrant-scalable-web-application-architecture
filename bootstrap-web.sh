#!/usr/bin/env bash

VMHOSTNAME=$1
CONSUL_CONFIG=$2
CONSUL_EXTRA_CONFIGS=$3
CONSUL_UI=$4
TIMEZONE="Australia/Melbourne"

echo -e "*** Start $VMHOSTNAME provisioning script"


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

# Enable Ubuntu Firewall and allow SSH, Consul agent and Apache Ports
if [ ! -f /var/log/2_setup_firewall ]
then
	echo -e "==> 2. Setup firewall"
	yes y | sudo ufw enable
	sudo ufw allow 22
	sudo ufw allow 80
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


if [ ! -f /var/log/10_install_dnsmasq ]
then
    echo -e "==> 10. Install and configure dnsmasq"

    sudo apt-get install dnsmasq -y

    sudo cat /vagrant/config/consul-template-files/dnsmasq.conf >> /etc/dnsmasq.conf
    sudo cat /vagrant/config/consul-template-files/resolve.conf > /etc/resolv.conf

    touch /var/log/10_install_dnsmasq
else
    echo -e "==> 10. dnsmasq is already installed and configured"
fi


echo -e "==> 11. Start dnsmasq"
sudo service dnsmasq restart

# Install apache & php
if [ ! -f /var/log/12_install_apache_php_packages ]
then

    echo -e "==> 12. Install apache & php5 packages"
    sudo apt-get -y install apache2 php5 libapache2-mod-php5 php5-mcrypt libapache2-mod-auth-mysql php-pear php5-mysql php-apc php-compat php-date

    touch /var/log/12_install_apache_php_packages

else
    echo -e "==> 12. Apache & php5 packages are already installed"
fi

echo -e "==> 13. Copy apache site configuration files"
sudo rm -rf /etc/apache2/sites-enabled/*
sudo cp /vagrant/config/web-files/000-default /etc/apache2/sites-enabled


echo -e "==> 14. Start apache server"
sudo service apache2 restart

# Setup web files
if [ ! -f /var/www/.setup_completed ]
then
    echo -e "==> 15. Download latest WordPress file and extract to /var/www"

    # get latest WordPress
    cd /var/www
    sudo rm index.html
    wget http://wordpress.org/latest.tar.gz  --quiet
    tar xfz latest.tar.gz
    mv wordpress/* ./
    rmdir ./wordpress/
    rm -f latest.tar.gz

    touch /var/www/.setup_completed
else
    echo -e "==> 15. WordPress is already installed"
fi
