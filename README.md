# vagrant-apache-mysql-scalable-architecture
Vagrantfile to spin up web scalable architecture using Consul, Consul Template, nginx and HAProxy

Note: This project is created for just practice. Not suitable for production use.


# Prerequisites
* Vagrant 1.8.1+: <http://www.vagrantup.com/>
* VirtualBox: <https://www.virtualbox.org/>


# Usage
```
    $ git clone https://github.com/chrisleekr/vagrant-apache-mysql-scalable-architecture.git
    $ vagrant up
```
[![asciicast](https://asciinema.org/a/br2ykgxy76rhim2hfkamca9wl.png?autoplay=1)](https://asciinema.org/a/br2ykgxy76rhim2hfkamca9wl)

After vagrant machines are running, you can connect instances to:
* Consul WEB UI: 192.168.100.11:8500
* Web Load Balancing Machine: 192.168.100.20
* DB Load Balancing Machine: 192.168.100.21

After vagrant halt/suspend, need to run provisioning scripts again to synchronize MySQL from master to slave machine
```
    $ vagrant halt
    $ vagrant up && vagrant provision
```

If having the error message 'The guest additions on this VM do not match the install version of VirtualBox!', then run following command before vagrant up
```
    $ vagrant plugin install vagrant-vbguest
```

# Features
* Launch scalable architecture in single command
* Used Consul to manage server nodes
* Configured web server load balancing with Consul Template + nginx reserve proxy
* Persistent storage for web servers using Vagrant synced folder 
* Configured database server load balancing with Consul Template + HAProxy
* Configured MySQL Two-way Master-Master replication
* Persistent storage for database using Vagrant synced folder

# What to do after launching Vagrant
Once all vagrant instances up, you can access Consul Web UI by opening browser [http://192.168.100.11:8500](http://192.168.100.11:8500). Then you will see services like consul, web-lb, web, db-lb and db. In Nodes section, you will see nodes like consul1, web-lb, web1, db-lb, db1 and so on. If you see services and nodes as following screenshot, then it is successfully up and running. 

![Alt text](/screenshots/1_consul_services.png?raw=true "Consul Web UI - Services")
![Alt text](/screenshots/2_consul_nodes.png?raw=true "Consul Web UI - Nodes")

Now, you can start installing WordPress to test your architecture. Open browser and access to [http://192.168.100.20](http://192.168.100.20). Then you will see WordPress installation screen like below. You can setup WordPress with following information.
```
    Database Name: wordpress
    Username: root
    Password: root
    Database Host: db-lb.service.consul
    Table Prefix: wp_
    Site Title: [Any title you want, e.g. Test Website]
    Username: [Any username you want, e.g. admin]
    Password: [Any password you want]
    Your Email: [Any email you want]
```
![Alt text](/screenshots/3_wordpress_screen1.png?raw=true "WordPress Installation - Language")
![Alt text](/screenshots/4_wordpress_screen2.png?raw=true "WordPress Installation - Database Settings")
![Alt text](/screenshots/5_wordpress_screen3.png?raw=true "WordPress Installation - Site Settings")
![Alt text](/screenshots/6_wordpress_screen4.png?raw=true "WordPress Installation - Success")
![Alt text](/screenshots/7_wordpress_screen5.png?raw=true "WordPress Installation - Login")
![Alt text](/screenshots/8_wordpress_screen6.png?raw=true "WordPress Installation - Dashboard")

After installing WordPress, you can now check server is properly doing load balancing. In the browser, go to [http://192.168.100.20/server.php](http://192.168.100.20/server.php). I added simple PHP script to display web server IP and database hostname. If you see Web Server IP and DB Hostname are changing on refresh, then it is successfully configured.
![Alt text](/screenshots/9_server_load_balancing1.png?raw=true "Server Information")
![Alt text](/screenshots/10_server_load_balancing2.png?raw=true "Server Information")

As this is test environment, you can access DB directly via any MySQL client tool. 
```
    db-lb.local
    Host: 192.168.100.21
    Username: root
    Password: root
    
    db1.local
    Host: 192.168.100.41
    Username: root
    Password: root
    
    db2.local
    Host: 192.168.100.42
    Username: root
    Password: root
``` 
If you see exactly same tables between db1.local and db2.local databases, then replication is successfully configured.
![Alt text](/screenshots/11_mysql_server1.png?raw=true "MySQL Server 1")
![Alt text](/screenshots/12_mysql_server2.png?raw=true "MySQL Server 2")

# Environments

![Alt text](/screenshots/0_vagrant_consu_architecture_diagram.png?raw=true "Vagrant Consul Architecture Diagram")

The Vagrant contains:
* 3 x Consul servers
* 1 x nginx load balancer for web servers
* 3 x Apache web servers
* 1 x HAProxy load balancer
* 2 x MySQL master-master replication servers

*Note* In order to reduce the launching time, 2 x Consul servers are commented as single Consul server will still work well. Consul recommends to launch at least 3 x Consul servers to prevent single point of failures. In addition, 1 x Apache web server is commented to not launch initially.If you would like to test completed architectures, then uncomment VM definitions.

Following list depicts detailed environment configurations for each VM:
* Consul servers
    * Consul 1 - Bootstrap, Web UI
        * Private IP: 192.168.100.11
        * Hostname: consulserver1.local
        * Web UI access URL: [http://192.168.100.11:8500](http://192.168.100.11:8500)
    * Consul 2 
        * Private IP: 192.168.100.12
        * Hostname: consulserver2.local
        * Commented to not launch in initial checkout
    * Consul 3
        * Private IP: 192.168.100.13
        * Hostname: consulserver3.local
        * Commented to not launch in initial checkout
* Web server load balancer
    * Private IP: 192.168.100.20
    * Hostname: web-lb.local
    * Web Access URL: [http://192.168.100.20:80](http://192.168.100.20)
    * Configured with Consul Template and nginx reverse proxy
    * This instance will be access point for internet users.
* Web servers
    * Web server 1 
        * Private IP: 192.168.100.31
        * Hostname: web1.local
        * Configured with Apache web server
        * When the instance is launched, then Consul Template in Web server load balancer will generate new nginx config file.
    * Web server 2
        * Private IP: 192.168.100.32
        * Hostname: web2.local
        * Same as Web server 1
        * Commented to not launch in initial checkout
    * Web server 3
        * Private IP: 192.168.100.33
        * Hostname: web3.local
        * Same as Web server 1
        * Commented to not launch in initial checkout
* Database load balancer
    * Private IP: 192.168.100.21
    * Hostname: db-lb.local
    * Database Access: tcp://192.168.100.21:3306
    * Configured with Consul Template and HAProxy
    * This instance will be access point for web servers to access database.
* Databases
    * Database server 1
        * Private IP: 192.168.100.41
        * Hostname: db1.local
        * This instance is configured Master-Master replication with Database server2.
        * Database Name/Username/Password: wordpress/root/root
        * When the instance is launched, then Consul Template in Database load balancer will generate new HAProxy config file.
    * Database server 2
        * Private IP: 192.168.100.42
        * Hostname: db2.local
        * This instance is configured Master-Master replication with Database server 1.
        * Same as Database server 1

# How it works
*Note* This section is a bit descriptive because I would like to make a note because I was struggling to setup this architecture. I want to make detailed instructions to not make same mistakes when create similar architectures.

1. Consul servers will be launched first.
    1. Consul server 1(consulserver1.local) will be launched and provisioning script will be executed.
    2. Update package list and upgrade system (Currently commented out. If need, uncomment it)
    3. Set the Server Timezone to Australia/Melbourne
    4. Enable Ubuntu Firewall and allow SSH & Consul agent
    5. Add consul user
    6. Install necessary packages
    7. Copy an upstart script to /etc/init so the Consul agent will be restarted if we restart the virtual machine
    8. Get the Consul agent zip file and install it
    9. Consul UI needs to be installed
    10. Create the Consul configuration directory and consul log file
    11. Copy the Consul configurations
    12. Start Consul agent
    13. Consul server 2(consulserver2.local) will be launched and provisioning script will be executed.
    14. Repeat aforementioned steps ii to viii
    15. Create the Consul configuration directory and consul log file
    16. Copy the Consul configurations
    17. Start Consul agent
    18. Consul server 3(consulserver3.local) will be launched and provisioning script will be executed.
    19. Repeat aforementioned steps ii to viii
    20. Create the Consul configuration directory and consul log file
    21. Copy the Consul configurations
    22. Start Consul agent
2. Web load balancer(web-lb.local) will be launched in following.
    1. Repeat aforementioned steps 1-ii to 1-viii
    2. Create the Consul configuration directory and consul log file
    3. Copy the Consul configurations
    4. Start Consul agent
    5. Install and configure dnsmasq
    6. Start dnsmasq
    7. Create consul-template configuration folder and copy nginx.conf template
    8. Install nginx
    9. Download consul-template and copy to /usr/local/bin
    10. Copy an upstart script to /etc/init, so the Consul template and nginx will be restarted if we restart the virtual machine
    11. Start consul-template and nginx will be started via consul-template
3. Web servers will be launched next.
    1. Web server 1(web1.local) will be launched and provisioning script will be executed.
    2. Repeat aforementioned steps 2-i to 2-vi
    3. Install apache & php5 packages
    4. Copy apache site configuration files
    5. Start apache server
    6. Download latest WordPress file and extract to /var/www
    7. Web server 2(web2.local) will be launched and provisioning script will be executed.
    8. Repeat aforementioned steps 3-i to 3-v
    7. Web server 3(web3.local) will be launched and provisioning script will be executed.
    8. Repeat aforementioned steps 3-i to 3-v
4. Database load balancer(db-lb.local) will be launched next.
    1. Repeat aforementioned steps 2-i to 2-vi
    2. Install MySQL packages - mysql-client
    3. Install HAProxy
    4. Create consul-template configuration folder and copy haproxy.conf template
    5. Download consul-template and copy to /usr/local/bin
    6. Copy an upstart script to /etc/init so the Consul template and HAProxy will be restarted if we restart the virtual machine
    7. Start consul-template and HAProxy will be started via consul-template
5. Database servers will be launched next.
    1. Database server 1(db1.local) will be launched and provisioning script will be executed.
    2. Repeat aforementioned steps 2-i to 2-iv
    3. Install MySQL specific packages and settings - mysql-server mysql-client
    4. Setup MySQL server
        * Move initial database file to persistent directory
        * Setting up MySQL DB and root user
        * Set up root user's host to be accessible from any remote
        * Create replication user
        * Create HAProxy user
        * Restart MySQL server
    5. Install and configure dnsmasq
    6. Start dnsmasq
    7. Database server 2(db2.local) will be launched and provisioning script will be executed.
    8. Repeat aforementioned steps 5-i to 5-vi
    9. Setting up MySQL replication, starting with installing sshpass to access SSH to MySQL server 1
    10. Check MySQL server 1 connection
    11. Dump wordpress database from MySQL server 1 to /vagrant/data/wordpress.sql
    12. Import wordpress database to MySQL server 2 from /vagrant/data/wordpress.sql
    13. Get current log file and position in MySQL server 1
    14. Change master host to MySQL server 1, log file and position in MySQL server 2 machine
    15. Get current log file and position in MySQL server 2
    16. Change master host to MySQL server 2, log file and position in MySQL server 1 machine
    17. Test replication by creating table called test_table