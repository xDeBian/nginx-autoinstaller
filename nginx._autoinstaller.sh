#!/bin/bash

# ANSI color escape codes
YELLOW='\033[0;33m'  # Yellow color
GREEN='\033[0;32m'   # Green color
RED='\033[0;31m'     # Red color
CYAN='\033[0;36m'    # Cyan color
NC='\033[0m'         # No color
                                                                                                                          

echo "       _____       ____  _  "           
echo "      |  __ \     |  _ \(_)  "          
echo " __  _| |  | | ___| |_) |_  __ _ _ __"  
echo " \ \/ / |  | |/ _ \  _ <| |/ _  |  _ \ " 
echo "  >  <| |__| |  __/ |_) | | (_| | | | | "
echo " /_/\_\_____/ \___|____/|_|\__ _|_| |_| "
echo "                                        "
                                       



# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install nginx
install_nginx() {
    # Retrieve nginx versions from the website and remove duplicates
    versions=$(curl -s https://nginx.org/en/download.html | grep -oP 'nginx-\d+\.\d+\.\d+' | sort -V | uniq)

    # Define latest stable and mainline versions
    latest_stable="nginx-1.24.0"
    latest_mainline="nginx-1.25.4"

    # Define versions to hide
    declare -a hide_versions=("nginx-0.5.38" "nginx-0.8.55" "nginx-0.6.39" "nginx-0.7.69" "nginx-1.0.15" "nginx-1.2.9" "nginx-1.4.7" "nginx-1.6.3" "nginx-1.8.1" "nginx-1.10.3" "nginx-1.12.2")

    # Categorize versions into stable, mainline, and legacy
    declare -a stable_versions=()
    declare -a mainline_versions=()
    declare -a legacy_versions=()

    for version in $versions; do
        if [[ "$version" == "$latest_stable" ]]; then
            stable_versions+=("$version")
        elif [[ "$version" == "$latest_mainline" ]]; then
            mainline_versions+=("$version")
        elif [[ ! " ${hide_versions[@]} " =~ " $version " ]]; then
            legacy_versions+=("$version")
        fi
    done

    # Present submenu for stable, mainline, and legacy versions
    echo -e "${YELLOW}Nginx-ის ვერსიები:${NC}"
    echo -e "${GREEN}1. სტაბილური ვერსიები:${NC}"
    count=1
    for stable_version in "${stable_versions[@]}"; do
        echo -e "${GREEN}   $count. $stable_version${NC}"
        ((count++))
    done
    echo -e "${GREEN}2. ბოლო ვერსია:${NC}"
    echo -e "${GREEN}   $count. $latest_mainline${NC}"
    ((count++))
    echo -e "${RED}3. ძველი ვერსიები:${NC}"
    for legacy_version in "${legacy_versions[@]}"; do
        echo -e "${RED}   $count. $legacy_version${NC}"
        ((count++))
    done

    # Prompt user to select a version
    read -p "შეიყვანეთ ვერსიის შესაბამისი ნომერი, რომლის ინსტალაციაც გსურთ: " choice

    # Validate user input
    if (( choice < 1 || choice > count - 1 )); then
        echo "არასწორია. გთხოვთ, აირჩიოთ სწორი ნომერი."
        exit 1
    fi

    # Extract the selected version
    if (( choice <= ${#stable_versions[@]} )); then
        selected_version="${stable_versions[choice - 1]}"
    elif (( choice == ${#stable_versions[@]} + 1 )); then
        selected_version="$latest_mainline"
    else
        selected_version="${legacy_versions[choice - ${#stable_versions[@]} - 2]}"
    fi

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

    # Add Nginx to PATH
    nginx_install_path="/usr/local/nginx/sbin"
    if ! grep -q "$nginx_install_path" ~/.bashrc; then
        echo "export PATH=$nginx_install_path:\$PATH" >> ~/.bashrc
        source ~/.bashrc
        
    fi
    
    # Export PATH
    export PATH="/usr/local/nginx/sbin:$PATH"

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

    echo "Nginx წარმატებით დაინსტალირდა."

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
    echo "<html><body><h1>სატესტო საიტი</h1></body></html>" | sudo tee /var/www/html/test.site/index.html

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

    echo "Nginx წარმატებით წაიშალა."
}

# Main menu
while true; do
    echo -e "${YELLOW}[Მთავარი მენიუ]:${NC}"
    echo -e "${GREEN}1. Nginx-ის ინსტალაცია${NC}"
    echo -e "${RED}2. Nginx-ის წაშლა${NC}"
    echo -e "${CYAN}3. გასვლა${NC}"
    read -p "მიუთითეთ თქვენი არჩევანი: " main_choice

    case $main_choice in
        1)
            install_nginx
            ;;
        2)
            uninstall_nginx
            ;;
        3)
            echo "ნახვამდის..."
            exit 0
            ;;
        *)
            echo "არასწორია. გთხოვთ, შეიყვანოთ სწორი ვარიანტი."
            ;;
    esac
done