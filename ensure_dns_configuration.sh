echo '#!/bin/bash

# Step 1: Check if /etc/resolv.conf Exists
echo "Checking if /etc/resolv.conf exists..."
if [ ! -f /etc/resolv.conf ]; then
    echo "/etc/resolv.conf does not exist. Creating it now..."
    sudo touch /etc/resolv.conf
    echo "/etc/resolv.conf created successfully."
else
    echo "/etc/resolv.conf already exists."
fi

# Step 2: Add DNS Configuration
echo "Adding DNS configuration to /etc/resolv.conf..."
sudo tee /etc/resolv.conf > /dev/null <<EOL
nameserver 8.8.8.8
nameserver 8.8.4.4
EOL
echo "DNS configuration added successfully."

# Step 3: Verify the Content of /etc/resolv.conf
echo "Verifying the content of /etc/resolv.conf..."
cat /etc/resolv.conf

# Step 4: Protect /etc/resolv.conf from Being Overwritten
echo "Protecting /etc/resolv.conf from being overwritten..."
sudo chattr +i /etc/resolv.conf
echo "/etc/resolv.conf is now immutable."

# Step 5: Confirm Protection
echo "Confirming the immutability of /etc/resolv.conf..."
lsattr /etc/resolv.conf

echo "DNS configuration and protection process completed successfully."
' > ensure_dns_configuration.sh