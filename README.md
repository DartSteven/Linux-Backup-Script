
# Backup Script for Multiple Directories and Databases

This script automates the process of backing up multiple directories and databases, compressing them, and sending a detailed report via email. It supports encryption, email notifications, Docker service management, and database backups.

## Features

- **Multiple Directories and Databases**: You can specify multiple directories and Docker-based databases to back up.
- **Exclusion of Directories**: Option to exclude certain directories from the backup process.
- **Compression and Optional Encryption**: Backups are compressed using `pigz`, and encryption with AES-256 can be enabled or disabled.
- **Email Reports**: Sends a detailed report after each backup operation, including backup size, MD5 checksum, and disk write speed.
- **Docker Management**: The script can stop Docker services before the backup and restart them afterward.
- **Database Backup**: Supports the backup of PostgreSQL, Redis, and other Docker-managed databases.
- **Customizable**: Fully customizable with variables for backup names, source directories, email settings, database backup options, and retention policies.
- **Backup to Multiple Destinations**: Option to back up files to two separate SATA disks for redundancy (1,2,3 principle).



## Theme Comparison: Dark vs Light

<div style="text-align: center;">
  <table>
    <tr>
      <td align="center"><strong>Dark Theme</strong></td>
      <td align="center"><strong>Light Theme</strong></td>
    </tr>
    <tr>
      <td align="center">
        <img src="https://github.com/DartSteven/Linux-Backup-Script/raw/main/Sample%20Template%20Preview/Samlple%20Dark%20Theme%20-%20small%20-%20Directory.png" alt="Samlple Dark Theme - small - Directory" width="300"/>
        <br>Directory
      </td>
      <td align="center">
        <img src="https://github.com/DartSteven/Linux-Backup-Script/raw/main/Sample%20Template%20Preview/Sample%20Light%20Theme%20-%20small%20-%20Directory.png" alt="Sample Light Theme - Directory" width="300"/>
        <br>Directory
      </td>
    </tr>
    <tr>
      <td align="center">
        <img src="https://github.com/DartSteven/Linux-Backup-Script/raw/main/Sample%20Template%20Preview/Samlple%20Dark%20Theme%20-%20small%20-%20Database.png" alt="Samlple Dark Theme - small - Database" width="300"/>
        <br>Database
      </td>
      <td align="center">
        <img src="https://github.com/DartSteven/Linux-Backup-Script/raw/main/Sample%20Template%20Preview/Sample%20Light%20Theme%20-%20small%20-%20Database.png" alt="Sample Light Theme - Database" width="300"/>
        <br>Database
      </td>
    </tr>
    <tr>
      <td align="center">
        <img src="https://github.com/DartSteven/Linux-Backup-Script/raw/main/Sample%20Template%20Preview/Samlple%20Dark%20Theme%20-%20small%20-%20Statistics.png" alt="Samlple Dark Theme - small - Statistics" width="300"/>
        <br>Statistics
      </td>
      <td align="center">
        <img src="https://github.com/DartSteven/Linux-Backup-Script/raw/main/Sample%20Template%20Preview/Sample%20Light%20Theme%20-%20small%20-%20Statistics.png" alt="Sample Light Theme - Statistics" width="300"/>
        <br>Statistics
      </td>
    </tr>
  </table>
</div>


## Prerequisites

Before running the script, ensure that the following packages are installed on your Linux system:

- `tar`
- `pv`
- `pigz`
- `openssl`
- `msmtp`
- `coreutils`

The script will automatically check and install these packages if they are not available on your system.

## Configuration

The script includes several variables that can be customized:

- **Backup name**: `BACKUP_NAME` – Defines the name of the backup.
- **Server name**: `SERVER_NAME` – Name of the server to include in the email report.
- **Encryption**: `ENCRYPT_BACKUP` – Set to `Y` to enable encryption of backup files, or `N` to disable it.
- **Source directories**: `SOURCE_DIRS` – List of directories to include in the backup.
- **Exclude directories**: `EXCLUDE_DIRS` – List of directories to exclude from the backup.
- **Backup directory**: `BACKUP_DIR` – Where the backups will be saved.
- **Email settings**: Set the recipient, SMTP host, port, and credentials for sending the backup report via email.
- **Database backup**: `BACKUP_DOCKER_DATABASE` – Set to `Y` to enable Docker database backups.
- **Database list**: `DATABASES` – Define which databases to back up, including container name, database name, and credentials.
- **Backup retention**: `DAYS_TO_KEEP` – Number of days to keep old backups.
- **Backup destinations**: `BACKUP_123` – Set to `Y` to enable backup to additional disks.
- **Max CPU cores**: `MAX_CPU_CORE` – Set the number of CPU cores to use for compression.

Example
An example of the source and excluded directories setup:

```bash
SOURCE_DIRS=(
        "/home/JohnDoe"
        "/etc"
)

    EXCLUDE_DIRS=(
        "/home/JohnDoe/Personal"
)

DATABASES=(
    "PostgreSQL|Joplin-Postgress|joplindb|joplin|password"
    "Redis|immich_redis||"
)
```

## **Automate with cron**

You can automate the backup process by adding it to your crontab. For example, to run the backup every day at midnight:

```bash
0 0 * * * /path/to/backup.sh
```

## Usage

1. **Modify the variables**: Edit the script to set the directories and databases to back up, email settings, and other configuration options.
2. **Run the script**: Make sure you are running the script as root or with `sudo`: 
   ```bash
   sudo ./backup.sh
   ```

## iCloud Users: Configure Email Notifications

To configure the script to send email notifications using iCloud's SMTP server:

1. **Generate an App-Specific Password for iCloud**:
   - Go to [appleid.apple.com](https://appleid.apple.com) and generate a password for third-party apps.

2. **Update the Script** with iCloud SMTP settings:
   ```bash
   EMAIL_RECIPIENT="youraddress@icloud.com"
   SMTP_HOST="smtp.mail.me.com"
   SMTP_PORT="587"
   SMTP_FROM="youraddress@icloud.com"
   SMTP_USER="youraddress@icloud.com"
   SMTP_PASSWORD="app-specific-password"
   ```

## Changelog

### [2.0] - 2024-09-16
#### Added
- Added Docker-managed database backup functionality for PostgreSQL, Redis, and other databases.
- Added option to back up to multiple SATA disks for redundancy (1,2,3 principle).
- Introduced the ability to limit the number of CPU cores for compression.
- Added functionality to select different email templates.

#### Changed
- Updated backup source directories to `/media/nvme/1TB/ORI1` and `/media/nvme/1TB/ORI2`.
- Updated the encryption option to be disabled by default.

### [1.0.0] - 2024-09-08
#### Added
- Initial release of the backup script.
