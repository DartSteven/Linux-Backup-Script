# Backup Script for Multiple Directories

This script automates the process of backing up multiple directories, compressing them, and sending a detailed report via email. It also supports encryption of backup files with AES-256, email notifications, and Docker service management.

## Features

- **Multiple Directories**: You can specify multiple directories to back up.
- **Exclusion of Directories**: Option to exclude certain directories from the backup process.
- **Compression and Encryption**: Backups are compressed using `pigz` and can be optionally encrypted with AES-256.
- **Email Reports**: Sends a detailed report after each backup operation, including backup size, MD5 checksum, and disk write speed.
- **Docker Management**: Option to stop Docker services before backup and restart them after the process.
- **Customizable**: Fully customizable with variables for backup names, source directories, email settings, and retention policies.


![Sample](https://github.com/DartSteven/Backup/blob/main/Sample.png)



## Prerequisites

Before running the script, ensure that the following packages are installed on your Linux system:

- `tar`
- `pv`
- `pigz`
- `openssl`
- `msmtp` (for sending email reports)

The script will automatically check and install these packages if they are not available on your system.

## Configuration

The script includes several variables that can be customized:

- **Backup name**: `BACKUP_NAME` – Defines the name of the backup.
- **Server name**: `SERVER_NAME` – Name of the server to include in the email report.
- **Encryption**: `ENCRYPT_BACKUP` – Set to `Y` to enable encryption of backup files.
- **Source directories**: `SOURCE_DIRS` – List of directories to include in the backup.
- **Exclude directories**: `EXCLUDE_DIRS` – List of directories to exclude from the backup.
- **Backup directory**: `BACKUP_DIR` – Where the backups will be saved.
- **Email settings**: Set the recipient, SMTP host, port, and credentials for sending the backup report via email.
- **Backup retention**: `DAYS_TO_KEEP` – Number of days to keep old backups.

Example  
An example of the source and excluded directories setup:

    SOURCE_DIRS=(
        "/home/JohnDoe"
        "/etc"
    )
 
    EXCLUDE_DIRS=(
        "/home/JohnDoe/Personal"
    )

## **Automate with cron**:

You can automate the backup process by adding it to your crontab. For example, to run the backup every day at midnight:

    0 0 * * * /path/to/backup.sh


## Usage

1. **Modify the variables**: Edit the script to set the directories to back up, email settings, and other configuration options.
2. **Run the script**: Make sure you are running the script as root or with `sudo`: sudo ./backup.sh



<br>
<br>




## Attention to iCloud users : Configure Email Notifications with iCloud

To configure the script to send email notifications using iCloud's SMTP server, follow these steps:

### 1. Generate an App-Specific Password for iCloud

iCloud requires an **app-specific password** for third-party applications (like this script) to send emails. Here's how you can generate one:

1. Go to [appleid.apple.com](https://appleid.apple.com) and sign in with your Apple ID.
2. In the **Security** section, look for **App-Specific Passwords** and click **Generate Password**.
3. Enter a label for the password (e.g., "Backup Script") and click **Create**.
4. Copy the password that is generated.

### 2. Update the Script with iCloud SMTP Settings

Edit the script and update the following SMTP variables to configure iCloud email notifications:

```bash
EMAIL_RECIPIENT="youraddress@icloud.com"  # The address that will receive the report
SMTP_HOST="smtp.mail.me.com"
SMTP_PORT="587"
SMTP_FROM="youraddress@icloud.com"  # Your iCloud email address
SMTP_USER="youraddress@icloud.com"  # Your Apple ID (iCloud email address)
SMTP_PASSWORD="app-specific-password"  # The app-specific password generated from iCloud*
