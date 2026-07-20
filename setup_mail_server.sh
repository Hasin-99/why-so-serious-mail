#!/bin/bash

# Paths for storing mail records
MAILBOX_DIR="/tmp/gmail_like_service"
INBOX_FILE="$MAILBOX_DIR/inbox.txt"
SENT_FILE="$MAILBOX_DIR/sent.txt"
SPAM_FILE="$MAILBOX_DIR/spam.txt"
TRASH_FILE="$MAILBOX_DIR/trash.txt"
DRAFTS_FILE="$MAILBOX_DIR/drafts.txt"

# Ensure mail record directory exists
function initialize_mailbox() {
    mkdir -p "$MAILBOX_DIR"
    touch "$INBOX_FILE" "$SENT_FILE" "$SPAM_FILE" "$TRASH_FILE" "$DRAFTS_FILE"
}

# Function to get the current timestamp
function get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}
# Function to validate email addresses
function validate_email() {
    email="$1"
    # Regex for validating email
    if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0 # Valid email
    else
        return 1 # Invalid email
    fi
}
# Function to delete all emails from a specific section
function delete_all_emails() {
    section="$1"
    file="$2"

    confirm=$(zenity --question --title="Delete Confirmation" --text="Are you sure you want to delete all emails from $section?" --ok-label="Yes" --cancel-label="No")
    if [[ $? -eq 0 ]]; then
        > "$file" # Clear the file
        zenity --info --title="Success" --text="All emails from $section have been deleted." --timeout=3
    else
        zenity --info --title="Cancelled" --text="Deletion cancelled for $section." --timeout=3
    fi
}

# Function to delete all emails from all sections
function delete_all_mails() {
    confirm=$(zenity --question --title="Delete All Confirmation" --text="Are you sure you want to delete all emails from all sections (Inbox, Sent, Drafts, Spam, Trash)?" --ok-label="Yes" --cancel-label="No")
    if [[ $? -eq 0 ]]; then
        > "$INBOX_FILE"
        > "$SENT_FILE"
        > "$DRAFTS_FILE"
        > "$SPAM_FILE"
        > "$TRASH_FILE"
        zenity --info --title="Success" --text="All emails from all sections have been deleted." --timeout=3
    else
        zenity --info --title="Cancelled" --text="Deletion of all emails has been cancelled." --timeout=3
    fi
}

# Function to assign mail IDs as simple numbers
function assign_mail_id() {
    file="$1"
    last_id=$(tail -n 1 "$file" | grep -oP "(?<=Mail ID: )\d+" || echo 0)
    echo $((last_id + 1))
}

# Function to send an email
function send_email() {
    email=$(zenity --entry --title="Send Email" --text="Enter the recipient email address:")
    if [[ -z "$email" ]]; then
        zenity --error --title="Error" --text="No email address provided!" --timeout=2
        return
    fi

    cc=$(zenity --entry --title="CC (Optional)" --text="Enter CC email addresses (comma-separated):")
    bcc=$(zenity --entry --title="BCC (Optional)" --text="Enter BCC email addresses (comma-separated):")

    subject=$(zenity --entry --title="Email Subject" --text="Enter the subject of the email:")
    if [[ -z "$subject" ]]; then
        zenity --error --title="Error" --text="No subject provided!" --timeout=2
        return
    fi

    body=$(zenity --entry --title="Email Body" --text="Enter the body of the email:")
    if [[ -z "$body" ]]; then
        zenity --error --title="Error" --text="No email body provided!" --timeout=2
        return
    fi

    timestamp=$(get_timestamp)
    mail_id=$(assign_mail_id "$SENT_FILE")

    # Log email to Sent
    echo -e "Mail ID: $mail_id\nTo: $email\nCC: ${cc:-None}\nBCC: ${bcc:-None}\nSubject: $subject\nBody: $body\nDate: $timestamp\n---" >> "$SENT_FILE"

    # Simulate receiving the same email by storing it in Inbox
    mail_id=$(assign_mail_id "$INBOX_FILE")
    echo -e "Mail ID: $mail_id\nFrom: $email\nCC: ${cc:-None}\nBCC: ${bcc:-None}\nSubject: $subject\nBody: $body\nDate: $timestamp\n---" >> "$INBOX_FILE"

    zenity --info --title="Success" --text="Email sent to $email. Check your Sent folder!" --timeout=3
}

