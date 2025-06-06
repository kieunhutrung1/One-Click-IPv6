#!/bin/sh

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        # freedesktop.org and systemd
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        # linuxbase.org
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        # For some versions of Debian/Ubuntu without lsb_release command
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        # Older Debian/Ubuntu/etc.
        OS=Debian
        VER=$(cat /etc/debian_version)
    else
        # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
        OS=$(uname -s)
        VER=$(uname -r)
    fi

    # Convert to lowercase
    OS=$(echo "$OS" | tr '[:upper:]' '[:lower:]')
}

install_dependencies() {
    echo "Installing dependencies..."
    if echo "$OS" | grep -iq "ubuntu\|debian"; then
        apt-get update -y
        apt-get install -y gcc net-tools zip wget make build-essential git curl
    else
        yum -y install gcc net-tools zip wget make git curl
    fi
}

random() {
	tr </dev/urandom -dc A-Za-z0-9 | head -c5
	echo
}

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
gen64() {
	ip64() {
		echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
	}
	echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

install_3proxy() {
    echo "Installing 3proxy"
    if echo "$OS" | grep -iq "ubuntu\|debian"; then
        # Use apt for Ubuntu/Debian
        apt-get --assume-yes update
        apt-get --assume-yes install build-essential git
    else
        # Use yum for CentOS/RHEL
        yum -y install build-essential git
    fi
    
    # Common installation steps for all OS types
    cd $WORKDIR
    git clone https://github.com/z3apa3a/3proxy
    cd 3proxy
    ln -s Makefile.Linux Makefile
    make
    make install
    
    # Make directory if it doesn't exist
    mkdir -p /etc/3proxy/conf/
    
    # Set permissions
    chmod 755 /etc/3proxy/conf/add3proxyuser.sh 2>/dev/null || true
    
    # Configure 3proxy
    mkdir -p /usr/local/3proxy/conf/
    cd /usr/local/3proxy/conf/
    rm -f 3proxy.cfg
    curl -X GET "https://raw.githubusercontent.com/h1777/3proxy-socks/refs/heads/master/3proxy.cfg" -H "accept: application/json" --output 3proxy.cfg
    chmod 755 /usr/local/3proxy/conf/3proxy.cfg
    
    # Handle service installation based on OS
    if echo "$OS" | grep -iq "ubuntu\|debian"; then
        # Use systemd for Ubuntu/Debian
        cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/3proxy /usr/local/3proxy/conf/3proxy.cfg
Restart=always

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable 3proxy
    else
        # Use init.d for CentOS/RHEL
        cat > /etc/init.d/3proxy <<EOF
#!/bin/sh
#
# chkconfig: 2345 20 80
# description: 3proxy tiny proxy server
#
# processname: 3proxy
# pidfile: /var/run/3proxy.pid
# config: /usr/local/3proxy/conf/3proxy.cfg

# Source function library.
. /etc/rc.d/init.d/functions

DAEMON=/usr/local/bin/3proxy
CONFIG=/usr/local/3proxy/conf/3proxy.cfg
PIDFILE=/var/run/3proxy.pid

case "\$1" in
start)
    echo -n "Starting 3proxy: "
    daemon "\$DAEMON \$CONFIG"
    echo
    touch /var/lock/subsys/3proxy
    ;;
stop)
    echo -n "Shutting down 3proxy: "
    killproc 3proxy
    echo
    rm -f /var/lock/subsys/3proxy
    ;;
restart)
    \$0 stop
    \$0 start
    ;;
status)
    status 3proxy
    ;;
*)
    echo "Usage: \$0 {start|stop|restart|status}"
    exit 1
esac
exit 0
EOF
        chmod +x /etc/init.d/3proxy
        chkconfig 3proxy on
    fi
    
    cd $WORKDIR
}

gen_3proxy() {
    # Custom 3proxy configuration for our proxies
    cat <<EOF
daemon
maxconn 1000
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
flush
auth strong

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDATA})

$(awk -F "/" '{print "auth strong\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

upload_proxy() {
    local PASS=$(random)
    zip --password $PASS proxy.zip proxy.txt
    URL=$(curl -s --upload-file proxy.zip https://bashupload.com/proxy.zip)

    echo "Proxy is ready! Format IP:PORT:LOGIN:PASS"
    echo "Download zip archive from: ${URL}"
    echo "Password: ${PASS}"
}

gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "usr$(random)/pass$(random)/$IP4/$port/$(gen64 $IP6)"
    done
}

gen_iptables() {
    cat <<EOF
    $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}

# Main script execution
detect_os
echo "Detected OS: $OS $VER"

install_dependencies

echo "working folder = /home/proxy-installer"
WORKDIR="/home/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR && cd $_

install_3proxy

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal ip = ${IP4}. External sub for ip6 = ${IP6}"

echo "How many proxy do you want to create? Example 500"
read COUNT

FIRST_PORT=10000
LAST_PORT=$(($FIRST_PORT + $COUNT))

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x ${WORKDIR}/boot_*.sh 

# Copy our generated config
gen_3proxy >/usr/local/3proxy/conf/3proxy.cfg

# Configure startup based on OS
if echo "$OS" | grep -iq "ubuntu\|debian"; then
    # Ubuntu/Debian using systemd
    cat > /etc/systemd/system/proxy-startup.service <<EOF
[Unit]
Description=Proxy Startup Service
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash ${WORKDIR}/boot_iptables.sh
ExecStart=/bin/bash ${WORKDIR}/boot_ifconfig.sh
ExecStart=/bin/sh -c 'ulimit -n 10048'
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable proxy-startup.service
    systemctl start proxy-startup.service
    systemctl restart 3proxy
else
    # CentOS/RHEL using rc.local
    cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
service 3proxy restart
EOF

    chmod +x /etc/rc.local
    bash /etc/rc.local
fi

gen_proxy_file_for_user

upload_proxy
