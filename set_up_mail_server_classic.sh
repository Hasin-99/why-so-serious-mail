#!/bin/bash

# Paths for storing mail records
MAILBOX_DIR="/tmp/Why_So_Serious"
INBOX_FILE="$MAILBOX_DIR/inbox.txt"
SENT_FILE="$MAILBOX_DIR/sent.txt"
SPAM_FILE="$MAILBOX_DIR/spam.txt"
TRASH_FILE="$MAILBOX_DIR/trash.txt"
DRAFTS_FILE="$MAILBOX_DIR/drafts.txt"

# Local server hostname
LOCAL_HOSTNAME="md.shadmanhain@example.com"

# Ensure mail record directory exists
function initialize_mailbox() {
    mkdir -p "$MAILBOX_DIR"
    touch "$INBOX_FILE" "$SENT_FILE" "$SPAM_FILE" "$TRASH_FILE" "$DRAFTS_FILE"
}

# Function to get the current timestamp
function get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Function to assign mail IDs as simple numbers
function assign_mail_id() {
    file="$1"

    if [[ -s "$file" ]]; then
        # Extract all lines with "Mail ID:", get the number part, find the max
        last_id=$(grep "^Mail ID:" "$file" | awk -F': ' '{print $2}' | sort -n | tail -n 1)
        if [[ -z "$last_id" ]]; then
            echo 0
        else
            echo $((last_id + 1))
        fi
    else
        echo 0
    fi
}


# Function to validate email addresses using regex
function validate_email() {
    email="$1"
    # Regex pattern for validating email addresses
    if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0 # Valid email
    else
        return 1 # Invalid email
    fi
}

# Function to move all emails from a specific section to Trash
function move_to_trash() {
    section="$1"
    file="$2"

    confirm=$(zenity --question --title="Move to Trash" --text="Are you sure you want to move all emails from $section to Trash?" --ok-label="Yes" --cancel-label="No")
    if [[ $? -eq 0 ]]; then
        cat "$file" >> "$TRASH_FILE" # Append emails to Trash
        > "$file" # Clear the original file
        zenity --info --title="Success" --text="All emails from $section have been moved to Trash." --timeout=3
    else
        zenity --info --title="Cancelled" --text="Moving emails to Trash was cancelled for $section." --timeout=3
    fi
}

# Function to permanently delete all emails from Trash
function permanently_delete_trash() {
    confirm=$(zenity --question --title="Permanently Delete Trash" --text="Are you sure you want to permanently delete all emails from Trash? This action cannot be undone." --ok-label="Yes" --cancel-label="No")
    if [[ $? -eq 0 ]]; then
        > "$TRASH_FILE" # Clear the Trash file
        zenity --info --title="Success" --text="All emails from Trash have been permanently deleted." --timeout=3
    else
        zenity --info --title="Cancelled" --text="Permanent deletion of Trash was cancelled." --timeout=3
    fi
}

# Function to send an email
function send_email() {
    combined_input=$(zenity --forms --title="Send Email" \
        --text="Fill out the fields below for the email" \
        --add-entry="Recipient Email Address" \
        --add-entry="Subject" \
        --add-entry="Email Body")

    if [[ $? -ne 0 ]]; then
        zenity --info --title="Cancelled" --text="Email sending was cancelled." --timeout=2
        return
    fi

    email=$(echo "$combined_input" | cut -d'|' -f1)
    subject=$(echo "$combined_input" | cut -d'|' -f2)
    body=$(echo "$combined_input" | cut -d'|' -f3)

    if ! validate_email "$email"; then
        zenity --error --title="Error" --text="Invalid email address! Please enter a valid email." --timeout=2
        return
    fi

    if [[ -z "$subject" || -z "$body" ]]; then
        zenity --error --title="Error" --text="Subject and Body are required!" --timeout=2
        return
    fi

    timestamp=$(get_timestamp)
    mail_id=$(assign_mail_id "$SENT_FILE")
    if is_spam "$subject" "$body"; then
    mail_id=$(assign_mail_id "$SPAM_FILE")
    echo -e "Mail ID: $mail_id\nFrom: $LOCAL_HOSTNAME\nTo: $email\nSubject: $subject\nBody: $body\nDate: $timestamp\n---" >> "$SPAM_FILE"
    zenity --info --title="Spam Detected" --text="This email was flagged as spam and moved to the Spam folder!" --timeout=3
    return
fi

    # Log email to Sent
    echo -e "Mail ID: $mail_id\nFrom: $LOCAL_HOSTNAME\nTo: $email\nSubject: $subject\nBody: $body\nDate: $timestamp\n---" >> "$SENT_FILE"

    # Simulate receiving the same email by storing it in Inbox
    mail_id=$(assign_mail_id "$INBOX_FILE")
    echo -e "Mail ID: $mail_id\nFrom: $LOCAL_HOSTNAME\nTo: $email\nSubject: $subject\nBody: $body\nDate: $timestamp\n---" >> "$INBOX_FILE"

    zenity --info --title="Success" --text="Email sent to $email. Check your Sent folder!" --timeout=3
}

