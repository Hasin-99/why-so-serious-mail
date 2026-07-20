#!/bin/bash
# =============================================================================
#  Why So Serious — Advanced Offline Mail System
#  CSE324 Operating System Lab | Bash + Zenity
#  Demonstrates: processes, file I/O, permissions, logging, IPC-style queues
# =============================================================================

set -u

APP_NAME="Why So Serious Mail"
MAILBOX_DIR="${HOME}/.why_so_serious"
FOLDERS=(inbox sent drafts spam trash)
CONTACTS_FILE="$MAILBOX_DIR/contacts.csv"
USERS_FILE="$MAILBOX_DIR/users.db"
LOG_FILE="$MAILBOX_DIR/activity.log"
QUEUE_DIR="$MAILBOX_DIR/queue"
ATTACH_DIR="$MAILBOX_DIR/attachments"
CONFIG_FILE="$MAILBOX_DIR/config.env"
SESSION_USER=""
SESSION_EMAIL=""

# -----------------------------------------------------------------------------
# Core helpers
# -----------------------------------------------------------------------------

log_event() {
    local level="$1"; shift
    printf '[%s] [%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "${SESSION_USER:-system}" "$*" >> "$LOG_FILE"
}

notify() {
    local title="$1" message="$2"
    if command -v osascript &>/dev/null; then
        osascript -e "display notification \"$message\" with title \"$title\"" &>/dev/null || true
    fi
    zenity --notification --text="$title: $message" 2>/dev/null || true
}

alert_info()    { zenity --info    --title="$APP_NAME" --width=420 --text="$1" ${2:+--timeout=$2}; }
alert_error()   { zenity --error   --title="$APP_NAME" --width=420 --text="$1" ${2:+--timeout=$2}; }
alert_warn()    { zenity --warning --title="$APP_NAME" --width=420 --text="$1" ${2:+--timeout=$2}; }
confirm_action(){ zenity --question --title="$APP_NAME" --width=420 --text="$1" --ok-label="Yes" --cancel-label="No"; }

get_timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