# Function to draft an email
function draft_email() {
    subject=$(zenity --entry --title="Draft Email Subject" --text="Enter the subject of the draft:")
    if [[ -z "$subject" ]]; then
        zenity --error --title="Error" --text="No subject provided!" --timeout=2
        return
    fi

    body=$(zenity --entry --title="Draft Email Body" --text="Enter the body of the draft:")
    if [[ -z "$body" ]]; then
        zenity --error --title="Error" --text="No email body provided!" --timeout=2
        return
    fi

    timestamp=$(get_timestamp)
    mail_id=$(assign_mail_id "$DRAFTS_FILE")

    # Save draft
    echo -e "Mail ID: $mail_id\nSubject: $subject\nBody: $body\nDate: $timestamp\n---" >> "$DRAFTS_FILE"

    zenity --info --title="Success" --text="Draft saved successfully!" --timeout=3
}

# Function to view mail records
function view_mail_records() {
    while true; do
        record=$(zenity --list --title="Mail Records" --column="Options" \
            "Inbox" \
            "Sent" \
            "Drafts" \
            "Spam" \
            "Trash" \
            "All Mails" \
            "Back to Main Menu")

        if [[ -z "$record" || "$record" == "Back to Main Menu" ]]; then
            return
        fi

        case $record in
            "Inbox") file="$INBOX_FILE" ;;
            "Sent") file="$SENT_FILE" ;;
            "Drafts") file="$DRAFTS_FILE" ;;
            "Spam") file="$SPAM_FILE" ;;
            "Trash") file="$TRASH_FILE" ;;
            "All Mails")
                # Combine all emails into one display
                content="All Mails:\n\n"
                content+="--- Inbox ---\n$(cat "$INBOX_FILE")\n"
                content+="--- Sent ---\n$(cat "$SENT_FILE")\n"
                content+="--- Drafts ---\n$(cat "$DRAFTS_FILE")\n"
                content+="--- Spam ---\n$(cat "$SPAM_FILE")\n"
                content+="--- Trash ---\n$(cat "$TRASH_FILE")\n"
                zenity --text-info --title="All Mails" --filename=<(echo -e "$content") --width=600 --height=400
                continue
                ;;
        esac

        # Add Mail IDs to display
        content=$(awk -v RS="---" 'BEGIN { ORS="\n---\n" } { print NR-1 " | " $0 }' "$file")
        if [[ -z "$content" ]]; then
            zenity --info --title="$record Records" --text="No emails found in $record." --timeout=3
        else
            zenity --text-info --title="$record Records" --filename=<(echo -e "$content") --width=600 --height=400
        fi
    done
}

function delete_mail_records() {
    while true; do
        record=$(zenity --list --title="Delete Mail Records" --column="Options" \
            "Inbox" \
            "Sent" \
            "Drafts" \
            "Spam" \
            "Trash" \
            "All Mails" \
            "Back to Main Menu")

        if [[ -z "$record" || "$record" == "Back to Main Menu" ]]; then
            return
        fi

        case $record in
            "Inbox") delete_all_emails "Inbox" "$INBOX_FILE" ;;
            "Sent") delete_all_emails "Sent" "$SENT_FILE" ;;
            "Drafts") delete_all_emails "Drafts" "$DRAFTS_FILE" ;;
            "Spam") delete_all_emails "Spam" "$SPAM_FILE" ;;
            "Trash") delete_all_emails "Trash" "$TRASH_FILE" ;;
            "All Mails") delete_all_mails ;;
        esac
    done
}

# Main menu
function main_menu() {
    while true; do
        choice=$(zenity --list --title="Gmail-like Service" --column="Options" \
            "Send Email" \
            "Draft Email" \
            "View Mail Records" \
            "Delete Mail Records" \
            "Exit")

        if [[ -z "$choice" || "$choice" == "Exit" ]]; then
            zenity --info --title="Goodbye" --text="Exiting Gmail-like Service. Goodbye!" --timeout=2
            break
        fi

        case $choice in
            "Send Email") send_email ;;
            "Draft Email") draft_email ;;
            "View Mail Records") view_mail_records ;;
            "Delete Mail Records") delete_mail_records ;;
        esac
    done
}