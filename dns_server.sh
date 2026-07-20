#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
    zenity --error --text="❌ This script must be run as root. Please try again with sudo or as root."
    exit 1
fi

# Install BIND
function install_bind() {
    zenity --info --text="Installing BIND DNS server..."
    brew install bind
    if [[ $? -eq 0 ]]; then
        zenity --info --text="✅ BIND DNS server installed successfully."
    else
        zenity --error --text="❌ Failed to install BIND DNS server. Please check your internet connection and ensure Homebrew is installed."
        exit 1
    fi
}

# Set up DNS zone files
function setup_dns_zone_files() {
    DOMAIN=$(zenity --entry --title="DNS Setup" --text="Enter your domain name (e.g., example.com):")
    if [[ -z "$DOMAIN" ]]; then
        zenity --error --text="❌ Domain name cannot be empty."
        exit 1
    fi

    IP=$(zenity --entry --title="DNS Setup" --text="Enter your server IP address:")
    if [[ -z "$IP" ]]; then
        zenity --error --text="❌ IP address cannot be empty."
        exit 1
    fi

    ZONE_FILE="/usr/local/etc/named/db.$DOMAIN"
    REVERSE_ZONE_FILE="/usr/local/etc/named/db.$(echo $IP | awk -F. '{print $3"."$2"."$1}').rev"

    # Forward zone file
    cat <<EOF >$ZONE_FILE
\$TTL    604800
@       IN      SOA     ns.$DOMAIN. admin.$DOMAIN. (
                             2         ; Serial
                        604800         ; Refresh
                         86400         ; Retry
                       2419200         ; Expire
                        604800 )       ; Negative Cache TTL
;
@       IN      NS      ns.$DOMAIN.
@       IN      A       $IP
ns      IN      A       $IP
EOF

    # Reverse zone file
    cat <<EOF >$REVERSE_ZONE_FILE
\$TTL    604800
@       IN      SOA     ns.$DOMAIN. admin.$DOMAIN. (
                             1         ; Serial
                        604800         ; Refresh
                         86400         ; Retry
                       2419200         ; Expire
                        604800 )       ; Negative Cache TTL
;
@       IN      NS      ns.$DOMAIN.
$(echo $IP | awk -F. '{print $4}')      IN      PTR     $DOMAIN.
EOF

    # Update named.conf.local
    NAMED_CONF="/usr/local/etc/named/named.conf.local"
    if [[ ! -f $NAMED_CONF ]]; then
        touch $NAMED_CONF
    fi

    cat <<EOF >>$NAMED_CONF

zone "$DOMAIN" {
    type master;
    file "$ZONE_FILE";
};

zone "$(echo $IP | awk -F. '{print $3"."$2"."$1}').in-addr.arpa" {
    type master;
    file "$REVERSE_ZONE_FILE";
};
EOF

    zenity --info --text="✅ DNS zone files and configuration updated successfully."
}

# Test DNS configuration
function test_dns() {
    named-checkconf
    if [[ $? -ne 0 ]]; then
        zenity --error --text="❌ DNS configuration failed. Please check your zone files."
        exit 1
    fi

    named-checkzone $DOMAIN $ZONE_FILE
    if [[ $? -ne 0 ]]; then
        zenity --error --text="❌ Forward zone configuration failed. Verify the zone file at $ZONE_FILE."
        exit 1
    fi

    named-checkzone "$(echo $IP | awk -F. '{print $3"."$2"."$1}').in-addr.arpa" $REVERSE_ZONE_FILE
    if [[ $? -ne 0 ]]; then
        zenity --error --text="❌ Reverse zone configuration failed. Verify the reverse zone file at $REVERSE_ZONE_FILE."
        exit 1
    fi

    zenity --info --text="✅ DNS configuration passed all tests."
}

# Restart BIND service
function restart_bind() {
    zenity --info --text="Restarting BIND DNS server..."
    sudo brew services restart bind
    if [[ $? -eq 0 ]]; then
        zenity --info --text="✅ BIND DNS server restarted successfully."
    else
        zenity --error --text="❌ Failed to restart BIND DNS server."
        exit 1
    fi
}

# GUI Menu
while true; do
    ACTION=$(zenity --list --title="DNS Server Setup" --column="Action" "Install BIND" "Setup DNS Zone Files" "Test DNS Configuration" "Restart DNS Server" "Exit")
    case $ACTION in
    "Install BIND")
        install_bind
        ;;
    "Setup DNS Zone Files")
        setup_dns_zone_files
        ;;
    "Test DNS Configuration")
        test_dns
        ;;
    "Restart DNS Server")
        restart_bind
        ;;
    "Exit")
        break
        ;;
    *)
        zenity --error --text="Invalid option. Please try again."
        ;;
    esac
done