#!/bin/bash

# 介绍信息
{
    echo -e "\e[92m" 
    echo "通往电脑的路不止一条，所有的信息都应该是免费的，打破电脑特权，在电脑上创造艺术和美，计算机将使生活更美好。"
    echo "    ______                   _____               _____         "
    echo "    ___  /_ _____  ____________  /______ ___________(_)______ _"
    echo "    __  __ \\__  / / /__  ___/_  __/_  _ \\__  ___/__  / _  __ \`/"
    echo "    _  / / /_  /_/ / _(__  ) / /_  /  __/_  /    _  /  / /_/ / "
    echo "    /_/ /_/ _\\__, /  /____/  \\__/  \\___/ /_/     /_/   \\__,_/  "
    echo "            /____/                                              "
    echo "                          ______          __________          "
    echo "    ______________ __________  /_____________  ____/         "
    echo "    __  ___/_  __ \\_  ___/__  //_/__  ___/______ \\           "
    echo "    _(__  ) / /_/ // /__  _  ,<   _(__  )  ____/ /        不要直连"
    echo "    /____/  \\____/ \\___/  /_/|_|  /____/  /_____/         没有售后"
    echo "缝合怪：天诚 原作者们：cmliu RealNeoMan、k0baya、eooce"
    echo "Cloudflare优选IP 订阅器，每天定时发布更新。"
    echo "欢迎加入交流群:https://t.me/cncomorg"
    echo -e "\e[0m"  
}

# 获取当前用户名
USER=$(whoami)
USER_HOME=$(readlink -f /home/$USER) # 获取标准化的用户主目录
WORKDIR="$USER_HOME/.nezha-agent"
FILE_PATH="$USER_HOME/.s5"
HYSTERIA_WORKDIR="$USER_HOME/.hysteria"

# 创建必要的目录，如果不存在
[ ! -d "$WORKDIR" ] && mkdir -p "$WORKDIR"
[ ! -d "$FILE_PATH" ] && mkdir -p "$FILE_PATH"
[ ! -d "$HYSTERIA_WORKDIR" ] && mkdir -p "$HYSTERIA_WORKDIR"

###################################################

# 随机生成密码函数
generate_password() {
  export PASSWORD=${PASSWORD:-$(uuidgen)}
}

# 设置服务器端口函数
set_server_port() {
  read -p "请输入 hysteria2 端口 (面板开放的UDP端口,默认 20026）: " input_port
  export SERVER_PORT="${input_port:-20026}"
}

