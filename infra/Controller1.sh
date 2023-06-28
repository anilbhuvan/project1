#! /bin/bash

#system info
#AMI NAME= ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20220912

# changing hostname
sudo hostnamectl hostname k8s-controller

# Forwarded IPv4 and enabled iptables to see bridged traffic
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# configured sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

# installing go lang
sudo apt-get update -y
sudo snap install go --classic

#  Docker Installation
# Removing Confliting packages
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done

# download all the debian packages from docker website
wget --directory-prefix=/home/ubuntu/docker_packages \
https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/containerd.io_1.6.9-1_amd64.deb \
https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/docker-buildx-plugin_0.10.5-1~ubuntu.22.04~jammy_amd64.deb \
https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/docker-ce-cli_24.0.2-1~ubuntu.22.04~jammy_amd64.deb \
https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/docker-ce_24.0.2-1~ubuntu.22.04~jammy_amd64.deb \
https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/docker-compose-plugin_2.6.0~ubuntu-jammy_amd64.deb 

# install all the .deb docker packages
sudo dpkg -i /home/ubuntu/docker_packages/containerd.io_1.6.9-1_amd64.deb \
/home/ubuntu/docker_packages/docker-ce_24.0.2-1~ubuntu.22.04~jammy_amd64.deb \
/home/ubuntu/docker_packages/docker-ce-cli_24.0.2-1~ubuntu.22.04~jammy_amd64.deb \
/home/ubuntu/docker_packages/docker-buildx-plugin_0.10.5-1~ubuntu.22.04~jammy_amd64.deb \
/home/ubuntu/docker_packages/docker-compose-plugin_2.6.0~ubuntu-jammy_amd64.deb

sudo service docker start

# Configure Docker to start on boot with systemd
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# Installing CRI-dockerd
cat <<'EOF' > /home/ubuntu/install.sh
cd /home/ubuntu
git clone https://github.com/Mirantis/cri-dockerd.git
cd cri-dockerd
mkdir bin
go build -o bin/cri-dockerd
mkdir -p /usr/local/bin
install -o root -g root -m 0755 bin/cri-dockerd /usr/local/bin/cri-dockerd
cp -a packaging/systemd/* /etc/systemd/system
sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service
systemctl daemon-reload
systemctl enable cri-docker.service
systemctl enable --now cri-docker.socket
EOF
chmod +x /home/ubuntu/install.sh
sudo bash /home/ubuntu/install.sh

# Installing kubeadm, kubelet and kubectl
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl restart kubelet
sudo systemctl daemon-reload

export KUBECONFIG=/etc/kubernetes/admin.conf

sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket=unix:///var/run/cri-dockerd.sock

# kubernetes configuration after creating cluster
sudo mkdir /home/ubuntu/.kube
sudo chown ubuntu:ubuntu /home/ubuntu/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

# configuring calico network-plugin
cd /home/ubuntu
sudo curl https://raw.githubusercontent.com/projectcalico/calico/v3.24.5/manifests/calico.yaml -O
kubectl apply -f /home/ubuntu/calico.yaml

# printing join command to a file.
sudo kubeadm token create --print-join-command | tee /home/ubuntu/join_command.txt
sed -i 's|kubeadm|sudo kubeadm|' /home/ubuntu/join_command.txt
sed -i 's|--token|--cri-socket=unix:///var/run/cri-dockerd.sock --token|' /home/ubuntu/join_command.txt

# creating readme file
cat <<EOF > READ_ME.txt
Configuration completed 100%
- HostName changed
- Forwarded IPv4 and enabled iptables to see bridged traffic
- configured sysctl params required by setup, params persist across reboots
- Installed Go lang
- Installed Docker
- Enabled Docker
- Installed CRI-Dockerd
- Installed kubeadm, kubelet and kubectl
- Initilized Kubernetes Cluster
- Configured Kubernetes Cluster
- Downloaded Calico network plugin
- configured Calico network plugin
- Printed join command and saved at /home/ubuntu/join_command.txt

To add worker nodes to this cluster, SSH into the worker node and run join_command.txt as a command
Two EC2 Instances were already created and configured in your AWS, Use them as worker nodes.
.
.
.
EOF


# installing aws-cli
sudo apt install python3-pip -y
pip3 install awscli --upgrade --user
echo 'export PATH=/home/ubuntu/.local/bin:$PATH' >> ~/.bashrc
source ~/.bashrc


JOIN_COMMAND=$(cat /home/ubuntu/join_command.txt) && aws ssm put-parameter --name "/k8s/join-command" --type "SecureString" --value "$JOIN_COMMAND" --region us-east-1


touch /home/ubuntu/"configured-100%"









