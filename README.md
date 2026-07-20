# Why So Serious Mail — Advanced Edition

CSE324 Operating System Lab project: offline mail client built with **Bash + Zenity**.

## Run

```bash
cd OS_Project
./set_up_mail_server.sh
```

1. Create an account (password is SHA-256 hashed)
2. Explore seeded demo mail in Inbox / Spam
3. Try Compose, Search, Contacts, Dashboard, OS Concepts Demo

Classic original backup: `set_up_mail_server_classic.sh`

## What’s new

| Feature | Why it’s cool (OS angle) |
|---|---|
| Login + hashed passwords | Access control / no plaintext secrets |
| Per-mail `.eml` files in folders | File system as a database |
| `chmod 700` mailbox | Discretionary access control |
| Background send queue | Process creation & async delivery |
| Activity log | System-style audit logging |
| Search / star / reply / forward | Real mail-client UX |
| Attachments | File I/O + staging directory |
| Spam scoring | Simple content filter |
| Contacts + templates | Productivity extras |
| Dashboard | Live counts, disk, queue, perms |

Data lives in `~/.why_so_serious/` (persists between runs).
