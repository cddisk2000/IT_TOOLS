!/bin/bash

# 移除舊版 python3.6
echo "=== 移除 python36 ==="
yum remove -y python36

# 安裝 epel-release 與 Python 3.11
echo "=== 安裝 EPEL 與 Python 3.11 ==="
#yum install -y epel-release
yum install -y python3.11

# 安裝開發與編譯套件
echo "=== 安裝 Python 開發相關依賴 ==="
yum install -y python3-devel
yum install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel

# 安裝 pip3.11（含 setuptools）
echo "=== 安裝 pip3.11 ==="
dnf install -y python3.11-pip

# 修改 pip3 鏡像為阿里雲源
echo "=== 配置 pip 鏡像源為阿里雲 ==="
mkdir -p ~/.pip
cat <<EOF > ~/.pip/pip.conf
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/
[install]
trusted-host = mirrors.aliyun.com
EOF

#设置 Python3 软连接
alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 311
alternatives --set python3 /usr/bin/python3.11

# 建立 /usr/bin/python 指向 python3.11
echo "=== 建立 Python3.11 軟連結至 /usr/bin/python ==="
ln -sf /usr/bin/python3.11 /usr/bin/python

echo "=== 安裝與設置完成 ==="