validate_email() {
    [[ "$1" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

hash_password() {
    # Portable one-way hash (no plaintext passwords on disk)
    printf '%s' "$1" | shasum -a 256 2>/dev/null | awk '{print $1}'
}

folder_path() { echo "$MAILBOX_DIR/$1"; }

count_mails() {
    local folder="$1"
    find "$(folder_path "$folder")" -maxdepth 1 -type f -name '*.eml' 2>/dev/null | wc -l | tr -d ' '
}

next_mail_id() {
    local max=0 id
    for folder in "${FOLDERS[@]}"; do
        for f in "$(folder_path "$folder")"/*.eml; do
            [[ -f "$f" ]] || continue
            id=$(basename "$f" .eml | sed 's/^0*//')
            [[ -z "$id" ]] && id=0
            (( id > max )) && max=$id
        done
    done
    printf '%04d' $((max + 1))
}

write_mail_file() {
    local path="$1"
    local id="$2" from="$3" to="$4" subject="$5" body="$6"
    local priority="${7:-Normal}" status="${8:-Unread}" starred="${9:-No}"
    local attachment="${10:-none}" cc="${11:-}" reply_to="${12:-}"

    cat > "$path" <<EOF
Mail-ID: $id
From: $from
To: $to
CC: $cc
Reply-To: $reply_to
Subject: $subject
Priority: $priority
Status: $status
Starred: $starred
Attachment: $attachment
Date: $(get_timestamp)
Body:
$body
EOF
    chmod 600 "$path"
}

read_header() {
    local file="$1" key="$2"
    awk -F': ' -v k="$key" '$1==k {print substr($0, index($0,$2)); exit}' "$file"
}

read_body() {
    awk 'BEGIN{p=0} /^Body:/{p=1; next} p{print}' "$1"
}

mail_list_row() {
    # Outputs: id|from|subject|date|priority|star|status
    local file="$1"
    local id from subject date priority starred status
    id=$(basename "$file" .eml)
    from=$(read_header "$file" "From")
    subject=$(read_header "$file" "Subject")
    date=$(read_header "$file" "Date")
    priority=$(read_header "$file" "Priority")
    starred=$(read_header "$file" "Starred")
    status=$(read_header "$file" "Status")
    local star_mark=" "
    [[ "$starred" == "Yes" ]] && star_mark="★"
    local unread_mark=""
    [[ "$status" == "Unread" ]] && unread_mark="● "
    printf '%s|%s|%s%s|%s|%s|%s\n' "$id" "$from" "$unread_mark" "$subject" "$date" "$priority" "$star_mark"
}

is_spam() {
    local subject="$1" body="$2"
    local text
    text=$(printf '%s %s' "$subject" "$body" | tr '[:upper:]' '[:lower:]')
    local keywords=(win free lottery prize urgent "click here" "act now" crypto bitcoin "account suspended" "verify now" "nigerian prince")
    local score=0 word
    for word in "${keywords[@]}"; do
        [[ "$text" == *"$word"* ]] && score=$((score + 1))
    done
    # ALL CAPS / shouty subject looks spammy (bash 3.2-safe check)
    local upper
    upper=$(printf '%s' "$subject" | tr '[:lower:]' '[:upper:]')
    if [[ ${#subject} -ge 8 && "$subject" == "$upper" ]]; then
        score=$((score + 2))
    fi
    (( score >= 2 ))
}

# -----------------------------------------------------------------------------
# Bootstrap
# -----------------------------------------------------------------------------

initialize_mailbox() {
    mkdir -p "$MAILBOX_DIR" "$QUEUE_DIR" "$ATTACH_DIR"
    for folder in "${FOLDERS[@]}"; do
        mkdir -p "$(folder_path "$folder")"
    done
    touch "$CONTACTS_FILE" "$USERS_FILE" "$LOG_FILE"
    [[ -f "$CONFIG_FILE" ]] || cat > "$CONFIG_FILE" <<'EOF'
THEME=Joker
AUTO_SPAM=1
NOTIFY=1
EOF
    # Private mailbox — OS permissions demo
    chmod 700 "$MAILBOX_DIR"
    chmod 600 "$USERS_FILE" "$LOG_FILE" "$CONTACTS_FILE" "$CONFIG_FILE" 2>/dev/null || true
    log_event INFO "Mailbox initialized at $MAILBOX_DIR"
}

seed_demo_data() {
    # Only seed once so re-runs keep user data
    if [[ -f "$MAILBOX_DIR/.seeded" ]]; then
        return
    fi

    local id
    id=$(next_mail_id)
    write_mail_file "$(folder_path inbox)/${id}.eml" "$id" \
        "alfred@wayne.enterprise" "$SESSION_EMAIL" \
        "Welcome to Why So Serious Mail" \
        "Master Bruce—or rather, fellow OS student—

Your offline mail fortress is ready.
Try Search, Star, Reply, Attachments, and the Dashboard.

— Alfred (simulated)" \
        "High" "Unread" "Yes"

    id=$(next_mail_id)
    write_mail_file "$(folder_path inbox)/${id}.eml" "$id" \
        "oracle@gotham.net" "$SESSION_EMAIL" \
        "Lab tip: file permissions matter" \
        "chmod 700 on your mailbox keeps other users out.
Your activity.log is an audit trail — classic OS logging.

— Oracle" \
        "Normal" "Unread" "No"

    id=$(next_mail_id)
    write_mail_file "$(folder_path spam)/${id}.eml" "$id" \
        "winner@totally-legit.biz" "$SESSION_EMAIL" \
        "URGENT FREE LOTTERY PRIZE!!!" \
        "Click here to claim your prize NOW!!!" \
        "Low" "Unread" "No"

    printf '%s\n' \
        "Alfred Pennyworth|alfred@wayne.enterprise|Butler" \
        "Barbara Gordon|oracle@gotham.net|Friend" \
        "Harvey Dent|harvey@gotham.gov|Contact" \
        >> "$CONTACTS_FILE"

    touch "$MAILBOX_DIR/.seeded"
    log_event INFO "Demo emails and contacts seeded"
}

# -----------------------------------------------------------------------------
# Auth
# -----------------------------------------------------------------------------

register_user() {
    local data username password email hash
    data=$(zenity --forms --title="Create Account" --width=480 \
        --text="Join the offline mail network" \
        --add-entry="Username" \
        --add-password="Password" \
        --add-entry="Your Email") || return 1

    username=$(echo "$data" | cut -d'|' -f1 | tr -d ' ')
    password=$(echo "$data" | cut -d'|' -f2)
    email=$(echo "$data" | cut -d'|' -f3 | tr -d ' ')

    if [[ -z "$username" || -z "$password" || -z "$email" ]]; then
        alert_error "All fields are required." 3; return 1
    fi
    if ! validate_email "$email"; then
        alert_error "Invalid email format." 3; return 1
    fi
    if grep -q "^${username}:" "$USERS_FILE" 2>/dev/null; then
        alert_error "Username already exists." 3; return 1
    fi

    hash=$(hash_password "$password")
    echo "${username}:${hash}:${email}" >> "$USERS_FILE"
    chmod 600 "$USERS_FILE"
    log_event INFO "User registered: $username"
    alert_info "Account created for <b>$username</b>." 3
}

login_user() {
    local data username password hash stored line email
    while true; do
        local choice
        choice=$(zenity --list --title="$APP_NAME — Login" --width=420 --height=260 \
            --text="<b>Secure local authentication</b>\nPasswords are SHA-256 hashed on disk." \
            --column="Action" \
            "Login" \
            "Create Account" \
            "Exit") || exit 0

        case "$choice" in
            "Create Account") register_user ;;
            "Exit"|"") exit 0 ;;
            "Login")
                data=$(zenity --forms --title="Login" --width=400 \
                    --add-entry="Username" \
                    --add-password="Password") || continue
                username=$(echo "$data" | cut -d'|' -f1 | tr -d ' ')
                password=$(echo "$data" | cut -d'|' -f2)
                hash=$(hash_password "$password")
                line=$(grep "^${username}:" "$USERS_FILE" 2>/dev/null || true)
                if [[ -z "$line" ]]; then
                    alert_error "Unknown user." 2; continue
                fi
                stored=$(echo "$line" | cut -d':' -f2)
                email=$(echo "$line" | cut -d':' -f3)
                if [[ "$hash" != "$stored" ]]; then
                    log_event WARN "Failed login for $username"
                    alert_error "Wrong password." 2
                    continue
                fi
                SESSION_USER="$username"
                SESSION_EMAIL="$email"
                log_event INFO "Login success"
                notify "$APP_NAME" "Welcome back, $SESSION_USER"
                return 0
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Contacts
# -----------------------------------------------------------------------------

manage_contacts() {
    while true; do
        local action
        action=$(zenity --list --title="Contacts" --width=420 --height=280 \
            --column="Action" \
            "View Contacts" \
            "Add Contact" \
            "Delete Contact" \
            "Back") || return

        case "$action" in
            "Back"|"") return ;;
            "View Contacts")
                if [[ ! -s "$CONTACTS_FILE" ]]; then
                    alert_info "No contacts yet." 2; continue
                fi
                zenity --text-info --title="Address Book" --width=520 --height=340 \
                    --filename=<(awk -F'|' '{printf "%-22s %-32s %s\n", $1, $2, $3}' "$CONTACTS_FILE") >/dev/null
                ;;
            "Add Contact")
                local data name email tag
                data=$(zenity --forms --title="Add Contact" --width=420 \
                    --add-entry="Name" --add-entry="Email" --add-entry="Tag") || continue
                name=$(echo "$data" | cut -d'|' -f1)
                email=$(echo "$data" | cut -d'|' -f2)
                tag=$(echo "$data" | cut -d'|' -f3)
                if ! validate_email "$email"; then alert_error "Invalid email." 2; continue; fi
                echo "${name}|${email}|${tag:-Friend}" >> "$CONTACTS_FILE"
                log_event INFO "Contact added: $email"
                alert_info "Contact saved." 2
                ;;
            "Delete Contact")
                if [[ ! -s "$CONTACTS_FILE" ]]; then alert_info "No contacts." 2; continue; fi
                local email_del
                email_del=$(awk -F'|' '{print $2}' "$CONTACTS_FILE" | zenity --list \
                    --title="Delete Contact" --width=420 --height=300 \
                    --column="Email") || continue
                grep -v "|${email_del}|" "$CONTACTS_FILE" > "$CONTACTS_FILE.tmp" && mv "$CONTACTS_FILE.tmp" "$CONTACTS_FILE"
                log_event INFO "Contact deleted: $email_del"
                alert_info "Deleted." 2
                ;;
        esac
    done
}

