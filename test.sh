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
WORKDIR="/home/${USER,,}/.nezha-agent"
FILE_PATH="/home/${USER,,}/.s5"

# 检查并创建工作目录和 SOCKS5 目录
mkdir -p "$WORKDIR"
mkdir -p "$FILE_PATH"

###################################################

# SOCKS5 配置
socks5_config() {
    read -p "请输入 socks5 端口号: " SOCKS5_PORT
    read -p "请输入 socks5 用户名: " SOCKS5_USER

    while true; do
        read -p "请输入 socks5 密码（不能包含 @ 和 :）：" SOCKS5_PASS
        echo
        if [[ "$SOCKS5_PASS" == *"@"* || "$SOCKS5_PASS" == *":"* ]]; then
            echo "密码中不能包含 @ 和 : 符号，请重新输入。"
        else
            break
        fi
    done

    cat > ${FILE_PATH}/config.json << EOF
{
  "log": {
    "access": "/dev/null",
    "error": "/dev/null",
    "loglevel": "none"
  },
  "inbounds": [
    {
      "port": "$SOCKS5_PORT",
      "protocol": "socks",
      "tag": "socks",
      "settings": {
        "auth": "password",
        "udp": false,
        "ip": "0.0.0.0",
        "userLevel": 0,
        "accounts": [
          {
            "user": "$SOCKS5_USER",
            "pass": "$SOCKS5_PASS"
          }
        ]
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    }
  ]
}
EOF
}

install_socks5() {
    socks5_config
    if [ ! -e "${FILE_PATH}/s5" ]; then
        curl -L -sS -o "${FILE_PATH}/s5" "https://github.com/eooce/test/releases/download/freebsd/web"
    else
        read -p "socks5 程序已存在，是否重新下载覆盖？(Y/N 回车N)" downsocks5
        downsocks5=${downsocks5^^} # 转换为大写
        if [ "$downsocks5" == "Y" ]; then
            curl -L -sS -o "${FILE_PATH}/s5" "https://github.com/eooce/test/releases/download/freebsd/web"
        else
            echo "使用已存在的 socks5 程序"
        fi
    fi

    if [ -e "${FILE_PATH}/s5" ]; then
        chmod 777 "${FILE_PATH}/s5"
        nohup ${FILE_PATH}/s5 -c ${FILE_PATH}/config.json >/dev/null 2>&1 &
        sleep 2
        pgrep -x "s5" > /dev/null && echo -e "\e[1;32ms5 is running\e[0m" || { echo -e "\e[1;35ms5 is not running, restarting...\e[0m"; pkill -x "s5" && nohup "${FILE_PATH}/s5" -c ${FILE_PATH}/config.json >/dev/null 2>&1 & sleep 2; echo -e "\e[1;32ms5 restarted\e[0m"; }
        CURL_OUTPUT=$(curl -s ip.sb --socks5 $SOCKS5_USER:$SOCKS5_PASS@localhost:$SOCKS5_PORT)
        if [[ $CURL_OUTPUT =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "代理创建成功，返回的 IP 是: $CURL_OUTPUT"
            echo "socks://${SOCKS5_USER}:${SOCKS5_PASS}@${CURL_OUTPUT}:${SOCKS5_PORT}"
        else
            echo "代理创建失败，请检查自己输入的内容。"
        fi
    fi
}

# Hysteria 安装
install_hysteria() {
    read -p "请输入 Hysteria 的监听端口: " HYST_PORT
    read -p "请输入 Hysteria 的密码: " HYST_PASSWORD

    # 下载 Hysteria
    curl -L -o /tmp/hysteria.tar.gz "https://github.com/HyNetwork/hysteria/releases/latest/download/hysteria-linux-amd64.tar.gz"
    mkdir -p /usr/local/bin/hysteria
    tar -zxvf /tmp/hysteria.tar.gz -C /usr/local/bin/hysteria
    mv /usr/local/bin/hysteria/hysteria /usr/local/bin/
    rm -rf /tmp/hysteria.tar.gz

    # 创建配置文件
    cat > /etc/hysteria.yaml <<EOF
server:
  listen: :$HYST_PORT
  allow_insecure: true
  users:
    - username: "user"
      password: "$HYST_PASSWORD"
EOF

    # 启动 Hysteria
    nohup hysteria server -config /etc/hysteria.yaml >/dev/null 2>&1 &
    echo "Hysteria 已启动，监听端口: $HYST_PORT"
}

download_agent() {
    DOWNLOAD_LINK="https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_freebsd_amd64.zip"
    ZIP_FILE="/tmp/nezha-agent.zip"
    if ! wget -qO "$ZIP_FILE" "$DOWNLOAD_LINK"; then
        echo 'error: Download failed! Please check your network or try again.'
        return 1
    fi
    return 0
}

decompression() {
    unzip "$1" -d "$WORKDIR"
    EXIT_CODE=$?
    if [ ${EXIT_CODE} -ne 0 ]; then
        echo "解压失败，请检查文件或权限。"
        exit 1
    fi
}

install_agent() {
    install -m 755 ${WORKDIR}/nezha-agent ${WORKDIR}/nezha-agent
}

generate_run_agent() {
    echo "请输入 Dashboard 站点地址（IP 或域名）："
    read -r NZ_DASHBOARD_SERVER
    echo "请输入面板 RPC 端口："
    read -r NZ_DASHBOARD_PORT
    echo "请输入 Agent 密钥："
    read -r NZ_DASHBOARD_PASSWORD

    cat > ${WORKDIR}/start.sh << EOF
#!/bin/bash
pgrep -f 'nezha-agent' | xargs -r kill
cd ${WORKDIR}
TMPDIR="${WORKDIR}" exec ${WORKDIR}/nezha-agent -s ${NZ_DASHBOARD_SERVER}:${NZ_DASHBOARD_PORT} -p ${NZ_DASHBOARD_PASSWORD} --report-delay 4 --disable-auto-update --disable-force-update >/dev/null 2>&1
EOF
    chmod +x ${WORKDIR}/start.sh
}

run_agent() {
    nohup ${WORKDIR}/start.sh >/dev/null 2>&1 &
    sleep 3
    if pgrep -f "nezha-agent -s" > /dev/null; then
        echo "nezha-agent 已启动！"
    else
        echo "nezha-agent 启动失败，请检查参数填写是否正确。"
    fi
}

install_nezha_agent() {
    mkdir -p ${WORKDIR}
    cd ${WORKDIR}
    TMP_DIRECTORY="$(mktemp -d)"
    ZIP_FILE="${TMP_DIRECTORY}/nezha-agent_freebsd_amd64.zip"

    download_agent && decompression "${ZIP_FILE}" && install_agent
    rm -rf "${TMP_DIRECTORY}"
    run_agent
}

########################梦开始的地方###########################

# 安装 socks5
read -p "是否安装 socks5 (Y/N 回车N): " socks5choice
socks5choice=${socks5choice^^} # 转换为大写
if [ "$socks5choice" == "Y" ]; then
    install_socks5
else
    echo "不安装 socks5"
fi

# 安装 Nezha Agent
read -p "是否安装 nezha-agent (Y/N 回车N): " choice
choice=${choice^^} # 转换为大写
if [ "$choice" == "Y" ]; then
    echo "正在安装 nezha-agent..."
    install_nezha_agent
else
    echo "不安装 nezha-agent"
fi

# 安装 Hysteria
read -p "是否安装 Hysteria (Y/N 回车N): " hysteria_choice
hysteria_choice=${hysteria_choice^^} # 转换为大写
if [ "$hysteria_choice" == "Y" ]; then
    echo "正在安装 Hysteria..."
    install_hysteria
else
    echo "不安装 Hysteria"
fi

# 添加 crontab
read -p "是否添加 crontab 守护进程的计划任务 (Y/N 回车N): " crontabgogogo
crontabgogogo=${crontabgogogo^^} # 转换为大写
if [ "$crontabgogogo" == "Y" ]; then
    echo "添加 crontab 守护进程的计划任务"
    curl -s https://raw.githubusercontent.com/cmliu/socks5-for-serv00/main/check_cron.sh | bash
else
    echo "不添加 crontab 计划任务"
fi

echo "脚本执行完成。致谢：RealNeoMan、k0baya、eooce"
