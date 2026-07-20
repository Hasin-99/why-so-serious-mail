#!/bin/bash

# Function to install and start CUPS
function install_cups() {
    # Check if CUPS is installed
    if ! command -v lpstat &> /dev/null; then
        echo "CUPS is not installed. Installing CUPS..."
        brew install cups
        
        if [ $? -ne 0 ]; then
            echo "Error: Failed to install CUPS. Please install Homebrew first."
            exit 1
        fi
    fi

    # Start CUPS service
    echo "Starting CUPS service..."
    sudo launchctl load -w /Library/LaunchDaemons/org.cups.cupsd.plist
    sudo cupsctl --remote-admin --remote-any --share-printers
    echo "CUPS service started and configured for remote access."
}

# Function to add a printer
function add_printer() {
    echo "Adding a new printer..."

    # List available printers
    echo "Available printers:"
    lpinfo -v

    # Prompt user for printer URI
    printer_uri=$(zenity --entry --title="Add Printer" --text="Enter the URI of the printer (e.g., ipp://printer.local):")

    if [ -z "$printer_uri" ]; then
        zenity --error --title="Error" --text="Printer URI is required."
        return
    fi

    # Prompt user for printer name
    printer_name=$(zenity --entry --title="Printer Name" --text="Enter a name for the printer:")
    
    if [ -z "$printer_name" ]; then
        zenity --error --title="Error" --text="Printer name is required."
        return
    fi

    # Add the printer
    sudo lpadmin -p "$printer_name" -v "$printer_uri" -E -m everywhere
    if [ $? -eq 0 ]; then
        zenity --info --title="Success" --text="Printer '$printer_name' added successfully!"
    else
        zenity --error --title="Error" --text="Failed to add the printer."
    fi
}

# Function to list installed printers
function list_printers() {
    echo "Listing installed printers..."
    printers=$(lpstat -p 2>&1)
    zenity --info --title="Installed Printers" --text="$printers"
}

# Function to set user permissions
function set_user_permissions() {
    echo "Setting user permissions for printers..."

    # Get printer name
    printer_name=$(zenity --entry --title="Printer Name" --text="Enter the name of the printer:")
    
    if [ -z "$printer_name" ]; then
        zenity --error --title="Error" --text="Printer name is required."
        return
    fi

    # Get username
    username=$(zenity --entry --title="Username" --text="Enter the username to grant access:")

    if [ -z "$username" ]; then
        zenity --error --title="Error" --text="Username is required."
        return
    fi

    # Grant permission
    sudo lpadmin -p "$printer_name" -u allow:"$username"
    if [ $? -eq 0 ]; then
        zenity --info --title="Success" --text="User '$username' granted access to printer '$printer_name'."
    else
        zenity --error --title="Error" --text="Failed to set permissions."
    fi
}

# Main Function
function main() {
    zenity --info --title="CUPS Print Server Setup" --text="Welcome to the CUPS Print Server Setup Tool!" --timeout=3

    install_cups

    while true; do
        choice=$(zenity --list --title="Main Menu" --column="Options" \
            "Add a Printer" \
            "List Installed Printers" \
            "Set User Permissions" \
            "Exit")
        
        case $choice in
            "Add a Printer") add_printer ;;
            "List Installed Printers") list_printers ;;
            "Set User Permissions") set_user_permissions ;;
            "Exit"|"") break ;;
            *) zenity --error --text="Invalid choice!" ;;
        esac
        sleep 1
    done
}

main