pick_recipient() {
    local email
    if [[ -s "$CONTACTS_FILE" ]]; then
        email=$(awk -F'|' '{print $2}' "$CONTACTS_FILE" | zenity --list \
            --title="Choose Recipient" --width=420 --height=300 \
            --text="Pick a contact — or cancel to type manually" \
            --column="Email") || true
        if [[ -n "${email:-}" ]]; then
            echo "$email"
            return
        fi
    fi
    zenity --entry --title="Recipient" --text="Enter email address:" --entry-text="friend@gotham.net" || true
}

# -----------------------------------------------------------------------------
# Compose / send / draft
# -----------------------------------------------------------------------------

compose_email() {
    local mode="${1:-send}"   # send | draft | reply | forward
    local preset_to="${2:-}"
    local preset_subject="${3:-}"
    local preset_body="${4:-}"

    local to subject body priority attachment attach_name="none"
    to="${preset_to}"
    if [[ -z "$to" ]]; then
        to=$(pick_recipient)
    fi
    [[ -z "$to" ]] && { alert_info "Cancelled." 2; return; }
    if ! validate_email "$to"; then
        alert_error "Invalid recipient email." 3; return
    fi

    local form
    form=$(zenity --forms --title="$( [[ "$mode" == draft ]] && echo 'Save Draft' || echo 'Compose Email' )" \
        --width=520 \
        --text="From: <b>$SESSION_EMAIL</b>\nTo: <b>$to</b>" \
        --add-entry="Subject" \
        --add-entry="Body (short — or leave blank to open editor)" \
        --add-combo="Priority" --combo-values="Normal|High|Low") || return

    subject=$(echo "$form" | cut -d'|' -f1)
    body=$(echo "$form" | cut -d'|' -f2)
    priority=$(echo "$form" | cut -d'|' -f3)
    [[ -n "$preset_subject" && -z "$subject" ]] && subject="$preset_subject"
    [[ -n "$preset_body" && -z "$body" ]] && body="$preset_body"

    if [[ -z "$subject" ]]; then
        alert_error "Subject is required." 2; return
    fi

    if [[ -z "$body" ]]; then
        body=$(zenity --text-info --editable --title="Message Body" --width=560 --height=360 \
            --filename=<(printf '%s' "${preset_body:-}")) || return
    fi
    [[ -z "$body" ]] && { alert_error "Body is required." 2; return; }

    if confirm_action "Attach a file?"; then
        attachment=$(zenity --file-selection --title="Select Attachment") || true
        if [[ -n "${attachment:-}" && -f "$attachment" ]]; then
            attach_name=$(basename "$attachment")
            cp "$attachment" "$ATTACH_DIR/${SESSION_USER}_$(date +%s)_$attach_name"
            log_event INFO "Attachment staged: $attach_name"
        fi
    fi

    if [[ "$mode" == "draft" ]]; then
        local id
        id=$(next_mail_id)
        write_mail_file "$(folder_path drafts)/${id}.eml" "$id" \
            "$SESSION_EMAIL" "$to" "$subject" "$body" "$priority" "Read" "No" "$attach_name"
        log_event INFO "Draft saved #$id"
        notify "$APP_NAME" "Draft saved"
        alert_info "Draft <b>#$id</b> saved." 3
        return
    fi

    # Background delivery simulation (process management demo)
    deliver_email_async "$to" "$subject" "$body" "$priority" "$attach_name"
}

