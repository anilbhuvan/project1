#! /bin/bash
# Forwarding IPv4 and letting iptables see bridged traffic
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

touch /home/ubuntu/"configured-10%"

# installing go lang
sudo apt-get update -y
sudo snap install go --classic

# install docker
sudo apt-get update -y
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo chmod a+r /etc/apt/keyrings/docker.gpg
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo groupadd docker
sudo usermod -aG docker "$USER"
newgrp docker
sudo swapoff -a
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
touch /docker_update

rm -rf /home/ubuntu/"configured-10%"
touch /home/ubuntu/"configured-35%"

# install and configure CRIls
cd /home/ubuntu
git clone https://github.com/Mirantis/cri-dockerd.git
cat <<EOF > script.sh
#! /bin/bash
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
cd /home/ubuntu
sudo bash script.sh

rm -rf /home/ubuntu/"configured-35%"
touch /home/ubuntu/"configured-75%"

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

touch /kubeadm_update


# installing aws-cli
apt update
apt install unzip -y
apt install curl -y

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install


rm -rf /home/ubuntu/"configured-75%"
touch /home/ubuntu/"configured-95%"

# Retrieve the join command from the Parameter Store in a loop until it succeeds
while true; do
    JOIN_COMMAND=$(aws ssm get-parameter --name "/k8s/join-command" --with-decryption --query "Parameter.Value" --output text --region us-east-1)
    if [ $? -eq 0 ]; then
        eval "$JOIN_COMMAND"
        if [ $? -eq 0 ]; then
            echo "Successfully joined the cluster."
            break
        else
            echo "Failed to join the cluster. Retrying in 5 seconds..."
            sleep 5
        fi
    else
        echo "Failed to retrieve join command. Retrying in 5 seconds..."
        sleep 5
    fi
done

rm -rf /home/ubuntu/"configured-95%"
touch /home/ubuntu/"configured-100%"
