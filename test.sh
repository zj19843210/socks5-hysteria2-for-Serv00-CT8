#!/bin/bash

# 介绍信息
echo -e "\e[32m
  ____   ___   ____ _  ______ ____  
 / ___| / _ \ / ___| |/ / ___| ___|  
 \___ \| | | | |   | ' /\___ \___ \ 
  ___) | |_| | |___| . \ ___) |__) |           不要直连
 |____/ \___/ \____|_|\_\____/____/            没有售后   
 缝合怪：cmliu 原作者们：RealNeoMan、k0baya、eooce
\e[0m"

# 获取当前用户名
USER=$(whoami)
USER_HOME=$(readlink -f /home/$USER) # 获取标准化的用户主目录
WORKDIR="$USER_HOME/.nezha-agent"
FILE_PATH="$USER_HOME/.s5"
HYSTERIA_WORKDIR="$USER_HOME/.hysteria"

# 创建必要的目录，如果不存在
mkdir -p "$WORKDIR" "$FILE_PATH" "$HYSTERIA_WORKDIR"

# 随机生成密码函数
generate_password() {
    export PASSWORD=${PASSWORD:-$(openssl rand -base64 12)}
}

# 设置服务器端口函数
set_server_port() {
    read -p "请输入服务器端口（默认 20026）： " input_port
    export SERVER_PORT="${input_port:-20026}"
}

# 下载依赖文件函数
download_dependencies() {
    ARCH=$(uname -m)
    DOWNLOAD_DIR="$HYSTERIA_WORKDIR"
    FILE_INFO=()

    if [[ "$ARCH" == "arm" || "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
        FILE_INFO=("https://download.hysteria.network/app/latest/hysteria-freebsd-arm64" "hysteria")
    elif [[ "$ARCH" == "amd64" || "$ARCH" == "x86_64" || "$ARCH" == "x86" ]]; then
        FILE_INFO=("https://download.hysteria.network/app/latest/hysteria-freebsd-amd64" "hysteria")
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
    nohup "$HYSTERIA_WORKDIR/hysteria" server "$HYSTERIA_WORKDIR/config.yaml" >/dev/null 2>&1 &
    sleep 1
    echo -e "\e[1;32mhysteria 正在运行\e[0m"
}

# 获取IP地址函数
get_ip() {
    ipv4=$(curl -s ipv4.ip.sb)
    if [[ -n "$ipv4" ]]; then
        HOST_IP="$ipv4"
    else
        ipv6=$(curl -s --max-time 1 ipv6.ip.sb)
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
    echo -e "\e[1;32mHysteria 安装成功\033[0m"
    echo ""
    echo -e "\e[1;33mV2rayN或Nekobox 配置\033[0m"
    echo -e "\e[1;32mhysteria://$PASSWORD@$HOST_IP:$SERVER_PORT/?sni=www.bing.com&alpn=h3&insecure=1#$ISP\033[0m"
    echo ""
    echo -e "\e[1;33mSurge 配置\033[0m"
    echo -e "\e[1;32m$ISP = hysteria, $HOST_IP, $SERVER_PORT, password = $PASSWORD, skip-cert-verify=true, sni=www.bing.com\033[0m"
    echo ""
    echo -e "\e[1;33mClash 配置\033[0m"
    cat << EOF
- name: $ISP
  type: hysteria
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
    rm -rf "$HYSTERIA_WORKDIR/hysteria" "$HYSTERIA_WORKDIR/config.yaml"
}

# 下载 Nezha Agent
download_agent() {
    DOWNLOAD_LINK="https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_freebsd_amd64.zip"
    if ! wget -qO "$ZIP_FILE" "$DOWNLOAD_LINK"; then
        echo 'error: 下载失败！请检查网络或重试。'
        return 1
    fi
    return 0
}

# 解压缩文件
decompression() {
    unzip "$1" -d "$TMP_DIRECTORY"
    EXIT_CODE=$?
    if [ ${EXIT_CODE} -ne 0 ]; then
        rm -r "$TMP_DIRECTORY"
        echo "已删除临时目录: $TMP_DIRECTORY"
        exit 1
    fi
}

# 安装 Nezha Agent
install_agent() {
    install -m 755 "${TMP_DIRECTORY}/nezha-agent" "${WORKDIR}/nezha-agent"
}

# 生成启动脚本
generate_run_agent() {
    echo "关于接下来需要输入的三个变量，请注意："
    echo "Dashboard 站点地址可以写 IP 也可以写域名（域名不可套 CDN）; 但请不要加上 http:// 或者 https:// 等前缀。"
    echo "面板 RPC 端口为你的 Dashboard 安装时设置的用于 Agent 接入的 RPC 端口（默认 5555）。"
    echo "Agent 密钥需要在管理面板上添加 Agent 后获取。"
    
    read -p "请输入 Dashboard 站点地址： " NZ_DASHBOARD_SERVER
    read -p "请输入面板 RPC 端口： " NZ_DASHBOARD_PORT
    read -p "请输入 Agent 密钥: " NZ_DASHBOARD_PASSWORD
    read -p "是否启用针对 gRPC 端口的 SSL/TLS 加密 (--tls)，需要请按 [Y]，默认是不需要： " NZ_GRPC_PROXY
    echo "${NZ_GRPC_PROXY}" | grep -qiw 'Y' && ARGS='--tls'

    if [ -z "${NZ_DASHBOARD_SERVER}" ] || [ -z "${NZ_DASHBOARD_PASSWORD}" ]; then
        echo "错误！所有选项都不能为空"
        return 1
    fi

    cat > "${WORKDIR}/start.sh" << EOF
#!/bin/bash
pgrep -f 'nezha-agent' | xargs -r kill
cd ${WORKDIR}
TMPDIR="${WORKDIR}" exec ${WORKDIR}/nezha-agent -s ${NZ_DASHBOARD_SERVER}:${NZ_DASHBOARD_PORT} -p ${NZ_DASHBOARD_PASSWORD} --report-delay 4 --disable-auto-update --disable-force-update ${ARGS} >/dev/null 2>&1
EOF
    chmod +x "${WORKDIR}/start.sh"
}

# 运行 Nezha Agent
run_agent() {
    nohup "${WORKDIR}/start.sh" >/dev/null 2>&1 &
    echo "nezha-agent已经准备就绪，请按下回车键启动"
    read
    echo "正在启动 nezha-agent，请耐心等待..."
    sleep 3
    if pgrep -f "nezha-agent -s" > /dev/null; then
        echo "nezha-agent 已启动！"
        echo "如果面板处未上线，请检查参数是否填写正确，并停止 agent 进程，删除已安装的 agent 后重新安装！"
        echo "停止 agent 进程的命令：pgrep -f 'nezha-agent' | xargs -r kill"
        echo "删除已安装的 agent 的命令：rm -rf ~/.nezha-agent"
    else
        rm -rf "${WORKDIR}"
        echo "nezha-agent 启动失败，请检查参数填写是否正确，并重新安装！"
    fi
}

# 安装 Nezha Agent
install_nezha_agent() {
    mkdir -p "${WORKDIR}"
    cd "${WORKDIR}"
    TMP_DIRECTORY="$(mktemp -d)"
    ZIP_FILE="${TMP_DIRECTORY}/nezha-agent_freebsd_amd64.zip"

    if [ ! -e "${WORKDIR}/start.sh" ]; then
        generate_run_agent
    fi

    if [ ! -e "${WORKDIR}/nezha-agent" ]; then
        download_agent \
        && decompression "${ZIP_FILE}" \
        && install_agent
    fi

    rm -rf "${TMP_DIRECTORY}"
    if [ -e "${WORKDIR}/start.sh" ]; then
        run_agent
    fi
}

###################################################

# 主程序
generate_password
set_server_port
get_ip
get_ipinfo
download_dependencies
generate_cert
generate_config
run_files
print_config
install_nezha_agent
cleanup
