#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install nginx
install_nginx() {
    # Retrieve nginx versions from the website and remove duplicates
    versions=$(curl -s https://nginx.org/en/download.html | grep -oP 'nginx-\d+\.\d+\.\d+' | sort -V | uniq)

    # Assign numbers to versions
    version_count=1
    version_map=()
    echo "Available Nginx Versions:"
    while read -r version; do
        version_map["$version_count"]=$version
        echo "$version_count. $version"
        ((version_count++))
    done <<< "$versions"

    # Prompt user to select a version
    read -p "Enter the number corresponding to the version you want to install: " choice

    # Validate user input
    if [[ ! "${version_map[$choice]}" ]]; then
        echo "Invalid choice. Please select a valid number."
        exit 1
    fi

    selected_version=${version_map[$choice]}

    # Download and install Nginx dependencies
    sudo apt update
    sudo apt install -y build-essential libpcre3 libpcre3-dev zlib1g zlib1g-dev openssl libssl-dev

    # Download and extract Nginx
    wget https://nginx.org/download/$selected_version.tar.gz
    tar -zxvf $selected_version.tar.gz
    cd $selected_version

    # Configure Nginx with default options
    ./configure
    make
    sudo make install

    # Clean up downloaded files and extracted source folder
    rm -f $selected_version.tar.gz
    sudo rm -rf $selected_version

    # Create sites-enabled directory
    sudo mkdir -p /etc/nginx/sites-available
    sudo mkdir -p /etc/nginx/sites-enabled
    # Create systemd unit file
    cat << EOF | sudo tee /etc/systemd/system/nginx.service
[Unit]
Description=Nginx HTTP Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/nginx/sbin/nginx
ExecStop=/usr/local/nginx/sbin/nginx -s stop
ExecReload=/usr/local/nginx/sbin/nginx -s reload
PIDFile=/usr/local/nginx/logs/nginx.pid
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd daemon to update changes
    sudo systemctl daemon-reload

    # Enable nginx service to start on boot
    sudo systemctl enable nginx

    # Start nginx service
    sudo systemctl start nginx

    echo "Nginx installed successfully."

    # Add site block for test.site
    cat << EOF | sudo tee /etc/nginx/sites-available/test.site
server {
    listen 80;
    server_name 127.0.2.1;

    root /var/www/html/test.site;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

    # Create directory for test.site site
    sudo mkdir -p /var/www/html/test.site
    sudo chown -R $USER:$USER /var/www/html/test.site
    echo "<html><body><h1>Test Website</h1></body></html>" | sudo tee /var/www/html/test.site/index.html

    # Create symbolic link in sites-enabled
    sudo ln -s /etc/nginx/sites-available/test.site /etc/nginx/sites-enabled/test.site
   
    # Add 127.0.2.1 test.site entry to /etc/hosts file
    echo "127.0.2.1 test.site" | sudo tee -a /etc/hosts

    # Include configurations from sites-enabled directory in nginx.conf
    sudo sed -i '/#gzip  on;/a\    # Include configurations from sites-enabled directory\n    include /etc/nginx/sites-enabled/*;' /usr/local/nginx/conf/nginx.conf

    # Reload nginx to apply changes
    sudo systemctl reload nginx
    sudo systemctl restart nginx
}

# Function to uninstall nginx
uninstall_nginx() {
    # Stop nginx if it's running
    sudo pkill nginx

    # Remove nginx files and directories, including custom configuration
    sudo rm -rf /etc/nginx
    sudo rm -rf /usr/local/nginx

    # Remove nginx executable path from PATH
    nginx_dir="/usr/local/nginx/sbin"
    if [[ ":$PATH:" == *":$nginx_dir:"* ]]; then
        sudo sed -i "/$nginx_dir/d" /etc/profile.d/nginx.sh
    fi

    # Remove nginx systemd service file
    sudo rm -f /etc/systemd/system/nginx.service

    # Reload systemd daemon to update changes
    sudo systemctl daemon-reload

    # Remove entry for test.site from /etc/hosts
    sudo sed -i '/test\.site/d' /etc/hosts

    echo "Nginx uninstalled successfully."
}

# Main menu
while true; do
    echo "Main Menu:"
    echo "1. Install Nginx"
    echo "2. Uninstall Nginx"
    echo "3. Exit"
    read -p "Enter your choice: " main_choice

    case $main_choice in
        1)
            install_nginx
            ;;
        2)
            uninstall_nginx
            ;;
        3)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please enter a valid option."
            ;;
    esac
done
