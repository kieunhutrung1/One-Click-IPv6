# One-Click IPv6 Proxy Installer

This script automatically installs and configures a 3proxy server with multiple IPv6 proxies on Linux systems. It supports both Ubuntu/Debian and CentOS/RHEL distributions.

## Features

- Automatic OS detection (Ubuntu, Debian, CentOS, RHEL)
- Generates multiple IPv6 proxies
- Authentication with randomly generated usernames and passwords
- Works with both systemd and init.d based systems
- Easy installation with a single command

## Requirements

- A server with IPv6 support
- Root access
- Linux OS (Ubuntu, Debian, CentOS, or RHEL)
- Curl and basic tools installed

## Installation

1. Download the installer:

```bash
wget -O install.sh https://gitlab.com/mikproxylink/one-click-proxyv6/-/raw/main/install.sh
```

2. Make it executable:

```bash
chmod +x install.sh
```

3. Run the installer:

```bash
./install.sh
```

4. Follow the prompts. When asked, enter the number of proxies you want to create.

## Usage

After installation, the script will generate a `proxy.zip` file containing your proxy list. The script will:

1. Upload this file to a temporary file sharing service
2. Provide you with a download URL
3. Give you a password to extract the zip file

The proxy format is:
```
IP:PORT:USERNAME:PASSWORD
```

You can use these proxies in your applications or browser with the provided credentials.

## Service Management

### Ubuntu/Debian (systemd)

- Start the proxy service: `systemctl start 3proxy`
- Stop the proxy service: `systemctl stop 3proxy`
- Restart the proxy service: `systemctl restart 3proxy`
- Check service status: `systemctl status 3proxy`

### CentOS/RHEL

- Start the proxy service: `service 3proxy start`
- Stop the proxy service: `service 3proxy stop`
- Restart the proxy service: `service 3proxy restart`
- Check service status: `service 3proxy status`

## Configuration

The main configuration files are:

- `/usr/local/etc/3proxy/3proxy.cfg` - 3proxy configuration
- `/home/proxy-installer/data.txt` - List of generated proxies with credentials

## Troubleshooting

1. If you can't connect to the proxies, check your firewall settings. The script adds iptables rules, but your server might have additional firewall software.

2. Verify the 3proxy service is running:
   ```
   # Ubuntu/Debian
   systemctl status 3proxy
   
   # CentOS/RHEL
   service 3proxy status
   ```

3. Check the 3proxy logs:
   ```
   # All systems
   tail -f /usr/local/etc/3proxy/logs/3proxy.log
   ```

## License

Open source under the terms of the MIT License.

## Support

For issues or feature requests, please open an issue on the GitHub repository.