# 下载依赖文件函数
download_dependencies() {
  ARCH=$(uname -m)
  DOWNLOAD_DIR="$HYSTERIA_WORKDIR"
  mkdir -p "$DOWNLOAD_DIR"
  FILE_INFO=()

  if [[ "$ARCH" == "arm" || "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
    FILE_INFO=("https://download.hysteria.network/app/latest/hysteria-freebsd-arm64 web" "https://github.com/eooce/test/releases/download/ARM/swith npm")
  elif [[ "$ARCH" == "amd64" || "$ARCH" == "x86_64" || "$ARCH" == "x86" ]]; then
    FILE_INFO=("https://download.hysteria.network/app/latest/hysteria-freebsd-amd64 web" "https://github.com/eooce/test/releases/download/freebsd/swith npm")
  else
    echo "不支持的架构: $ARCH"
    exit 1
  fi

  for entry in "${FILE_INFO[@]}"; do
    URL=$(echo "$entry" | cut -d ' ' -f 1)
    NEW_FILENAME=$(echo "$entry" | cut -d ' ' -f 2)
    FILENAME="$DOWNLOAD_DIR/$NEW_FILENAME"
    if [[ -e "$FILENAME" ]]; then
      echo -e "\e[1;32m$FILENAME 已存在，跳过下载\e[0m"
    else
      curl -L -sS -o "$FILENAME" "$URL"
      echo -e "\e[1;32m下载 $FILENAME\e[0m"
    fi
    chmod +x "$FILENAME"
  done
  wait
}

# 生成证书函数
generate_cert() {
  openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout "$HYSTERIA_WORKDIR/server.key" -out "$HYSTERIA_WORKDIR/server.crt" -subj "/CN=bing.com" -days 36500
}

# 生成配置文件函数
generate_config() {
  cat << EOF > "$HYSTERIA_WORKDIR/config.yaml"
listen: :$SERVER_PORT

tls:
  cert: $HYSTERIA_WORKDIR/server.crt
  key: $HYSTERIA_WORKDIR/server.key

auth:
  type: password
  password: "$PASSWORD"

fastOpen: true

masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true

transport:
  udp:
    hopInterval: 30s
EOF
}

# 运行下载的文件函数
run_files() {
  if [[ -e "$HYSTERIA_WORKDIR/web" ]]; then
    nohup "$HYSTERIA_WORKDIR/web" server "$HYSTERIA_WORKDIR/config.yaml" >/dev/null 2>&1 &
    sleep 1
    echo -e "\e[1;32mweb 正在运行\e[0m"
  fi
}

# 获取IP地址函数
get_ip() {
  ipv4=$(curl -s 4.ipw.cn)
  if [[ -n "$ipv4" ]]; then
    HOST_IP="$ipv4"
  else
    ipv6=$(curl -s --max-time 1 6.ipw.cn)
    if [[ -n "$ipv6" ]]; then
      HOST_IP="$ipv6"
    else
      echo -e "\e[1;35m无法获取IPv4或IPv6地址\033[0m"
      exit 1
    fi
  fi
  echo -e "\e[1;32m本机IP: $HOST_IP\033[0m"
}

# 获取网络信息函数
get_ipinfo() {
  ISP=$(curl -s https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18}' | sed -e 's/ /_/g')
}

# 输出配置函数
print_config() {
  echo -e "\e[1;32mHysteria2 安装成功\033[0m"
  echo ""
  echo -e "\e[1;33mV2rayN或Nekobox 配置\033[0m"
  echo -e "\e[1;32mhysteria2://$PASSWORD@$HOST_IP:$SERVER_PORT/?sni=www.bing.com&alpn=h3&insecure=1#$ISP\033[0m"
  echo ""
  echo -e "\e[1;33mSurge 配置\033[0m"
  echo -e "\e[1;32m$ISP = hysteria2, $HOST_IP, $SERVER_PORT, password = $PASSWORD, skip-cert-verify=true, sni=www.bing.com\033[0m"
  echo ""
  echo -e "\e[1;33mClash 配置\033[0m"
  cat << EOF
- name: $ISP
  type: hysteria2
  server: $HOST_IP
  port: $SERVER_PORT
  password: $PASSWORD
  alpn:
    - h3
  sni: www.bing.com
  skip-cert-verify: true
  fast-open: true
EOF
}

# 删除临时文件函数
cleanup() {
  rm -rf "$HYSTERIA_WORKDIR/web" "$HYSTERIA_WORKDIR/config.yaml"
}

# 安装 Hysteria
install_hysteria() {
  generate_password
  set_server_port
  download_dependencies
  generate_cert
  generate_config
  run_files
  get_ip
  get_ipinfo
  print_config
}

# 安装和配置 socks5
socks5_config(){
  # 提示用户输入 socks5 端口号
  read -p "请输入 socks5 端口 (面板开放的TCP端口): " SOCKS5_PORT

  # 提示用户输入用户名和密码
  read -p "请输入 socks5 用户名: " SOCKS5_USER

  while true; do
    read -p "请输入 socks5 密码（不能包含@和:）：" SOCKS5_PASS
    echo
    if [[ "$SOCKS5_PASS" == *"@"* || "$SOCKS5_PASS" == *":"* ]]; then
      echo -e "\e[1;31m密码不能包含 @ 和 : \e[0m"
    else
      break
    fi
  done

  # 创建 Socks5 配置文件
  cat << EOF > /etc/socks5-config.json
{
  "log": {
    "level": "info"
  },
  "server": "0.0.0.0",
  "port": $SOCKS5_PORT,
  "user": "$SOCKS5_USER",
  "pass": "$SOCKS5_PASS"
}
EOF

  # crontab 设置
  add_crontab_task

  echo -e "\e[1;32mSocks5 配置文件生成完毕，Socks5 服务将于 5 秒后启动...\e[0m"
  sleep 5
}

# 添加 crontab 守护进程任务
add_crontab_task() {
  echo -e "\e[1;32m正在下载 crtest.sh 脚本...\e[0m"
  curl -L -sS -o /tmp/crtest.sh "https://raw.githubusercontent.com/gshtwy/socks5-hysteria2-for-Serv00-CT8/main/crtest.sh"
  if [[ $? -eq 0 ]]; then
    echo -e "\e[1;32mcrtest.sh 脚本下载完成\e[0m"
    chmod +x /tmp/crtest.sh
    /tmp/crtest.sh
    echo -e "\e[1;32mCrontab 任务添加完成\e[0m"
  else
    echo -e "\e[1;31mcrtest.sh 脚本下载失败，请检查网络连接。\e[0m"
  fi
}

# 安装和配置 Nezha Agent
install_nezha_agent() {
  echo -e "\e[1;32m开始安装 Nezha Agent...\e[0m"

  # 下载 Nezha Agent
  curl -L -sS -o /tmp/nezha-agent-linux-amd64.tar.gz "https://github.com/naiba/nezha/releases/download/v1.2.4/nezha-agent-linux-amd64.tar.gz"
  if [[ $? -eq 0 ]]; then
    echo -e "\e[1;32mNezha Agent 下载完成\e[0m"
    tar -xzf /tmp/nezha-agent-linux-amd64.tar.gz -C /tmp
    mv /tmp/nezha-agent /usr/local/bin/
    rm -rf /tmp/nezha-agent-linux-amd64.tar.gz
  else
    echo -e "\e[1;31mNezha Agent 下载失败，请检查网络连接。\e[0m"
    exit 1
  fi

  # 创建配置文件
  read -p "请输入 Nezha Server 地址: " NEZHA_SERVER
  read -p "请输入 Nezha Server Key: " NEZHA_KEY

  cat << EOF > /etc/nezha-agent/nezha-agent.yaml
server: $NEZHA_SERVER
key: $NEZHA_KEY
EOF

  # 配置服务
  cat << EOF > /etc/systemd/system/nezha-agent.service
[Unit]
Description=Nezha Agent
After=network.target

[Service]
ExecStart=/usr/local/bin/nezha-agent -c /etc/nezha-agent/nezha-agent.yaml
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

  # 启动服务
  systemctl daemon-reload
  systemctl enable nezha-agent
  systemctl start nezha-agent

  echo -e "\e[1;32mNezha Agent 安装完成，服务已启动。\e[0m"
}

# 选择操作
echo "选择操作:"
echo "1. 安装 Hysteria"
echo "2. 配置 Socks5"
echo "3. 安装 Nezha Agent"
read -p "请输入操作编号 (1/2/3): " choice

case $choice in
  1)
    install_hysteria
    ;;
  2)
    socks5_config
    ;;
  3)
    install_nezha_agent
    ;;
  *)
    echo -e "\e[1;31m无效的选择，请重新运行脚本。\e[0m"
    exit 1
    ;;
esac