# Function to save a draft
function save_draft() {
    combined_input=$(zenity --forms --title="Save Draft" \
        --text="Fill out the fields below for the draft" \
        --add-entry="Recipient Email Address" \
        --add-entry="Subject" \
        --add-entry="Email Body")

    if [[ $? -ne 0 ]]; then
        zenity --info --title="Cancelled" --text="Saving draft was cancelled." --timeout=2
        return
    fi

    email=$(echo "$combined_input" | cut -d'|' -f1)
    subject=$(echo "$combined_input" | cut -d'|' -f2)
    body=$(echo "$combined_input" | cut -d'|' -f3)

    if ! validate_email "$email"; then
        zenity --error --title="Error" --text="Invalid recipient email address! Please enter a valid email." --timeout=2
        return
    fi

    if [[ -z "$subject" || -z "$body" ]]; then
        zenity --error --title="Error" --text="Subject and Body are required!" --timeout=2
        return
    fi

    timestamp=$(get_timestamp)
    mail_id=$(assign_mail_id "$DRAFTS_FILE")

    # Log email to Drafts
    echo -e "Mail ID: $mail_id\nFrom: $LOCAL_HOSTNAME\nTo: $email\nSubject: $subject\nBody: $body\nDate: $timestamp\n---" >> "$DRAFTS_FILE"

    zenity --info --title="Success" --text="Draft saved successfully!" --timeout=3
}

# Function to view mail records
function view_mail_records() {
    while true; do
        record=$(zenity --list --title="View Mail Records" --column="Options" \
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

        content=$(cat "$file")
        if [[ -z "$content" ]]; then
            zenity --info --title="$record Records" --text="No emails found in $record." --timeout=3
        else
            zenity --text-info --title="$record Records" --filename=<(echo -e "$content") --width=600 --height=400
        fi
    done
}

function is_spam() {
    local subject="$1"
    local body="$2"

    # Define some common spammy words (you can expand this list)
    spam_keywords=("win" "free" "offer" "lottery" "prize" "urgent")

    for word in "${spam_keywords[@]}"; do
        if [[ "$subject" =~ $word || "$body" =~ $word ]]; then
            return 0  # It's spam
        fi
    done

    return 1  # Not spam
}


# Function to delete mail records
function delete_mail_records() {
    while true; do
        record=$(zenity --list --title="Delete Mail Records" --column="Options" \
            "Inbox" \
            "Sent" \
            "Drafts" \
            "Spam" \
            "Trash" \
            "Move All to Trash" \
            "Permanently Delete Trash" \
            "Back to Main Menu")

        if [[ -z "$record" || "$record" == "Back to Main Menu" ]]; then
            return
        fi

        case $record in
            "Inbox") move_to_trash "Inbox" "$INBOX_FILE" ;;
            "Sent") move_to_trash "Sent" "$SENT_FILE" ;;
            "Drafts") move_to_trash "Drafts" "$DRAFTS_FILE" ;;
            "Spam") move_to_trash "Spam" "$SPAM_FILE" ;;
            "Trash") permanently_delete_trash ;;
            "Move All to Trash")
                move_to_trash "Inbox" "$INBOX_FILE"
                move_to_trash "Sent" "$SENT_FILE"
                move_to_trash "Drafts" "$DRAFTS_FILE"
                move_to_trash "Spam" "$SPAM_FILE"
                ;;
            "Permanently Delete Trash") permanently_delete_trash ;;
        esac
    done
}

# Main menu
function main_menu() {
    while true; do
        choice=$(zenity --list --title="Why_So_Serious" --column="Options" \
            "Send Email" \
            "Save Draft" \
            "View Mail Records" \
            "Delete Mail Records" \
            "Exit")

        if [[ -z "$choice" || "$choice" == "Exit" ]]; then
            zenity --info --title="Goodbye" --text="Exiting Why_So_Serious. Goodbye!" --timeout=2
            break
        fi

        case $choice in
            "Send Email") send_email ;;
            "Save Draft") save_draft ;;
            "View Mail Records") view_mail_records ;;
            "Delete Mail Records") delete_mail_records ;;
        esac
    done
}

# Initialize mailbox and run the main menu
initialize_mailbox
main_menu