deliver_email_async() {
    local to="$1" subject="$2" body="$3" priority="$4" attach_name="$5"
    local job_id="job_$(date +%s)_$$"
    local job_file="$QUEUE_DIR/$job_id"

    cat > "$job_file" <<EOF
TO=$to
SUBJECT=$subject
BODY<<ENDBODY
$body
ENDBODY
PRIORITY=$priority
ATTACH=$attach_name
EOF

    (
        # Simulate network / MTA delay in a background subshell
        sleep 1
        id=$(next_mail_id)

        if is_spam "$subject" "$body"; then
            write_mail_file "$(folder_path spam)/${id}.eml" "$id" \
                "$SESSION_EMAIL" "$to" "$subject" "$body" "$priority" "Unread" "No" "$attach_name"
            sent_id=$(next_mail_id)
            write_mail_file "$(folder_path sent)/${sent_id}.eml" "$sent_id" \
                "$SESSION_EMAIL" "$to" "[spam-flagged] $subject" "$body" "$priority" "Read" "No" "$attach_name"
            log_event WARN "Spam filtered mail to $to (score triggered)"
            notify "$APP_NAME" "Spam filtered: $subject"
        else
            sent_id=$(next_mail_id)
            write_mail_file "$(folder_path sent)/${sent_id}.eml" "$sent_id" \
                "$SESSION_EMAIL" "$to" "$subject" "$body" "$priority" "Read" "No" "$attach_name"
            inbox_id=$(next_mail_id)
            write_mail_file "$(folder_path inbox)/${inbox_id}.eml" "$inbox_id" \
                "$SESSION_EMAIL" "$to" "$subject" "$body" "$priority" "Unread" "No" "$attach_name"
            log_event INFO "Delivered mail #$sent_id to $to (bg pid $$)"
            notify "$APP_NAME" "Delivered: $subject"
        fi
        rm -f "$job_file"
    ) &

    local bg_pid=$!
    log_event INFO "Queued delivery job $job_id (background PID $bg_pid)"
    zenity --info --title="$APP_NAME" --width=420 --timeout=3 \
        --text="Email queued for delivery.\n\nBackground PID: <b>$bg_pid</b>\n(OS process management demo)\n\nCheck Sent / Inbox in a moment."
}

