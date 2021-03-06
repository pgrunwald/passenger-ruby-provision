#!/usr/bin/env bash
# Prepare the system
# Add keys for repos
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7
sudo sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger trusty main > /etc/apt/sources.list.d/passenger.list'

sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db && \
sudo add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://ftp.yz.yamagata-u.ac.jp/pub/dbms/mariadb/repo/10.1/ubuntu trusty main'

# add repo for elastic search
wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add - && \
echo "deb http://packages.elastic.co/elasticsearch/2.x/debian stable main" | \
sudo tee -a /etc/apt/sources.list.d/elasticsearch-2.x.list

# Update repos and upgrade
sudo apt-get update
sudo apt-get upgrade -qq

# Set automatic security updates
cat << EOF | sudo tee /etc/apt/apt.conf.d/50unattended-upgrades 
// Automatically upgrade packages from these (origin:archive) pairs
Unattended-Upgrade::Allowed-Origins {
        "\${distro_id}:\${distro_codename}-security";
};
Unattended-Upgrade::Package-Blacklist {};
EOF

cat << EOF | sudo tee /etc/apt/apt.conf.d/*periodic
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Install Packages
sudo apt-get install -y --fix-missing language-pack-en curl gnupg build-essential \
git-core curl zlib1g-dev libssl-dev libreadline-dev \
libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev \
python-software-properties libffi-dev \
apt-transport-https ca-certificates \
nginx-extras passenger git \
mariadb-server libmariadbd-dev imagemagick libgmp3-dev \
openjdk-7-jre elasticsearch \
nodejs && sudo ln -sf /usr/bin/nodejs /usr/local/bin/node

# Install Let's Encrypt helper
git clone https://github.com/letsencrypt/letsencrypt
sudo openssl dhparam -out /etc/nginx/dhparam.pem 2048

# configure elastic search
sudo update-rc.d elasticsearch defaults 95 10
sudo /usr/share/elasticsearch/bin/plugin install analysis-smartcn

# Set proper paths in nginx and restart
PASS_ROOT=`passenger-config --root`
INPUT_USERNAME=`whoami`
sudo sed -i "s,\# passenger_root .*;,passenger_root $PASS_ROOT;,g" /etc/nginx/nginx.conf
sudo sed -i "s,\# passenger_ruby .*,passenger_ruby /home/$INPUT_USERNAME/.rbenv/shims/ruby;,g" /etc/nginx/nginx.conf
sudo sed -i 's,# gzip,gzip,g' /etc/nginx/nginx.conf
sudo service nginx restart

# Update Elasticsearch config to use less memory
sudo sed -i "s,\#*ES_HEAP_SIZE\=.*,ES_HEAP_SIZE=256m,g" /etc/default/elasticsearch
sudo service elasticsearch restart

# Add swap (uncomment for staging, should avoid swap for prod)
#sudo fallocate -l 4G /swapfile && \
#sudo chmod 600 /swapfile && \
#sudo mkswap /swapfile && \
#sudo swapon /swapfile && \
#echo "/swapfile   none    swap    sw    0   0" | sudo tee -a /etc/fstab && \
#echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf && \
#echo "vm.vfs_cache_pressure = 50" | sudo tee -a /etc/sysctl.conf

# Reboot so that upgraded packages come into effect
sudo reboot
