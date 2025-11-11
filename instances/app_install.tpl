#!/bin/bash

DB_ADDRESS="${DB_ADDRESS}"
DB_USERNAME="${DB_USERNAME}"
DB_PASSWORD="${DB_PASSWORD}"

SWAPFILE="/swapfile"
SIZE="1G"
TOMCAT_VERSION="10.1.48"

fallocate -l $SIZE $SWAPFILE
chmod 600 $SWAPFILE
mkswap $SWAPFILE
swapon $SWAPFILE
echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab

apt update
apt install -y nodejs npm
mkdir -p /home/ubuntu/my-app/views
chown -RH ubuntu: /home/ubuntu/my-app/
cd /home/ubuntu/my-app

until [ -f /home/ubuntu/my-app/views/index.ejs ]; do
  echo "Wait until the file transfer is complete"
  sleep 10
done

cat >.env <<EOF
# 이 파일의 이름을 .env 로 변경한 후, 실제 AWS RDS 정보를 입력하세요.

# 1. RDS 엔드포인트 (예: tf-project-db.xxxxxxxx.ap-northeast-2.rds.amazonaws.com)
DB_HOST=${DB_ADDRESS}

# 2. RDS 마스터 사용자 이름 (예: admin)
DB_USER=${DB_USERNAME}

# 3. RDS 마스터 비밀번호 (예: your-strong-password)
DB_PASSWORD=${DB_PASSWORD}

# 4. RDS에서 설정한 데이터베이스 이름 (예: myappdb)
DB_NAME=myappdb
EOF

npm install
npm run setup

npm install pm2 -g

sudo -i -u ubuntu bash << 'EOF'
cd /home/ubuntu/my-app
pm2 start server.js
sudo pm2 startup systemd -u ubuntu --hp /home/ubuntu
pm2 save
EOF