# -----------------------------------------------------------------------------
# Browse / search / act on mail
# -----------------------------------------------------------------------------

select_folder() {
    zenity --list --title="Choose Folder" --width=360 --height=280 \
        --column="Folder" --column="Count" \
        "inbox" "$(count_mails inbox)" \
        "sent" "$(count_mails sent)" \
        "drafts" "$(count_mails drafts)" \
        "spam" "$(count_mails spam)" \
        "trash" "$(count_mails trash)"
}

list_folder_mails() {
    local folder="$1"
    local file tmp title
    tmp=$(mktemp)
    title=$(printf '%s' "$folder" | tr '[:lower:]' '[:upper:]')

    for file in "$(folder_path "$folder")"/*.eml; do
        [[ -f "$file" ]] || continue
        mail_list_row "$file" >> "$tmp"
    done

    if [[ ! -s "$tmp" ]]; then
        rm -f "$tmp"
        alert_info "No emails in <b>$folder</b>." 2
        return 1
    fi

    # Build zenity args safely (bash 3.2 + spaces in subjects)
    local args=()
    local id from subject date priority star
    while IFS='|' read -r id from subject date priority star; do
        args+=("$id" "$from" "$subject" "$date" "$priority" "$star")
    done < <(sort -t'|' -k4 -r "$tmp")

    local selected
    selected=$(zenity --list --title="$title — Mail" \
        --width=780 --height=420 \
        --print-column=1 \
        --column="ID" --column="From" --column="Subject" --column="Date" --column="Priority" --column="★" \
        "${args[@]}") || { rm -f "$tmp"; return 1; }

    rm -f "$tmp"
    echo "$selected"
}

open_mail() {
    local folder="$1" id="$2"
    local file="$(folder_path "$folder")/${id}.eml"
    [[ -f "$file" ]] || { alert_error "Mail not found." 2; return; }

    # Mark read
    if grep -q '^Status: Unread' "$file"; then
        sed -i.bak 's/^Status: Unread/Status: Read/' "$file" && rm -f "${file}.bak"
    fi

    local content
    content=$(cat "$file")
    zenity --text-info --title="Mail #$id" --width=620 --height=440 \
        --filename=<(printf '%s\n' "$content") >/dev/null

    mail_actions "$folder" "$id"
}

mail_actions() {
    local folder="$1" id="$2"
    local file="$(folder_path "$folder")/${id}.eml"
    local action from subject body

    action=$(zenity --list --title="Mail #$id Actions" --width=400 --height=360 \
        --column="Action" \
        "Reply" \
        "Forward" \
        "Toggle Star" \
        "Move to Trash" \
        "Restore to Inbox" \
        "Delete Forever" \
        "Open Attachment" \
        "Back") || return

    from=$(read_header "$file" "From")
    subject=$(read_header "$file" "Subject")
    body=$(read_body "$file")

    case "$action" in
        "Reply")
            local reply_body
            reply_body=$(printf 'On previous message:\n%s\n\n---\n' "$body")
            compose_email "reply" "$from" "Re: $subject" "$reply_body"
            ;;
        "Forward")
            local fwd_body
            fwd_body=$(printf '---------- Forwarded message ----------\n%s' "$body")
            compose_email "forward" "" "Fwd: $subject" "$fwd_body"
            ;;
        "Toggle Star")
            if grep -q '^Starred: Yes' "$file"; then
                sed -i.bak 's/^Starred: Yes/Starred: No/' "$file"
            else
                sed -i.bak 's/^Starred: No/Starred: Yes/' "$file"
            fi
            rm -f "${file}.bak"
            alert_info "Star toggled." 2
            ;;
        "Move to Trash")
            if [[ "$folder" != "trash" ]]; then
                mv "$file" "$(folder_path trash)/${id}.eml"
                log_event INFO "Moved #$id from $folder → trash"
                alert_info "Moved to Trash." 2
            fi
            ;;
        "Restore to Inbox")
            if [[ "$folder" == "trash" || "$folder" == "spam" ]]; then
                mv "$file" "$(folder_path inbox)/${id}.eml"
                log_event INFO "Restored #$id to inbox"
                alert_info "Restored to Inbox." 2
            else
                alert_warn "Restore is for Trash/Spam only." 2
            fi
            ;;
        "Delete Forever")
            confirm_action "Permanently delete mail #$id?" || return
            rm -f "$file"
            log_event WARN "Permanently deleted #$id"
            alert_info "Deleted forever." 2
            ;;
        "Open Attachment")
            local att
            att=$(read_header "$file" "Attachment")
            if [[ "$att" == "none" || -z "$att" ]]; then
                alert_info "No attachment." 2
            else
                local found
                found=$(find "$ATTACH_DIR" -name "*${att}" | head -1)
                if [[ -n "$found" ]]; then
                    open "$found" 2>/dev/null || xdg-open "$found" 2>/dev/null || alert_info "Saved at:\n$found" 4
                else
                    alert_info "Attachment record: $att\n(file not found on disk)" 3
                fi
            fi
            ;;
    esac
}

browse_mail() {
    while true; do
        local folder id
        folder=$(select_folder) || return
        [[ -z "$folder" ]] && return
        id=$(list_folder_mails "$folder") || continue
        [[ -z "$id" ]] && continue
        open_mail "$folder" "$id"
    done
}

search_mail() {
    local query
    query=$(zenity --entry --title="Search Mail" --width=420 \
        --text="Search subject, from, to, or body:") || return
    [[ -z "$query" ]] && return

    local tmp results=0
    tmp=$(mktemp)
    local folder file
    for folder in "${FOLDERS[@]}"; do
        for file in "$(folder_path "$folder")"/*.eml; do
            [[ -f "$file" ]] || continue
            if grep -qi -- "$query" "$file"; then
                local id from subject
                id=$(basename "$file" .eml)
                from=$(read_header "$file" "From")
                subject=$(read_header "$file" "Subject")
                printf '%s|%s|%s|%s\n' "$folder" "$id" "$from" "$subject" >> "$tmp"
                results=$((results + 1))
            fi
        done
    done

    if (( results == 0 )); then
        rm -f "$tmp"
        alert_info "No matches for <b>$query</b>." 3
        return
    fi

    local args=() folder id from subject
    while IFS='|' read -r folder id from subject; do
        args+=("$folder" "$id" "$from" "$subject")
    done < "$tmp"

    local pick
    pick=$(zenity --list --title="Search: $query ($results hits)" --width=700 --height=400 \
        --print-column=ALL --separator="|" \
        --column="Folder" --column="ID" --column="From" --column="Subject" \
        "${args[@]}") || { rm -f "$tmp"; return; }
    rm -f "$tmp"

    folder=$(echo "$pick" | cut -d'|' -f1)
    id=$(echo "$pick" | cut -d'|' -f2)
    open_mail "$folder" "$id"
}

# -----------------------------------------------------------------------------
# Bulk trash ops
# -----------------------------------------------------------------------------

delete_menu() {
    while true; do
        local choice
        choice=$(zenity --list --title="Cleanup" --width=420 --height=320 \
            --column="Action" \
            "Empty entire folder → Trash" \
            "Empty Trash forever" \
            "Empty Spam" \
            "Back") || return
        case "$choice" in
            "Back"|"") return ;;
            "Empty entire folder → Trash")
                local folder
                folder=$(zenity --list --title="Source" --column="Folder" inbox sent drafts spam) || continue
                confirm_action "Move ALL mail from <b>$folder</b> to Trash?" || continue
                local f
                for f in "$(folder_path "$folder")"/*.eml; do
                    [[ -f "$f" ]] || continue
                    mv "$f" "$(folder_path trash)/"
                done
                log_event WARN "Emptied $folder → trash"
                alert_info "Done." 2
                ;;
            "Empty Trash forever")
                confirm_action "⚠ Permanently delete EVERYTHING in Trash?" || continue
                rm -f "$(folder_path trash)"/*.eml
                log_event WARN "Trash emptied permanently"
                alert_info "Trash is empty." 2
                ;;
            "Empty Spam")
                confirm_action "Delete all spam forever?" || continue
                rm -f "$(folder_path spam)"/*.eml
                log_event WARN "Spam emptied"
                alert_info "Spam cleared." 2
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Dashboard / logs / OS demo
# -----------------------------------------------------------------------------

show_dashboard() {
    local inbox sent drafts spam trash total starred unread
    inbox=$(count_mails inbox)
    sent=$(count_mails sent)
    drafts=$(count_mails drafts)
    spam=$(count_mails spam)
    trash=$(count_mails trash)
    total=$((inbox + sent + drafts + spam + trash))
    starred=$(grep -rl '^Starred: Yes' "$MAILBOX_DIR" --include='*.eml' 2>/dev/null | wc -l | tr -d ' ')
    unread=$(grep -rl '^Status: Unread' "$(folder_path inbox)" --include='*.eml' 2>/dev/null | wc -l | tr -d ' ')

    local queue_jobs perms disk
    queue_jobs=$(find "$QUEUE_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
    perms=$(stat -f '%Sp %N' "$MAILBOX_DIR" 2>/dev/null || stat -c '%A %n' "$MAILBOX_DIR" 2>/dev/null)
    disk=$(du -sh "$MAILBOX_DIR" 2>/dev/null | awk '{print $1}')

    local report
    report=$(cat <<EOF
╔══════════════════════════════════════╗
║     WHY SO SERIOUS — DASHBOARD       ║
╚══════════════════════════════════════╝

User:     $SESSION_USER
Email:    $SESSION_EMAIL
Mailbox:  $MAILBOX_DIR
Perms:    $perms
Disk:     $disk

── Folders ────────────────────────────
  Inbox     $inbox   (unread: $unread)
  Sent      $sent
  Drafts    $drafts
  Spam      $spam
  Trash     $trash
  ─────────────────
  Total     $total
  Starred   $starred

── Live OS stats ──────────────────────
  Delivery queue jobs: $queue_jobs
  Log lines:           $(wc -l < "$LOG_FILE" | tr -d ' ')
  Contacts:            $(grep -c . "$CONTACTS_FILE" 2>/dev/null || echo 0)
  Attachments:         $(find "$ATTACH_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')

Tip: Background send uses a subshell PID —
watch Activity Log for process events.
EOF
)
    zenity --text-info --title="Dashboard" --width=520 --height=520 \
        --filename=<(printf '%s\n' "$report") >/dev/null
}

show_activity_log() {
    if [[ ! -s "$LOG_FILE" ]]; then
        alert_info "Log is empty." 2; return
    fi
    zenity --text-info --title="Activity Log (tail)" --width=700 --height=420 \
        --filename=<(tail -n 80 "$LOG_FILE") >/dev/null
}

show_templates() {
    local pick body subject
    pick=$(zenity --list --title="Quick Templates" --width=480 --height=280 \
        --column="Template" \
        "Meeting Request" \
        "Lab Submission" \
        "Thank You" \
        "Apology / Delay" \
        "Cancel") || return
    case "$pick" in
        "Meeting Request")
            subject="Meeting request"
            body="Hi,

Could we meet this week to discuss the OS lab project?
Please suggest a time that works for you.

Thanks,
$SESSION_USER"
            ;;
        "Lab Submission")
            subject="CSE324 Lab Submission"
            body="Dear Course Teacher,

Please find my CSE324 Operating System Lab submission attached/described below.

Regards,
$SESSION_USER
$SESSION_EMAIL"
            ;;
        "Thank You")
            subject="Thank you"
            body="Hi,

Thank you for your help — I really appreciate it.

Best,
$SESSION_USER"
            ;;
        "Apology / Delay")
            subject="Running a bit late"
            body="Hi,

Apologies for the delay. I will follow up shortly.

— $SESSION_USER"
            ;;
        *) return ;;
    esac
    compose_email "send" "" "$subject" "$body"
}

process_demo() {
    # Fun OS concept showcase
    (
        for i in 1 2 3; do
            echo "#$i fake worker $$ sleeping..."; sleep 1
        done
    ) | zenity --progress --title="Process Demo" --text="Spawning worker processes..." \
        --percentage=0 --auto-close --pulsate 2>/dev/null || true

    local info
    info=$(cat <<EOF
OS Concepts in this app
───────────────────────
• chmod 700 mailbox → discretionary access control
• SHA-256 password hashes → no plaintext secrets
• Background subshells → process creation & async I/O
• activity.log → system-style audit logging
• queue/ → simple mail transfer agent job queue
• Per-mail .eml files → file-system as database
• grep/awk/sed/find → classic Unix tool pipeline

Current shell PID: $$
Mailbox inode dir: $MAILBOX_DIR
EOF
)
    zenity --text-info --title="OS Concepts" --width=520 --height=380 \
        --filename=<(printf '%s\n' "$info") >/dev/null
}

# -----------------------------------------------------------------------------
# Main menu
# -----------------------------------------------------------------------------

main_menu() {
    while true; do
        local unread choice
        unread=$(grep -rl '^Status: Unread' "$(folder_path inbox)" --include='*.eml' 2>/dev/null | wc -l | tr -d ' ')

        choice=$(zenity --list --title="$APP_NAME" --width=480 --height=460 \
            --text="<span size='large'><b>🦇 Why So Serious Mail</b></span>\nUser: <b>$SESSION_USER</b>  ·  Unread: <b>$unread</b>" \
            --column="Menu" \
            "✉  Compose / Send" \
            "📝  Save Draft" \
            "📂  Browse Mailboxes" \
            "🔍  Search" \
            "⚡  Quick Templates" \
            "👤  Contacts" \
            "📊  Dashboard" \
            "🧹  Cleanup" \
            "📜  Activity Log" \
            "🧠  OS Concepts Demo" \
            "🚪  Logout / Exit") || choice="🚪  Logout / Exit"

        case "$choice" in
            "✉  Compose / Send")      compose_email send ;;
            "📝  Save Draft")         compose_email draft ;;
            "📂  Browse Mailboxes")   browse_mail ;;
            "🔍  Search")             search_mail ;;
            "⚡  Quick Templates")    show_templates ;;
            "👤  Contacts")           manage_contacts ;;
            "📊  Dashboard")          show_dashboard ;;
            "🧹  Cleanup")            delete_menu ;;
            "📜  Activity Log")       show_activity_log ;;
            "🧠  OS Concepts Demo")   process_demo ;;
            "🚪  Logout / Exit"|*)
                log_event INFO "Session ended"
                notify "$APP_NAME" "Goodbye, $SESSION_USER"
                alert_info "Why so serious?\n\nSee you next time, <b>$SESSION_USER</b>." 3
                break
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Entry
# -----------------------------------------------------------------------------

require_zenity() {
    if ! command -v zenity &>/dev/null; then
        echo "Zenity is required. Install with: brew install zenity" >&2
        exit 1
    fi
}

require_zenity
initialize_mailbox
login_user
seed_demo_data
main_menu
