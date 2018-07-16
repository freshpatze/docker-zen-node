#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

print_status() {
    echo
    echo "## $1"
    echo
}

# Populating Cache
print_status "Populating apt-get cache..."
apt-get update

print_status "Updating zend service..."
cat <<EOF > /etc/systemd/system/zen-node.service
[Unit]
Description=Zen Daemon Container
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=10m
Restart=always
ExecStartPre=-/usr/bin/docker stop zen-node
ExecStartPre=-/usr/bin/docker rm  zen-node
# Always pull the latest docker image
ExecStartPre=/usr/bin/docker pull freshpatze/zend:latest
ExecStart=/usr/bin/docker run --rm --net=host -p 9033:9033 -p 18231:18231 -v /mnt/zen:/mnt/zen --name zen-node freshpatze/zend:latest
[Install]
WantedBy=multi-user.target
EOF

print_status "Updating secnodetracker service..."
cat <<EOF > /etc/systemd/system/zen-secnodetracker.service
[Unit]
Description=Zen Secnodetracker Container
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=10m
Restart=always
ExecStartPre=-/usr/bin/docker stop zen-secnodetracker
ExecStartPre=-/usr/bin/docker rm  zen-secnodetracker
# Always pull the latest docker image
ExecStartPre=/usr/bin/docker pull freshpatze/nodetracker:latest
#ExecStart=/usr/bin/docker run --init --rm --net=host -v /mnt/zen:/mnt/zen --name zen-secnodetracker freshpatze/nodetracker:latest
ExecStart=/usr/bin/docker run --rm --net=host -v /mnt/zen:/mnt/zen --name zen-secnodetracker freshpatze/nodetracker:latest
[Install]
WantedBy=multi-user.target
EOF

print_status "Enabling and starting container services..."
systemctl daemon-reload
systemctl enable zen-node
systemctl restart zen-node

systemctl enable zen-secnodetracker
systemctl restart zen-secnodetracker

print_status "Removing old/unused docker images ..."
  docker rmi $(docker images --filter "dangling=true" -q --no-trunc)

print_status "Waiting for node to fetch params ..."
until docker exec -it zen-node /usr/local/bin/gosu user zen-cli getinfo
do
  echo ".."
  sleep 30
done

print_status "Update finished."
