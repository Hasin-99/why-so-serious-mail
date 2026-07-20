# Why So Serious Mail

> Offline mail client for the **CSE324 Operating System Lab** — built entirely with **Bash** and **Zenity**.

A lightweight, privacy-first email simulator that never needs the cloud. All data stays on your machine. Along the way it puts core OS ideas to work: processes, file I/O, permissions, logging, and a simple delivery queue.

---

## Features

- **Secure login** — accounts with SHA-256 hashed passwords (no plaintext on disk)
- **Full mailbox** — Inbox, Sent, Drafts, Spam, Trash as real folders of `.eml` files
- **Compose & deliver** — send mail in a background process (shows the worker PID)
- **Read & act** — open messages, reply, forward, star, trash, restore, or delete forever
- **Search** — find mail across every folder by subject, sender, or body
- **Contacts & templates** — address book plus quick-start message templates
- **Attachments** — pick a file and stage it locally
- **Spam filter** — keyword + shouty-subject scoring
- **Dashboard** — live counts, disk use, queue depth, and mailbox permissions
- **Activity log** — audit trail of logins, sends, deletes, and system events
- **macOS notifications** — desktop alerts when mail is delivered or filtered

---

## Requirements

| Tool | Purpose |
|------|---------|
| **Bash** | Script runtime |
| **Zenity** | GUI dialogs |
| **shasum** | Password hashing (preinstalled on macOS) |

Install Zenity on macOS:

```bash
brew install zenity
```

---

## Quick start

```bash
git clone https://github.com/Hasin-99/why-so-serious-mail.git
cd why-so-serious-mail
chmod +x set_up_mail_server.sh
./set_up_mail_server.sh
```

1. Choose **Create Account** and set a username, password, and email  
2. Browse the seeded demo messages in **Inbox** and **Spam**  
3. Try **Compose**, **Search**, **Contacts**, **Dashboard**, and **OS Concepts Demo**

---

## Project layout

```
why-so-serious-mail/
├── set_up_mail_server.sh          # Main app (advanced edition)
├── set_up_mail_server_classic.sh  # Original simpler version
├── setup_mail_server.sh           # Earlier draft
├── dns_server.sh                  # Related OS lab scripts
├── ensure_dns_configuration.sh
├── setup_printer_server.sh
└── README.md
```

User data is stored under:

```
~/.why_so_serious/
├── inbox/  sent/  drafts/  spam/  trash/   # *.eml messages
├── attachments/                            # staged files
├── queue/                                  # background delivery jobs
├── users.db                                # hashed credentials
├── contacts.csv
├── activity.log
└── config.env
```

The mailbox directory is created with `chmod 700` so only your user can read it.

---

## OS concepts demonstrated

| Concept | How it shows up in the app |
|---------|----------------------------|
| **Process management** | Background subshell delivers mail; PID is shown in the UI |
| **File systems & I/O** | One `.eml` file per message; folders act as the database |
| **Permissions** | `chmod 700` / `600` on mailbox and secrets |
| **Logging** | Timestamped `activity.log` for audits |
| **Job queues** | `queue/` holds pending delivery jobs |
| **Text processing** | `grep`, `awk`, `sed`, `find`, `sort` for search and metadata |

Open **OS Concepts Demo** from the main menu for an in-app walkthrough.

---

## Course info

| | |
|---|---|
| **Course** | CSE324 — Operating System Lab |
| **Institution** | Daffodil International University |
| **Project** | Setting Up a Mail Server (offline simulation) |
| **Group** | A1 |

---

## License

Educational project for CSE324. Feel free to fork and adapt for learning.
