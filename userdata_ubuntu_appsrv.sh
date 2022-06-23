#!/bin/bash

# update the system software
apt-get update
apt-get upgrade -y
# install nginx open source version
apt-get install nginx -y
systemctl enable nginx
systemctl restart nginx

# create the index file 
echo "---" > /var/www/html/index.html
echo "hello, this is from app server" >> /var/www/html/index.html
curl -s ifconfig.me >> /var/www/html/index.html
echo "" >> /var/www/html/index.html
echo "---" >> /var/www/html/index.html

# reboot the instance
sudo reboot

