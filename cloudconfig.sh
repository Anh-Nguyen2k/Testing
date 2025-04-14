#!/bin/bash -ex

# sudo sh -c "$(curl -s https://raw.githubusercontent.com/cirrascalecloudservices/install/main/install-cuda.sh)"

. /etc/os-release

systemctl set-default multi-user.target

# https://developer.nvidia.com/cuda-toolkit-archive
arch=x86_64
distro=ubuntu$(echo "$VERSION_ID" | tr -d .)

LATEST_CUDA_DRIVER=$(curl -s https://developer.download.nvidia.com/compute/cuda/repos/"$distro"/$arch/ | grep -oP 'nvidia-driver-\K[0-9]+' | sort -n | tail -n 1)

# Variable to store lspci output
lspci_output=$(lspci -n)



# https://forums.developer.nvidia.com/t/notice-cuda-linux-repository-key-rotation/212772
# https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#network-repo-installation-for-ubuntu
dpkg -i $(basename $(curl -s -w "%{url_effective}" https://developer.download.nvidia.com/compute/cuda/repos/"$distro"/$arch/cuda-keyring_1.1-1_all.deb -O)) && apt-get update -y

# install kernel headers
apt-get install -y linux-headers-$(uname -r)

# install cuda library
if [ "$CUDA" ]; then
	apt-get install -y cuda-toolkit-"$CUDA" -y && apt-mark hold cuda-toolkit-"$CUDA"
else
	apt-get install -y cuda-toolkit -y && apt-mark hold cuda-toolkit
fi

# install nvidia open driver
if [ "$CUDA_DRIVER" ]; then
	apt install -y nvidia-driver-"$CUDA_DRIVER"-open nvidia-modprobe && apt-mark hold nvidia-driver-"$CUDA_DRIVER"-open
else
	CUDA_DRIVER=$LATEST_CUDA_DRIVER
	apt install -y nvidia-driver-"$CUDA_DRIVER"-open nvidia-modprobe && apt-mark hold nvidia-driver-"$CUDA_DRIVER"-open
fi

# install fabricmanager for nvswitch systems
#if check_nvswitch; then
		#apt-get install -y nvidia-fabricmanager-"$CUDA_DRIVER" -y && apt-mark hold nvidia-fabricmanager-"$CUDA_DRIVER"
		#systemctl enable nvidia-fabricmanager.service --now
#fi

# install nvlsm for Gen5 nvlink systems
#if check_nvl5; then
#	apt-get install -y nvlsm -y && apt-mark hold nvlsm
#fi

# install cudnn
if [ "$CUDNN" ]; then
	apt-get install -y libcudnn9-cuda-12="$CUDNN" libcudnn9-dev-cuda-12="$CUDNN" -y && apt-mark hold libcudnn9-cuda-12 libcudnn9-dev-cuda-12
else
	apt-get install -y libcudnn9-cuda-12 libcudnn9-dev-cuda-12 -y && apt-mark hold libcudnn9-cuda-12 libcudnn9-dev-cuda-12
fi

# install nccl
if [ "$NCCL" ]; then
	apt-get install -y libnccl2="$NCCL" libnccl-dev="$NCCL" && apt-mark hold libnccl2 libnccl-dev
else
	apt-get install -y libnccl2 libnccl-dev && apt-mark hold libnccl2 libnccl-dev
fi

# enable persistence (keeps GPUs initialized)
systemctl enable nvidia-persistenced.service

# load nvidia-peermem module (enables RDMA GPU support)
echo "nvidia-peermem" | tee -a /etc/modules

# https://docs.nvidia.com/cuda/cuda-quick-start-guide/index.html#debian-x86_64-deb
cat > /etc/profile.d/cirrascale-cuda.sh << 'EOF'
export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
EOF

# prevent auto-upgrades from upgrading cuda and nvidia software
tee -a /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Package-Blacklist {"nvidia";"cuda";"libnvidia";"libcudnn";"libnccl";"nvlsm";};  
EOF