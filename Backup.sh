#!/bin/bash

# Backup Script for Directories with Special Focus on Docker and Its Databases
#
# Description:
# This script is designed to automate the backup process for directories on a Linux-based server,
# with special attention to Docker containers and their associated databases. It was created to provide
# a reliable, flexible, and efficient way to safeguard critical data from directories and Dockerized
# applications, ensuring easy restoration when needed.
#
# Key Features:
# - Backs up important directories and Docker databases, including PostgreSQL, MySQL, Redis, and more.
# - Provides the option to encrypt backups using AES-256 encryption for enhanced data security.
# - Implements the "1-2-3" backup strategy, copying backups to multiple locations for redundancy.
# - Allows for stopping and restarting Docker services to ensure consistent database snapshots.
# - Sends detailed backup reports via email, covering backup status, sizes, durations, and verification results.
# - Utilizes CPU parallelism for efficient compression, optimizing backup times on systems with multiple cores.
# - Offers customizable retention policies to automatically clean up old backups after a specified number of days.
# - Automatically detects the Linux distribution and installs required packages.
#   - Supported distributions include Ubuntu, Debian, CentOS, RHEL, Fedora, and Arch Linux.
#
# Why This Script Was Created:
# This script was created to simplify and automate the process of backing up critical directories and Dockerized
# applications, particularly their databases. By handling these tasks automatically, the script minimizes the risk
# of data loss, reduces downtime in case of failures, and ensures that backups are performed consistently and securely.
#
# The script is highly customizable, allowing users to define backup directories, email configurations, and encryption
# preferences. It’s an ideal solution for system administrators who need a powerful tool to protect data and ensure
# disaster recovery, with a special focus on Docker environments.




# Variable for naming the backup that will be sent via email
# 	•	Example: BACKUP_NAME="Docker-Compose, /etc, Databases"
#	•	You can change the name to reflect the content of your backup.
#	•	If you are backing up specific directories or databases, you can include their names in the BACKUP_NAME.
BACKUP_NAME=""

# Variable for the Server name
# 	•	This variable stores the name of the server where the backup script is running.
#	•	Example: SERVER_NAME="HOME SERVER"
#	•	This can be customized to any server name that makes sense for your environment, and it will be included in email notifications.
SERVER_NAME=""

# Variable to enable backup encryption
#   •	This variable is used to determine whether to encrypt the backup files.
#	•	Values: "Y" or "N".
#	•	If you set ENCRYPT_BACKUP="Y", the backup will be encrypted with AES-256. If set to "N", no encryption will be applied.
ENCRYPT_BACKUP="Y"


# Default variables for the source directories
# 	•	This is an array of directories you wish to back up.
#	•	Example: SOURCE_DIRS=( "/home/JohnDoe" "/etc" )
#	•	You can add multiple directories by separating each path with a space. Make sure each path points to valid directories you want to back up.
SOURCE_DIRS=(
        "/home/JohnDoe"
        "/etc"
)

# Default variables for exlude directories
#   •	This is an array of directories you want to exclude from the backup.
#	•	Example: EXCLUDE_DIRS=( "/home/JohnDoe/Personal" )
#	•	You can leave this array empty if you do not want to exclude any directories, or add paths you want to skip.
EXCLUDE_DIRS=(
    "/home/JohnDoe/Personal"
)

# Backup destination directory
# 	•	This is the destination directory where the backups will be stored.
#	•	Example: BACKUP_DIR="/media/nvme/1TB/BACKUP"
#	•	This should point to the directory where you have sufficient storage space for backups.
BACKUP_DIR=""

# Log file for the backup script
LOG_FILE="$BACKUP_DIR/Compose.log"

# Email Configuration Variables
#	•	EMAIL_RECIPIENT: The email address to which the backup report will be sent. Example: EMAIL_RECIPIENT="JohnDoe@icloud.com"
#	•	SMTP Configuration Variables (SMTP_HOST, SMTP_PORT, SMTP_FROM, SMTP_USER, SMTP_PASSWORD):
#	•	These variables define the SMTP configuration needed to send emails.
#	•	Example:
#	•	SMTP_HOST="smtp.mail.me.com" (The SMTP server for sending emails)
#	•	SMTP_PORT="587" (The port for SMTP, typically 587 for TLS)
#	•	SMTP_FROM="JohnDoe@icloud.com" (The email address from which the email will be sent)
#	•	SMTP_USER="JohnDoe@icloud.com" (SMTP username, often the same as the sender’s email)
#	•	SMTP_PASSWORD="your-password" (Password for SMTP authentication) The app-specific password generated from iCloud*
EMAIL_RECIPIENT=""
SMTP_HOST=""
SMTP_PORT=""
SMTP_FROM=""
SMTP_USER=""
SMTP_PASSWORD=""

# Variable to define how many days to retain backups, Change the number of days as needed
# 	•	This defines how many days to retain the backup files before they are automatically deleted.
#	•	Example: DAYS_TO_KEEP=6
#	•	You can adjust the number of days to suit your retention policy.
DAYS_TO_KEEP=6

# Variable to stop Docker before the backup
#   •	This variable controls whether Docker containers should be stopped before starting the backup.
#	•	Values: "Y" or "N".
#	•	Set it to "Y" if you want Docker services to stop before the backup (useful when you are backing up Docker data).
STOP_DOCKER_BEFORE_BACKUP="Y"

# Variable to enable database backup
# 	•	This controls whether Docker databases should be backed up.
#	•	Values: "Y" or "N".
#	•	If set to "Y", the script will perform backups of the databases listed in the DATABASES variable.
BACKUP_DOCKER_DATABASE="Y"

# Backup destination database directory
# 	•	The destination directory where database backups will be stored.
#	•	Example: BACKUP_DATABASE_DIR="/media/nvme/1TB/BACKUP/backup_databases"
#	•	Make sure this points to a directory with enough space to store database backups.
BACKUP_DATABASE_DIR=""

# List of databases to back up; in the logic of DB | CONTAINER-NAME | DB-NAME | DB-USER-NAME | DB-PASSWORD. Example follows below.
# 	•	This is an array listing all the databases to be backed up. The format is:
#	•	DB_TYPE|CONTAINER_NAME|DB_NAME|DB_USER|DB_PASSWORD
#   •	Example: DATABASES=( "PostgreSQL|Joplin-Postgress|joplindb|joplin|joplin"
#   •	You can add multiple databases by separating each entry with a space. Make sure each entry is in the correct format.
#   •	You can find the database type, container name, database name, database user, and password by running the docker-compose ps command.
#   •	Make sure to replace the example values with the actual values for your databases.
#   •	You can leave this array empty if you do not want to back up any databases.
#   •	Supportoed databases: PostgreSQL, TimescaleDB, MySQL, MariaDB, MongoDB, Redis, Cassandra, Elasticsearch, SQLite, Neo4j,
#  •	                       CockroachDB, InfluxDB, Oracle, RethinkDB and Memcached.
DATABASES=(
        "PostgreSQL|Joplin-Postgress|joplindb|joplin|joplin"
        "PostgreSQL|Tesla-Postgres|teslamate|teslamate|teslamate"
        "PostgreSQL|immich_postgres|immich|postgres|postgres"
        "Redis|immich_redis||"
        "PostgreSQL|Invidiuous-db|invidious|kemal|kemal"
)

# Variable for selecting the email template
# 	•	This variable allows you to choose between different email templates.
#	•	Values: 1 for Professional Light Theme, 2 for Professional Dark, or random for a random selection.
MAIL_TEMPLATE="1"

# Variable to specify the maximum number of CPU cores to use for compression
#   •	The variable MAX_CPU_CORE allows you to define how many CPU cores should be used for compression during the backup process.
#   •	If you set this variable to a specific number, the script will use that many cores.
#   •	However, if you leave this variable unset or set it to an empty value The script will automatically detect the maximum number of available CPU cores on your system and use all of them for compression.
MAX_CPU_CORE=20


# 	•	Controls whether the 1-2-3 backup "principle" (Working in Progress) is applied (creating multiple backup copies).
#	•	Values: "Y" or "N".
#	•	If enabled ("Y"), backups will be copied to additional storage locations defined by SATA_DISK1 and SATA_DISK2.
#   •	Example:
#	•	SATA_DISK1="/media/nvme/1TB/123-1"
#	•	SATA_DISK2="/media/nvme/1TB/123-2"
BACKUP_123="Y"
SATA_DISK1=""
SATA_DISK2=""






#####################################################################################################################################
#       DO NOT EDIT BELOW THIS LINE - DO NOT EDIT BELOW THIS LINE - DO NOT EDIT BELOW THIS LINE - DO NOT EDIT BELOW THIS LINE       #
#       DO NOT EDIT BELOW THIS LINE - DO NOT EDIT BELOW THIS LINE - DO NOT EDIT BELOW THIS LINE - DO NOT EDIT BELOW THIS LINE       #
#       DO NOT EDIT BELOW THIS LINE - DO NOT EDIT BELOW THIS LINE - DO NOT EDIT BELOW THIS LINE - DO NOT EDIT BELOW THIS LINE       #
#       DO NOT EDIT BELOW THIS LINE - DO NOT EDIT BELOW THIS LINE - DO NOT EDIT BELOW THIS LINE - DO NOT EDIT BELOW THIS LINE       #
#       DO NOT EDIT BELOW THIS LINE - DO NOT EDIT BELOW THIS LINE - DO NOT EDIT BELOW THIS LINE - DO NOT EDIT BELOW THIS LINE       #
#####################################################################################################################################





# Check if the script is being run as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root user." >&2
  exit 1
fi

# Function to detect the Linux distribution and install required packages
check_and_install_dependencies() {
    # Identify the distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        echo "Distro found $DISTRO"
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO=$DISTRIB_ID
        echo "Distro found $DISTRO"
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
        echo "Distro found $DISTRO"
    elif [ -f /etc/redhat-release ]; then
        DISTRO="rhel"
        echo "Distro found $DISTRO"
    else
        DISTRO=$(uname -s)
        echo "Distro found $DISTRO"
    fi

    # Required packages
    REQUIRED_PACKAGES="tar pv pigz openssl msmtp coreutils"

    case "$DISTRO" in
        ubuntu|debian)
            # Check if nala is installed
            if command -v nala > /dev/null 2>&1; then
                PACKAGE_MANAGER="nala"
            else
                PACKAGE_MANAGER="apt"
            fi

            # Check if packages are already installed
            for pkg in $REQUIRED_PACKAGES; do
                if ! dpkg -s $pkg > /dev/null 2>&1; then
                    echo "Installing package $pkg on $DISTRO using $PACKAGE_MANAGER..."
                    $PACKAGE_MANAGER update && $PACKAGE_MANAGER install -y $pkg
                else
                    echo "$pkg is already installed."
                fi
            done
            ;;
        centos|rhel|fedora)
            # Check if packages are already installed
            for pkg in $REQUIRED_PACKAGES; do
                if ! rpm -q $pkg > /dev/null 2>&1; then
                    echo "Installing package $pkg on $DISTRO..."
                    yum install -y $pkg
                else
                    echo "$pkg is already installed."
                fi
            done
            ;;
        arch)
            # Check if packages are already installed
            for pkg in $REQUIRED_PACKAGES; do
                if ! pacman -Qi $pkg > /dev/null 2>&1; then
                    echo "Installing package $pkg on $DISTRO..."
                    pacman -Syu --noconfirm $pkg
                else
                    echo "$pkg is already installed."
                fi
            done
            ;;
        *)
            echo "Unsupported distribution: $DISTRO" >&2
            exit 1
            ;;
    esac
}

check_and_install_dependencies

# Variable to specify the maximum number of CPU cores to use for compression and decompression
# If not set, use the maximum available cores
MAX_CPU_CORE=${MAX_CPU_CORE:-$(nproc)}

# Get the number of available CPU cores
AVAILABLE_CPU_CORES=$(nproc)

# Ensure MAX_CPU_CORE does not exceed the available CPU cores
if [ "$MAX_CPU_CORE" -gt "$AVAILABLE_CPU_CORES" ]; then
    MAX_CPU_CORE="$AVAILABLE_CPU_CORES"
fi

# Function to gather host statistics
gather_host_statistics() {
    KERNEL_VERSION=$(uname -r)
    TOTAL_MEMORY=$(free -h | grep Mem | awk '{print $2}')
    USED_MEMORY=$(free -h | grep Mem | awk '{print $3}')
    AVAILABLE_MEMORY=$(free -h | grep Mem | awk '{print $7}')
    CPU_LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | awk '{ print $1 }')
    DISK_USAGE=$(df -h / | grep / | awk '{print $5}')
}

# Function to generate current date and time
CURRENT_DATE=$(date +%Y%m%d)

# Variables to accumulate backup reports
SOURCE_DIR_LIST=""
EXCLUDE_DIR_LIST=""

# Arrays to accumulate individual backup metrics
BACKUP_FILES=()
BACKUP_SIZES=()
MD5_SUMS=()
DISK_SPEEDS=()
BACKUP_DURATIONS=()
BACKUP_STARTS=()
BACKUP_ENDS=()
TEST_STATUSES=()

# Arrays to separately manage backup files for directories and databases
DIRECTORY_BACKUP_FILES=()
DATABASE_BACKUP_FILES=()
DIRECTORY_PASSWORDS=()
DATABASE_PASSWORDS=()
DATABASE_BACKUP_DETAILS=()
DATABASE_BACKUP_DURATIONS=()
DATABASE_BACKUP_STARTS=()
DATABASE_BACKUP_ENDS=()
DATABASE_TEST_STATUSES=()

# Array to store generated passwords
BACKUP_PASSWORDS=()

# Check if the backup directory does not exist
if [ ! -d "$BACKUP_DIR" ]; then
  # Create the backup directory
  mkdir -p "$BACKUP_DIR"
fi

# Check if the backup database directory does not exist
if [ ! -d "$BACKUP_DATABASE_DIR" ]; then
  # Create the backup directory
  mkdir -p "$BACKUP_DATABASE_DIR"
fi

# Function to check and create backup destination directories
check_and_create_directories() {
    local dirs=("$@")
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            echo "Directory $dir does not exist. Creating it..."
            mkdir -p "$dir"
        else
            echo "Directory $dir already exists."
        fi
    done
}

# Check and create backup destination directories for the 1,2,3 principle if 123BACKUP is enabled
if [ "$BACKUP_123" == "Y" ]; then
    check_and_create_directories "$SATA_DISK1" "$SATA_DISK2"
fi

# Function to stop Docker based on the distribution
stop_docker() {
echo "Stopping Docker services..." | tee -a "$LOG_FILE"
case "$DISTRO" in
    ubuntu|debian)
        sudo systemctl stop docker.service
        sudo systemctl stop docker.socket
        sudo systemctl stop containerd.service
        ;;
    centos|rhel|fedora)
        sudo systemctl stop docker
        sudo systemctl stop docker.socket
        sudo systemctl stop containerd
        ;;
    arch)
        sudo systemctl stop docker
        sudo systemctl stop docker.socket
        sudo systemctl stop containerd
        ;;
    *)
        echo "Unsupported distribution: $DISTRO ????" >&2
        exit 1
        ;;
esac
echo "Docker services stopped." | tee -a "$LOG_FILE"
}

# Function to start Docker based on the distribution
start_docker() {
echo "Starting Docker services..." | tee -a "$LOG_FILE"
case "$DISTRO" in
    ubuntu|debian)
        sudo systemctl start docker.service
        sudo systemctl start docker.socket
        sudo systemctl start containerd.service
        ;;
    centos|rhel|fedora)
        sudo systemctl start docker
        sudo systemctl start docker.socket
        sudo systemctl start containerd
        ;;
    arch)
        sudo systemctl start docker
        sudo systemctl start docker.socket
        sudo systemctl start containerd
        ;;
    *)
        echo "Unsupported distribution: $DISTRO" >&2
        exit 1
        ;;
esac
echo "Docker services started." | tee -a "$LOG_FILE"
}

# Function to check if Docker has stopped
check_docker_stopped() {
    local retries=5
    local wait_time=5
    for ((i=1; i<=retries; i++)); do
        if ! systemctl is-active --quiet docker; then
            echo "Docker has stopped successfully." | tee -a "$LOG_FILE"
            return 0
        fi
        echo "Waiting for Docker to stop... ($i/$retries)" | tee -a "$LOG_FILE"
        sleep $wait_time
    done
    echo "Error: Docker did not stop within the expected time." | tee -a "$LOG_FILE"
    exit 1
}

# Function to generate a random password
generate_password() {
    openssl rand -base64 32
}

# Function to calculate the MD5 checksum
calculate_md5() {
     local file="$1"
     md5sum "$file" | awk '{ print $1 }'
}

# Function to calculate the total size of source directories
calculate_total_source_size() {
    local total_size=0
    for dir in "${SOURCE_DIRS[@]}"; do
        dir_size=$(du -sb "$dir" | awk '{print $1}')
        total_size=$((total_size + dir_size))
    done
    echo "$total_size"
}

# Function to calculate the file size in a human-readable format
calculate_file_size_readable() {
    local file="$1"
    du -sh "$file" | awk '{print $1}'
}

# Function to verify the backup using pigz for parallel decompression
verify_backup() {
    local file="$1"
    local password="$2"
    TEST_START=$(date +%s)

    echo "Begin backup verification for file: $file" | tee -a "$LOG_FILE"

    if [[ "$file" == *.enc ]]; then
        # Decrypt and then verify the backup
        if openssl enc -d -aes-256-cbc -pbkdf2 -iter 10000 -in "$file" -pass pass:"$password" | pigz -p $MAX_CPU_CORE -dc -9 | tar -tf - > /dev/null 2>&1; then
            TEST_END=$(date +%s)
            TEST_STATUS="Successful"
            echo "Verification successful for encrypted file: $file"
        else
            TEST_END=$(date +%s)
            TEST_STATUS="Failed"
            echo "Verification failed for encrypted file: $file" >> "$LOG_FILE"
            echo "Verification failed for encrypted file: $file"
        fi
    else
        # Verify the backup using pigz for parallel decompression
        if pigz -p $MAX_CPU_CORE -dc -9 "$file" | pv -s $(stat -c%s "$file") | tar -tf - > /dev/null 2>&1; then
            TEST_END=$(date +%s)
            TEST_STATUS="Successful"
            echo "Verification successful for non-encrypted file: $file"
        else
            TEST_END=$(date +%s)
            TEST_STATUS="Failed"
            echo "Verification failed for non-encrypted file: $file" >> "$LOG_FILE"
            echo "Verification failed for non-encrypted file: $file"
        fi
    fi

    echo "Backup verification completed for file: $file" | tee -a "$LOG_FILE"

    # Calculate the test duration in minutes and seconds
    local test_duration=$(( TEST_END - TEST_START ))
    local test_minutes=$(( test_duration / 60 ))
    local test_seconds=$(( test_duration % 60 ))
    TEST_DURATION="${test_minutes} minutes and ${test_seconds} seconds"

    # Convert the timestamps to a readable format
    TEST_START_READABLE=$(convert_timestamp_to_date "$TEST_START")
    TEST_END_READABLE=$(convert_timestamp_to_date "$TEST_END")
}

# Function to compress and encrypt the database backup
compress_and_encrypt_backup() {
    local file="$1"
    local encrypted_file="$2"
    local password="$3"

    # Remove the .sql.enc extension from the original file name to get the correct name
    local base_file=$(basename "$file" .sql.enc)
    local backup_dir=$(dirname "$file")  # Get the directory of the file

    # Full path for the compressed file
    local compressed_file="${backup_dir}/${base_file}.tar.gz"

    # Compress the backup file in every case
    echo "Compressing the backup file $file..."
    tar -P -cf - "$file" | pv -s $(du -sb "$file" | awk '{print $1}') | pigz -p $MAX_CPU_CORE -9 > "$compressed_file"

    if [ $? -ne 0 ]; then
        echo "Compression failed for $file" >> "$LOG_FILE"
        return 1
    else
        echo "Compression completed for $file. Compressed file: $compressed_file" >> "$LOG_FILE"
    fi

    # Calculate the MD5 before encrypting
    local md5_checksum=$(md5sum "$compressed_file" | awk '{ print $1 }')
    echo "MD5 checksum: $md5_checksum"
    DATABASE_MD5_SUMS+=("$md5_checksum")

    if [ "$ENCRYPT_BACKUP" == "Y" ]; then
        echo "Encrypting the compressed file $compressed_file..."
        openssl enc -aes-256-cbc -pbkdf2 -iter 10000 -salt -in "$compressed_file" -out "${encrypted_file}.tar.gz.enc" -pass pass:"$password"

        if [ $? -ne 0 ]; then
            echo "Encryption failed for $compressed_file" >> "$LOG_FILE"
            return 1
        else
            echo "Encryption completed for $compressed_file" >> "$LOG_FILE"
            rm -f "$compressed_file"  # Delete the file only after encryption is complete
        fi

    else
        COMPRESSED_BACKUP_SIZES+=($(stat -c%s "$compressed_file"))
    fi

    # Delete the original .sql file after compression and/or encryption
    rm -f "$file"
    echo "Original file $file deleted." >> "$LOG_FILE"
}

# Function to encrypt the backup file with AES-256
encrypt_backup() {
    local file="$1"
    local password="$2"
    local encrypted_file="${file}.enc"

    # Encrypt the backup file using AES-256-CBC with PBKDF2 and 10,000 iterations
    openssl enc -aes-256-cbc -pbkdf2 -iter 10000 -salt -in "$file" -out "$encrypted_file" -pass pass:"$password" 2>> "$LOG_FILE"

    # Remove the unencrypted file
    rm -f "$file"
    echo "$encrypted_file"
}

# Function to convert a UNIX timestamp to a readable date
convert_timestamp_to_date() {
    local timestamp=$1
    date -d @"$timestamp" +"%a %d %b %Y, %H:%M:%S %Z"
}

# Function to calculate the backup duration in minutes and seconds
calculate_backup_duration() {
    local start_time=$1
    local end_time=$2
    local duration=$(( end_time - start_time ))

    # If the duration is too short (less than 1 second), set it to 1 second
    if [[ $duration -eq 0 ]]; then
        duration=1
    fi

    # Calculate minutes and seconds
    local minutes=$(( duration / 60 ))
    local seconds=$(( duration % 60 ))

    # Return the calculated duration
    echo "${minutes} minutes and ${seconds} seconds"
}

# Function to calculate disk speed
calculate_disk_speed() {
    local file_path=$1        # The backup file
    local start_time=$2       # Backup start timestamp
    local end_time=$3         # Backup end timestamp

    # Calculate the backup file size in bytes
    local size_bytes=$(stat -c%s "$file_path")

    # Calculate the duration in seconds
    local time_seconds=$((end_time - start_time))

    # Avoid division by zero: if the time is 0, set the duration to 1 second
    if [[ $time_seconds -eq 0 ]]; then
        time_seconds=1
    fi

    # Calculate speed in MB/s (bytes / seconds -> MB/s)
    DISK_SPEED=$(echo "scale=2; $size_bytes / $time_seconds / 1024 / 1024" | bc -l)

    # Write the speed to the log for debugging without duplicating "MB/s"
    echo "$DISK_SPEED" | tee -a "$LOG_FILE"
}

# Function to perform the database backup
backup_database() {
    local db_info="$1"
    local db_type=$(echo $db_info | cut -d'|' -f1)
    local container_name=$(echo $db_info | cut -d'|' -f2)
    local db_name=$(echo $db_info | cut -d'|' -f3)
    local db_user=$(echo $db_info | cut -d'|' -f4)
    local db_password=$(echo $db_info | cut -d'|' -f5)
    local backup_file="$BACKUP_DATABASE_DIR/${db_name}-$(date +%Y%m%d).sql"
    local encrypted_file="${backup_file}"

    # Log the backup start time
    local BACKUP_START=$(date +%s)

    case "$db_type" in
        "PostgreSQL"|"TimescaleDB")
            echo "Performing the database backup $db_type..."
            docker exec "$container_name" pg_dump -U "$db_user" "$db_name" > "$backup_file"
            ;;
        "MySQL"|"MariaDB")
            echo "Performing the database backup MySQL/MariaDB..."
            docker exec "$container_name" mysqldump -u "$db_user" -p"$db_password" "$db_name" > "$backup_file"
            ;;
        "MongoDB")
            echo "Performing the database backup MongoDB..."
            docker exec "$container_name" mongodump --db "$db_name" --out "$BACKUP_DATABASE_DIR/$db_name-$(date +%Y%m%d)"
            ;;
        "Redis")
            echo "Performing the database backup Redis..."
            docker exec "$container_name" redis-cli BGSAVE
            # Wait for the Redis backup to complete
            while ! docker exec "$container_name" redis-cli LASTSAVE > /dev/null; do
                sleep 1
            done
            # Copy the dump.rdb file from the Redis container to the backup directory
            docker cp "$container_name:/data/dump.rdb" "$BACKUP_DATABASE_DIR/dump-$CURRENT_DATE.rdb"
            # Update the backup file name with the correct container name
            backup_file="$BACKUP_DATABASE_DIR/dump-$CURRENT_DATE.rdb"
            encrypted_file="$BACKUP_DATABASE_DIR/${container_name}_dump-$CURRENT_DATE"
            ;;
        "Cassandra")
            echo "Performing the database backup Cassandra..."
            docker exec "$container_name" nodetool snapshot -t "$(date +%Y%m%d)-snapshot"
            ;;
        "Elasticsearch")
            echo "Performing the database backup Elasticsearch..."
            docker exec "$container_name" elasticsearch-snapshot --repository backup-repo --snapshot "$(date +%Y%m%d)"
            ;;
        "SQLite")
            echo "Performing the database backup SQLite..."
            docker cp "$container_name:/path/to/database.sqlite" "$BACKUP_DATABASE_DIR/sqlite-backup-$(date +%Y%m%d).sqlite"
            ;;
        "Neo4j")
            echo "Performing the database backup Neo4j..."
            docker exec "$container_name" neo4j-admin backup --from="$container_name" --backup-dir="$BACKUP_DATABASE_DIR"
            ;;
        "CockroachDB")
            echo "Performing the database backup CockroachDB..."
            docker exec "$container_name" cockroach sql --execute="BACKUP TO '$BACKUP_DATABASE_DIR/backup'"
            ;;
        "InfluxDB")
            echo "Performing the database backup InfluxDB..."
            docker exec "$container_name" influx backup -portable "$BACKUP_DATABASE_DIR"
            ;;
        "Oracle")
            echo "Performing the database backup Oracle..."
            docker exec "$container_name" rman target / <<EOF
            backup database;
EOF
            ;;
        "RethinkDB")
            echo "Performing the database backup RethinkDB..."
            docker exec "$container_name" rethinkdb dump -f "$BACKUP_DATABASE_DIR/rethinkdb-backup-$(date +%Y%m%d).tar.gz"
            ;;
        "Memcached")
            echo "Memcached does not require a backup of persistent data. Ignoring…"
            ;;
        *)
            echo "Unsupported database type: $db_type"
            return 1
            ;;
    esac

    # Calculate the original size of the database file
    local original_db_size=$(calculate_file_size_readable "$backup_file")
    DATABASE_ORIGINAL_SIZES+=("$original_db_size")  # Store the original size in the array

    if [ "$ENCRYPT_BACKUP" == "Y" ]; then
        local password=$(generate_password)
        compress_and_encrypt_backup "$backup_file" "$encrypted_file" "$password"
        DATABASE_PASSWORDS+=("$password")
        DATABASE_BACKUP_FILES+=("${encrypted_file}.tar.gz.enc")
        # Verify  backup
        verify_backup "${encrypted_file}.tar.gz.enc" "$password"
        echo "Verifying the Encrypted backup..."
    else
        compress_and_encrypt_backup "$backup_file" "" ""
        DATABASE_PASSWORDS+=("No encryption")
        DATABASE_BACKUP_FILES+=("${backup_file}.tar.gz")
        # Verify  backup
        verify_backup "${backup_file}.tar.gz" ""
        echo "Verifying the UnEncrypted backup..."
    fi

    # Add the verification status to the DATABASE_TEST_STATUSES variable
    DATABASE_TEST_STATUSES+=("$TEST_STATUS")

    # Log the backup end time
    local BACKUP_END=$(date +%s)

    # Convert timestamps to a readable format
    local BACKUP_START_READABLE=$(convert_timestamp_to_date "$BACKUP_START")
    local BACKUP_END_READABLE=$(convert_timestamp_to_date "$BACKUP_END")

    # Calculate the backup duration
    local BACKUP_DURATION=$(calculate_backup_duration "$BACKUP_START" "$BACKUP_END")

    # Store the backup details
    DATABASE_BACKUP_DURATIONS+=("$BACKUP_DURATION")
    DATABASE_BACKUP_STARTS+=("$BACKUP_START_READABLE")
    DATABASE_BACKUP_ENDS+=("$BACKUP_END_READABLE")

    # Add database backup details for the email report
    DATABASE_BACKUP_DETAILS+=("<tr><td>${db_name}</td><td>${container_name}</td><td>${BACKUP_DATABASE_DIR}</td><td>${original_db_size}</td></tr>")

    echo "Backup and compression completed for the database $db_name."
}

# Function to perform the database restore
restore_database() {
    local db_info="$1"
    local db_type=$(echo $db_info | cut -d'|' -f1)
    local container_name=$(echo $db_info | cut -d'|' -f2)
    local db_name=$(echo $db_info | cut -d'|' -f3)
    local db_user=$(echo $db_info | cut -d'|' -f4)
    local db_password=$(echo $db_info | cut -d'|' -f5)
    local backup_file="$BACKUP_DATABASE_DIR/${db_name}-$(date +%Y%m%d).sql"

    case "$db_type" in
        "PostgreSQL"|"TimescaleDB")
            echo "Restoring the database $db_type..."
            docker exec -i "$container_name" psql -U "$db_user" "$db_name" < "$backup_file"
            ;;
        "MySQL"|"MariaDB")
            echo "Restoring the database MySQL/MariaDB..."
            docker exec -i "$container_name" mysql -u "$db_user" -p"$db_password" "$db_name" < "$backup_file"
            ;;
        "MongoDB")
            echo "Restoring the database MongoDB..."
            docker exec "$container_name" mongorestore --db "$db_name" "$BACKUP_DATABASE_DIR/$db_name-$(date +%Y%m%d)"
            ;;
        "Redis")
            echo "Restoring the database Redis..."
            docker cp "$backup_file" "$container_name:/data/dump.rdb"
            docker exec "$container_name" redis-cli shutdown save
            docker start "$container_name"
            ;;
        "Cassandra")
            echo "Restoring the database Cassandra..."
            docker exec "$container_name" nodetool refresh -- $db_name $(date +%Y%m%d)-snapshot
            ;;
        "Elasticsearch")
            echo "Restoring the database Elasticsearch..."
            docker exec "$container_name" elasticsearch-snapshot --repository backup-repo --restore --snapshot "$(date +%Y%m%d)"
            ;;
        "SQLite")
            echo "Restoring the database SQLite..."
            docker cp "$backup_file" "$container_name:/path/to/database.sqlite"
            ;;
        "Neo4j")
            echo "Restoring the database Neo4j..."
            docker exec "$container_name" neo4j-admin restore --from="$BACKUP_DATABASE_DIR"
            ;;
        "CockroachDB")
            echo "Restoring the database CockroachDB..."
            docker exec "$container_name" cockroach sql --execute="RESTORE FROM '$BACKUP_DATABASE_DIR/backup'"
            ;;
        "InfluxDB")
            echo "Restoring the database InfluxDB..."
            docker exec "$container_name" influx restore -portable "$BACKUP_DATABASE_DIR"
            ;;
        "Oracle")
            echo "Restoring the database Oracle..."
            docker exec "$container_name" rman target / <<EOF
            restore database;
EOF
            ;;
        "RethinkDB")
            echo "Restoring the database RethinkDB..."
            docker exec "$container_name" rethinkdb restore -f "$BACKUP_DATABASE_DIR/rethinkdb-backup-$(date +%Y%m%d).tar.gz"
            ;;
        "Memcached")
            echo "Memcached does not require a restore of persistent data. Ignoring..."
            ;;
        *)
            echo "Unsupported database type: $db_type"
            return 1
            ;;
    esac
}

# Back up all Docker databases
if [ "$BACKUP_DOCKER_DATABASE" == "Y" ]; then
    for db_info in "${DATABASES[@]}"; do
        backup_database "$db_info"
    done
fi

# Stop Docker only if necessary
if [ "$STOP_DOCKER_BEFORE_BACKUP" == "Y" ]; then
    stop_docker
    check_docker_stopped
fi

# Function to calculate the total size of source directories in a human-readable format
calculate_total_source_size_readable() {
    local dir="$1"
    du -sh "$dir" | awk '{print $1}'
}

# Function to count the number of files in a directory
count_files_in_directory() {
    local dir="$1"
    find "$dir" -type f | wc -l
}

# Start backup for all source directories
for DIR in "${SOURCE_DIRS[@]}"; do
    DIR_NAME=$(basename "$DIR")
    BACKUP_FILE="$BACKUP_DIR/${CURRENT_DATE}-${DIR_NAME}.tar.gz"

    # Log the backup start time
    BACKUP_START=$(date +%s)

    # Write a log with the start timestamp
    echo "Starting backup for $DIR_NAME at $(date)" | tee -a "$LOG_FILE"

    # Check if EXCLUDE_DIRS is empty
    EXCLUDE_OPTIONS=""
    if [ ${#EXCLUDE_DIRS[@]} -ne 0 ]; then
        EXCLUDE_OPTIONS=$(printf -- '--exclude=%s ' "${EXCLUDE_DIRS[@]}")
    fi

    # Create the backup with 'pv' to show progress, excluding sockets
    tar $EXCLUDE_OPTIONS --exclude='*.sock' -cf - "$DIR" -P | pv -s $(du -sb "$DIR" | awk '{print $1}') | pigz -9 > "$BACKUP_FILE" 2>> "$LOG_FILE"
    BACKUP_END=$(date +%s)

    # Write a log with the end timestamp
    echo "Backup completed for $DIR_NAME at $(date)" | tee -a "$LOG_FILE"

    # Convert timestamps to a readable format
    BACKUP_START_READABLE=$(convert_timestamp_to_date "$BACKUP_START")
    BACKUP_END_READABLE=$(convert_timestamp_to_date "$BACKUP_END")

    # Calculate the backup duration
    BACKUP_DURATION=$(calculate_backup_duration "$BACKUP_START" "$BACKUP_END")

    # Calculate disk write speed (use a separate variable)
    DISK_SPEED=$(calculate_disk_speed "$BACKUP_FILE" "$BACKUP_START" "$BACKUP_END")

    # Calculate backup size in bytes
    BACKUP_SIZE_BYTES=$(stat -c%s "$BACKUP_FILE")

    # Calculate the number of files in the current directory
    NUM_FILES=$(count_files_in_directory "$DIR")

    # Calculate the original size of the directory in a human-readable format
    ORIGINAL_SIZE=$(calculate_total_source_size_readable "$DIR")

    # Function to convert the size to a readable scale (B, KiB, MiB, GiB, TiB)
    human_readable_size() {
        local size=$1
        local unit="B"
        if (( $(echo "$size >= 1024" | bc -l) )); then
            size=$(echo "scale=2; $size / 1024" | bc)
            unit="KiB"
        fi
        if (( $(echo "$size >= 1024" | bc -l) )); then
            size=$(echo "scale=2; $size / 1024" | bc)
            unit="MiB"
        fi
        if (( $(echo "$size >= 1024" | bc -l) )); then
            size=$(echo "scale=2; $size / 1024" | bc)
            unit="GiB"
        fi
        if (( $(echo "$size >= 1024" | bc -l) )); then
            size=$(echo "scale=2; $size / 1024" | bc)
            unit="TiB"
        fi
        echo "$size $unit"
    }

    # Calculate the backup size in a readable format
    BACKUP_SIZE=$(human_readable_size "$BACKUP_SIZE_BYTES")

    # Calculate the MD5 checksum
    MD5_SUM=$(md5sum "$BACKUP_FILE" | awk '{print $1}')

    # If encryption is enabled, generate a password and encrypt the backup
    if [ "$ENCRYPT_BACKUP" == "Y" ]; then
        PASSWORD=$(generate_password)
        BACKUP_FILE=$(encrypt_backup "$BACKUP_FILE" "$PASSWORD")
        BACKUP_PASSWORDS+=("$PASSWORD")  # Store the password for this backup
    else
        PASSWORD=""  # Ensure PASSWORD is empty if encryption is disabled
        BACKUP_PASSWORDS+=("No encryption")  # No password if encryption is disabled
    fi

    # Verify the backup
    verify_backup "$BACKUP_FILE" "$PASSWORD"

    # Array BACKUP_PASSWORDS for logging
    echo "BACKUP_PASSWORDS: ${BACKUP_PASSWORDS[@]}" | tee -a "$LOG_FILE"

    # Add the source directory to the HTML report
    SOURCE_DIR_LIST="$SOURCE_DIR_LIST<tr><td>$(basename ${BACKUP_FILE})</td><td><center>${DIR_NAME}</center></td><td>${BACKUP_DIR}</td><td>${BACKUP_DURATION}</td><td>${BACKUP_START_READABLE}</td><td>${BACKUP_END_READABLE}</td><td>${DISK_SPEED} MB/s</td></tr>"
    # Store values in their respective arrays
    BACKUP_FILES+=("$BACKUP_FILE")
    BACKUP_SIZES+=("$BACKUP_SIZE")
    MD5_SUMS+=("$MD5_SUM")
    DISK_SPEEDS+=("$DISK_SPEED")
    BACKUP_DURATIONS+=("$BACKUP_DURATION")
    BACKUP_STARTS+=("$BACKUP_START_READABLE")
    BACKUP_ENDS+=("$BACKUP_END_READABLE")
    TEST_STATUSES+=("$TEST_STATUS")
    NUM_FILES_ARRAY+=("$NUM_FILES")  # Store the number of files for this backup
    ORIGINAL_SIZES+=("$ORIGINAL_SIZE")  # Store the original size for this backup
done

# Cleanup old backups based on the defined retention days
for DIR in "${SOURCE_DIRS[@]}"; do
    find "$BACKUP_DIR" -type f -name "$(basename "$DIR")*.tar.gz" -mtime +$DAYS_TO_KEEP -exec rm -f {} \;
done

# Restart Docker if necessary
if [ "$STOP_DOCKER_BEFORE_BACKUP" == "Y" ]; then
    start_docker
fi

# Function to count existing backups
count_existing_backups() {
    local dir="$1"
    local pattern="$2"
    find "$dir" -type f -name "$pattern" | wc -l
}

# Function to copy backups to the 1,2,3 principle destinations
copy_backups_to_destinations() {
    local backup_files=("$@")
    local total_size=0

    # Calculates the total size of all backup files.
    for file in "${backup_files[@]}"; do
        total_size=$((total_size + $(stat -c%s "$file")))
    done

    # Copies all files to SATA_DISK1 using pv
    echo "Copying backups to $SATA_DISK1..."
    for file in "${backup_files[@]}"; do
        pv "$file" > "$SATA_DISK1/$(basename "$file")"
    done

    # Copies all files to SATA_DISK2 using pv
    echo "Copying backups to $SATA_DISK2..."
    for file in "${backup_files[@]}"; do
        pv "$file" > "$SATA_DISK2/$(basename "$file")"
    done
}

# Function to send a combined email for both directory and database backups
send_email() {
    # Host statistics function
    gather_host_statistics
    # Calculate total number of directories and files backed up
    TOTAL_DIRECTORIES=${#SOURCE_DIRS[@]}
    TOTAL_FILES=$(find "${SOURCE_DIRS[@]}" -type f | wc -l)

    # Calculate total backup size
    TOTAL_BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | awk '{print $1}')

    # Calculate total and average backup time
    TOTAL_BACKUP_TIME=0
    for duration in "${BACKUP_DURATIONS[@]}"; do
        minutes=$(echo $duration | awk '{print $1}')
        seconds=$(echo $duration | awk '{print $4}')
        TOTAL_BACKUP_TIME=$((TOTAL_BACKUP_TIME + minutes * 60 + seconds))
    done
    AVERAGE_BACKUP_TIME=$((TOTAL_BACKUP_TIME / TOTAL_DIRECTORIES))
    AVERAGE_BACKUP_MINUTES=$((AVERAGE_BACKUP_TIME / 60))
    AVERAGE_BACKUP_SECONDS=$((AVERAGE_BACKUP_TIME % 60))

    # Check if backups are encrypted
    if [ "$ENCRYPT_BACKUP" == "Y" ]; then
        ENCRYPTION_STATUS="Yes"
    else
        ENCRYPTION_STATUS="No"
    fi

    # Calculate total number of databases backed up
    TOTAL_DATABASES=${#DATABASES[@]}

    # Calculate total database backup size
    TOTAL_DATABASE_BACKUP_SIZE=$(du -sh "$BACKUP_DATABASE_DIR" | awk '{print $1}')

    # Count existing backups for directories and databases
    TOTAL_DIRECTORY_BACKUPS=$(count_existing_backups "$BACKUP_DIR" "*.tar.gz*")
    TOTAL_DATABASE_BACKUPS=$(count_existing_backups "$BACKUP_DATABASE_DIR" "*.tar.gz*")

# Styles for email templates
# Professional Light Theme
STYLE_1="body { font-family: 'Courier New', Courier, monospace; background-color: #ffffff; color: #333333; }
.container { max-width: 1200px; margin: 40px auto; background-color: #f9f9f9; padding: 20px; border-radius: 8px; box-shadow: 0px 0px 15px rgba(0, 0, 0, 0.3); color: #2c3e50; }
h1 { font-size: 28px; color: #3498db; margin-bottom: 20px; } h2 { color: #2c3e50; margin-bottom: 15px; font-size: 22px; }
ul { list-style-type: none; padding: 0; }
li { padding: 8px; background-color: #ecf0f1;
margin-bottom: 8px; border-radius: 4px; box-shadow: 0px 0px 5px rgba(0, 0, 0, 0.1); }
pre { background-color: #3498db; color: #ffffff;
padding: 10px; border-radius: 5px; white-space: pre-wrap; word-wrap: break-word; }
table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
th, td { padding: 12px; border: 1px solid #e0e0e0; text-align: left; }
th { background-color: #3498db; color: #ffffff; }
td { background-color: #ecf0f1; color: #2c3e50; }
footer { margin-top: 20px; font-size: 12px; color: #7f8c8d; text-align: center; }
.stats-table { border-radius: 8px ; overflow: hidden; }
.coffee-link { color: #2980b9; text-decoration: none; }
.coffee-link:hover { text-decoration: underline; }
.coffee-logo { width: 20px; vertical-align: middle; margin-right: 5px; }
.separator { border-top: 3px solid #2980b9; margin: 20px 0; border-radius: 5px; }
.centered-table th, .centered-table td { text-align: center; }
body3 { background-color: #1d1d1f; font-family: Arial, sans-serif; color: #aab0c6; }
.stats_backup { width: 300px auto; padding: 20px; background-color: #f9f9f9; border-radius: 8px; box-shadow: 0px 0px 15px rgba(0, 0, 0, 0.3); text-align: center; color: #2c3e50; margin: auto; }
.stats_info_backup { width: 700px auto; padding: 20px; background-color: #f9f9f9; border-radius: 8px; box-shadow: 0px 0px 15px rgba(0, 0, 0, 0.3); text-align: left; color: #2c3e50; margin: auto; }
.backup { font-size: 50px; margin-bottom: 15px; }
.enc { font-size: 20px; font-weight: bold; }
.size { font-size: 40px; color: #7f85ff; font-family: 'Courier New', Courier, monospace; }
.status { font-size: 14px; }"

STYLE_2="body { font-family: 'Courier New', Courier, monospace; background-color: #1b1b1b; color: #e0e0e0; }
.container { max-width: 1200px; margin: 40px auto; background-color: #2b2b2b; padding: 20px; border-radius: 8px; box-shadow: 0px 0px 15px rgba(0, 0, 0, 0.8); color: #e0e0e0; }
h1 { font-size: 28px; color: #77c0e3; margin-bottom: 20px; }
h2 { color: #e0e0e0; margin-bottom: 15px; font-size: 22px; }
ul { list-style-type: none; padding: 0; }
li { padding: 8px; background-color: #444444; margin-bottom: 8px; border-radius: 4px; box-shadow: 0px 0px 5px rgba(0, 0, 0, 0.5); }
pre { background-color: #77c0e3; color: #1b1b1b; padding: 10px; border-radius: 5px; white-space: pre-wrap; word-wrap: break-word; }
table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
th, td { padding: 12px; border: 1px solid #444444; text-align: left; }
th { background-color: #77c0e3; color: #1b1b1b; }
td { background-color: #444444; color: #e0e0e0; }
footer { margin-top: 20px; font-size: 12px; color: #b0b0b0; text-align: center; }
.stats-table { border-radius: 8px ; overflow: hidden; }
.coffee-link { color: #77c0e3; text-decoration: none; }
.coffee-link:hover { text-decoration: underline; }
.coffee-logo { width: 20px; vertical-align: middle; margin-right: 5px; }
.separator { border-top: 3px solid #77c0e3; margin: 20px 0; border-radius: 5px; }
.centered-table th, .centered-table td { text-align: center; }
body3 { background-color: #121212; font-family: Arial, sans-serif; color: #aab0c6; }
.stats_backup { width: 300px auto; padding: 20px; background-color: #2b2b2b; border-radius: 8px; box-shadow: 0px 0px 15px rgba(0, 0, 0, 0.8); text-align: center; color: #e0e0e0; margin: auto; }
.stats_info_backup { width: 700px auto; padding: 20px; background-color: #2b2b2b; border-radius: 8px; box-shadow: 0px 0px 15px rgba(0, 0, 0, 0.8); text-align: left; color: #e0e0e0; margin: auto; }
.backup { font-size: 50px; margin-bottom: 15px; }
.enc { font-size: 20px; font-weight: bold; }
.size { font-size: 40px; color: #7f85ff; font-family: 'Courier New', Courier, monospace; }
.status { font-size: 14px; }"

# Select the style based on MAIL_TEMPLATE
case "$MAIL_TEMPLATE" in
    1) SELECTED_STYLE="$STYLE_1" ;;
    2) SELECTED_STYLE="$STYLE_2" ;;
    random|*)
        RANDOM_INDEX=$((RANDOM % 2 + 1))
        SELECTED_STYLE=$(eval echo "\$STYLE_$RANDOM_INDEX")
        ;;
esac

    # Calculate total and average database backup time
    TOTAL_DATABASE_BACKUP_TIME=0
    for duration in "${DATABASE_BACKUP_DURATIONS[@]}"; do
        minutes=$(echo $duration | awk '{print $1}')
        seconds=$(echo $duration | awk '{print $4}')
        TOTAL_DATABASE_BACKUP_TIME=$((TOTAL_DATABASE_BACKUP_TIME + minutes * 60 + seconds))
    done
    AVERAGE_DATABASE_BACKUP_TIME=$((TOTAL_DATABASE_BACKUP_TIME / TOTAL_DATABASES))
    AVERAGE_DATABASE_BACKUP_MINUTES=$((AVERAGE_DATABASE_BACKUP_TIME / 60))
    AVERAGE_DATABASE_BACKUP_SECONDS=$((AVERAGE_DATABASE_BACKUP_TIME % 60))

    SUBJECT="Backup Report - $SERVER_NAME - $(date +'%d %b %Y, %H:%M:%S')"

    MESSAGE="
    <!DOCTYPE html>
    <html lang='en'>
    <head>
        <meta charset='UTF-8'>
        <meta name='viewport' content='width=device-width, initial-scale=1.0'>
        <title>Backup Report</title>
        <style>
            $SELECTED_STYLE
        </style>
    </head>
    <body>
       <div class='container'>
            <center><h1>Backup successfully completed</h1>
            <p>Server: $SERVER_NAME - Used $MAX_CPU_CORE cores for compression and decompression</p>
            <p>Backup performed on $(date +'%d %b %Y, %H:%M:%S')</p></center>

            <h2><center>Exported directories:</center></h2>

            <table>
                <thead>
                    <tr>
                        <th>Backup Name</th>
                        <th>Source Directory</th>
                        <th>Destination Directory</th>
                        <th>Backup Time</th>
                        <th>Start</th>
                        <th>Stop</th>
                        <th>Speed</th>
                    </tr>
                </thead>
                <tbody>
                   $SOURCE_DIR_LIST
                </tbody>
            </table>"

    # Condition to display the ‘Directories Excluded from Backup’ section only if EXCLUDE_DIRS is not empty
    if [ ${#EXCLUDE_DIRS[@]} -ne 0 ]; then
        MESSAGE+="
            <h2><center>Directories Excluded from Backup</center></h2>
            <div class='metrics'>
                <ul>
                    $EXCLUDE_DIR_LIST
                </ul>
            </div>"
    fi

    MESSAGE+="
             <h2><center>Detailed Report DIRECTORY backup</center></h2>
            <ul>"



##########################################################################
#
#         START OF DIRECTORY EMAIL SECTION
#
##########################################################################


    # Add the details of the directory backups
    for i in "${!BACKUP_FILES[@]}"; do
        backup_file="${BACKUP_FILES[$i]}"
        password="${BACKUP_PASSWORDS[$i]}"
        md5_checksum="${MD5_SUMS[$i]}"
        backup_duration="${BACKUP_DURATIONS[$i]}"
        backup_start="${BACKUP_STARTS[$i]}"
        backup_end="${BACKUP_ENDS[$i]}"
        disk_speed="${DISK_SPEEDS[$i]}"
        test_status="${TEST_STATUSES[$i]}"
        dir_name=$(basename "${SOURCE_DIRS[$i]}")  # Get the directory name
        backup_size="${BACKUP_SIZES[$i]}"  # Get the backup size
        num_files="${NUM_FILES_ARRAY[$i]}"  # Get the number of files for this backup
        original_size="${ORIGINAL_SIZES[$i]}"  # Get the original size for this backup
        MESSAGE+="
        <table>
          <tr>
                <td style='border: 0; vertical-align: top;'>

                    <div class="stats_info_backup">

                        <strong style='font-size: 1.2em;'>Directory: ${dir_name}</strong><br>
                        <strong>Backup Name:</strong> $(basename $backup_file)<br>
                        <strong>Destination:</strong> ${BACKUP_DIR}<br>
                        <strong>Nr. File:</strong> $num_files<br>
                        <strong>Original File Size:</strong> $original_size <br>
                        <strong>File Size Compressed:</strong> $backup_size<br>
                        <strong>MD5 Checksum:</strong> $md5_checksum<br>
                        <strong>Verification Status:</strong> $test_status<br>
                        <strong>Backup Duration:</strong> $backup_duration<br>
                        <strong>Start:</strong> $backup_start<br>
                        <strong>Stop:</strong> $backup_end<br>
                        <strong>Disk Speed:</strong> $disk_speed MB/s<br>

                    </div>
                </td>
                <td style='border: 0; vertical-align: top;'>
                    <div class="stats_backup">
                    <div class="backup">${dir_name}</div>
                    <div class="size">$backup_size</div>
                    <div class="enc">Encrypted: $ENCRYPTION_STATUS</div>
                    <div class="status">$test_status</div>
                    </div>
                </td>
            </tr>
            <tr>
                <td colspan="2" class="row-span">"

        # Command to extract the encrypted and compressed file
        if [ "$ENCRYPT_BACKUP" == "Y" ]; then
            MESSAGE+="<strong>Password:</strong> $password<br><strong>Command to extract the encrypted directory:</strong><br>
            <pre>sudo openssl enc -d -aes-256-cbc -pbkdf2 -iter 10000 -in ${backup_file} -pass pass:$password | pigz -p $MAX_CPU_CORE -d | sudo tar --strip-components=1 -xvf - -C $BACKUP_DIR</pre>"
        else
            MESSAGE+="<strong>Password:</strong> No encryption<br><strong>Command to extract the non-encrypted directory:</strong><br>
            <pre>sudo tar --strip-components=1 -xvf ${backup_file} -C $BACKUP_DIR</pre>"
        fi

        MESSAGE+="</td>
            </tr>
        </table>"
    done

    MESSAGE+="</ul>"

    # Conditionally add the database backup section
    if [ "$BACKUP_DOCKER_DATABASE" == "Y" ]; then
        MESSAGE+="
            <h2><center>Exported databases:</center></h2>

            <table>
                <thead>
                    <tr>
                        <th>DB Name</th>
                        <th>Container DB Name</th>
                        <th>Destination DB Directory Backup</th>
                        <th>Size</th>
                    </tr>
                </thead>
                <tbody>
                   ${DATABASE_BACKUP_DETAILS[*]}
                </tbody>
            </table>
             <h2><center>Detailed Report DATABASE Backup:</center></h2>
            <ul>"

            # Add the details of the database backups
            for i in "${!DATABASE_BACKUP_FILES[@]}"; do
                local backup_file="${DATABASE_BACKUP_FILES[$i]}"
                local password="${DATABASE_PASSWORDS[$i]}"
                local md5_checksum="${DATABASE_MD5_SUMS[$i]}"
                local backup_duration="${DATABASE_BACKUP_DURATIONS[$i]}"
                local backup_start="${DATABASE_BACKUP_STARTS[$i]}"
                local backup_end="${DATABASE_BACKUP_ENDS[$i]}"
                local test_status="${DATABASE_TEST_STATUSES[$i]}"
                local disk_speed=$(calculate_disk_speed "$backup_file" "$BACKUP_START" "$BACKUP_END")
                local db_name=$(echo "${DATABASES[$i]}" | cut -d'|' -f3)  # Get the database name
                local db_type=$(echo "${DATABASES[$i]}" | cut -d'|' -f1)  # Get the database type
                local container_name=$(echo "${DATABASES[$i]}" | cut -d'|' -f2)  # Get the container name
                local db_user=$(echo "${DATABASES[$i]}" | cut -d'|' -f4)  # Get the database user
                local backup_size=$(human_readable_size "$(stat -c%s "$backup_file")")  # Get the backup size
                local original_db_size="${DATABASE_ORIGINAL_SIZES[$i]}"  # Get the original database size

                # Determine the restore command based on the database type
                local restore_command=""
                case "$db_type" in
                    "PostgreSQL"|"TimescaleDB")
                        restore_command="docker exec -i $container_name psql -U $db_user $db_name < $BACKUP_DATABASE_DIR/${db_name}-$(date +%Y%m%d).sql"
                        ;;
                    "MySQL"|"MariaDB")
                        restore_command="docker exec -i $container_name mysql -u $db_user -p$db_password $db_name < $BACKUP_DATABASE_DIR/${db_name}-$(date +%Y%m%d).sql"
                        ;;
                    "MongoDB")
                        restore_command="docker exec $container_name mongorestore --db $db_name $BACKUP_DATABASE_DIR/$db_name-$(date +%Y%m%d)"
                        ;;
                    "Redis")
                        restore_command="docker cp $backup_file $container_name:/data/dump.rdb && docker exec $container_name redis-cli shutdown save && docker start $container_name"
                        ;;
                    "Cassandra")
                        restore_command="docker exec $container_name nodetool refresh -- $db_name $(date +%Y%m%d)-snapshot"
                        ;;
                    "Elasticsearch")
                        restore_command="docker exec $container_name elasticsearch-snapshot --repository backup-repo --restore --snapshot $(date +%Y%m%d)"
                        ;;
                    "SQLite")
                        restore_command="docker cp $backup_file $container_name:/path/to/database.sqlite"
                        ;;
                    "Neo4j")
                        restore_command="docker exec $container_name neo4j-admin restore --from=$BACKUP_DATABASE_DIR"
                        ;;
                    "CockroachDB")
                        restore_command="docker exec $container_name cockroach sql --execute=\"RESTORE FROM '$BACKUP_DATABASE_DIR/backup'\""
                        ;;
                    "InfluxDB")
                        restore_command="docker exec $container_name influx restore -portable $BACKUP_DATABASE_DIR"
                        ;;
                    "Oracle")
                        restore_command="docker exec $container_name rman target / <<EOF
                        restore database;
EOF"
                        ;;
                    "RethinkDB")
                        restore_command="docker exec $container_name rethinkdb restore -f $BACKUP_DATABASE_DIR/rethinkdb-backup-$(date +%Y%m%d).tar.gz"
                        ;;
                    "Memcached")
                        restore_command="Memcached does not require a restore of persistent data. Ignoring..."
                        ;;
                    *)
                        restore_command="Unsupported database type: $db_type"
                        ;;
                esac

                ##########################################################################
                #
                #         DATABASE SECTION
                #
                ##########################################################################

                MESSAGE+="

                <table>
                  <tr>
                    <td style='border: 0; vertical-align: top;'>

                        <div class="stats_info_backup">
                            <strong style='font-size: 1.2em;'>Database: ${db_name}</strong><br>
                            <strong>Backup file location:</strong> ${BACKUP_DATABASE_DIR}<br>
                            <strong>Original DB File Size:</strong> ${original_db_size}<br>
                            <strong>File Size:</strong> $backup_size<br>
                            <strong>MD5 Checksum:</strong> $md5_checksum<br>
                            <strong>Verification Status:</strong> $test_status<br>
                            <strong>Backup Duration:</strong> $backup_duration<br>
                            <strong>Start:</strong> $backup_start<br>
                            <strong>Stop:</strong> $backup_end<br>
                            <strong>Disk Speed:</strong> $disk_speed<br>
                        </div>
                    </td>

                    <td style='border: 0; vertical-align: top;'>
                        <div class="stats_backup">
                        <div class="backup">${db_name}</div>
                        <div class="size">$backup_size</div>
                        <div class="enc">Encrypted: $ENCRYPTION_STATUS</div>
                        <div class="status">$test_status</div>
                        </div>
                    </td>
                </tr>
                <tr>
                    <td colspan="2" class="row-span">"



                if [ "$password" != "No encryption" ]; then
                    MESSAGE+="<strong>Password:</strong> $password<br><strong>Command to extract the encrypted database:</strong><br>
                    <pre>sudo openssl enc -d -aes-256-cbc -pbkdf2 -iter 10000 -in ${backup_file} -pass pass:$password | pigz -d | sudo tar -xvf - -C $BACKUP_DATABASE_DIR</pre>"
                    MESSAGE+="<strong>Command to restore the database:</strong><br>
                    <em>Before running this command blindly, please double-check within the corresponding project that this is indeed the correct command for your setup.</em><br>
                    <pre>${restore_command}</pre>"
                else
                    MESSAGE+="<strong>Command to extract the non-encrypted database:</strong><br>
                    <pre>sudo tar -xvf ${backup_file} -C $BACKUP_DATABASE_DIR</pre>"
                    MESSAGE+="<strong>Command to restore the database:</strong><br>
                    <em>Before running this command blindly, please double-check within the corresponding project that this is indeed the correct command for your setup.</em><br>
                    <pre>${restore_command}</pre>"
                fi

        MESSAGE+="</td>
            </tr>
        </table>"
    done
fi

##########################################################################
#
#         FINAL SECTION
#
##########################################################################

MESSAGE+="
            <br>
            <div class='separator'></div>
            <br>
            <h2><center>Backup Statistics:</center></h2>
            <table class='stats-table centered-table'>
                <thead>
                    <tr>
                        <th>Nr. Directories backed up</th>
                        <th>Nr. Files backed up</th>
                        <th>Total size backed up</th>
                        <th>Total backup time</th>
                        <th>Average backup time</th>
                        <th>Encrypted</th>
                        <th>Nr. of Rotations</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>$TOTAL_DIRECTORIES</td>
                        <td>$TOTAL_FILES</td>
                        <td>$TOTAL_BACKUP_SIZE</td>
                        <td>$((TOTAL_BACKUP_TIME / 60)) minutes and $((TOTAL_BACKUP_TIME % 60)) seconds</td>
                        <td>${AVERAGE_BACKUP_MINUTES} minutes and ${AVERAGE_BACKUP_SECONDS} seconds</td>
                        <td>$ENCRYPTION_STATUS</td>
                        <td>$TOTAL_DIRECTORY_BACKUPS</td>
                    </tr>
                </tbody>
            </table>

            <h2><center>Database Backup Statistics:</center></h2>
            <table class='stats-table centered-table'>
                <thead>
                    <tr>
                        <th>Nr. Databases backed up</th>
                        <th>Total size backed up</th>
                        <th>Total backup time</th>
                        <th>Average backup time</th>
                        <th>Encrypted</th>
                        <th>Nr. of Rotations</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>$TOTAL_DATABASES</td>
                        <td>$TOTAL_DATABASE_BACKUP_SIZE</td>
                        <td>$((TOTAL_DATABASE_BACKUP_TIME / 60)) minutes and $((TOTAL_DATABASE_BACKUP_TIME % 60)) seconds</td>
                        <td>${AVERAGE_DATABASE_BACKUP_MINUTES} minutes and ${AVERAGE_DATABASE_BACKUP_SECONDS} seconds</td>
                        <td>$ENCRYPTION_STATUS</td>
                        <td>$TOTAL_DATABASE_BACKUPS</td>
                    </tr>
                </tbody>
            </table>

            <h2><center>Host Statistics:</center></h2>
            <table class='stats-table centered-table'>
                <thead>
                    <tr>
                        <th>Kernel Version</th>
                        <th>Total Memory</th>
                        <th>Used Memory</th>
                        <th>Available Memory</th>
                        <th>CPU Load</th>
                        <th>Disk Usage</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>$KERNEL_VERSION</td>
                        <td>$TOTAL_MEMORY</td>
                        <td>$USED_MEMORY</td>
                        <td>$AVAILABLE_MEMORY</td>
                        <td>$CPU_LOAD</td>
                        <td>$DISK_USAGE</td>
                    </tr>
                </tbody>
            </table>"

            if [ "$BACKUP_123" == "Y" ]; then
                MESSAGE+="
                <h2><center>123 BACKUP:</center></h2>
                    <table class='stats-table centered-table'>
                        <thead>
                            <tr>
                                <th>First disk copy</th>
                                    <th>Second disk copy</th>
                                        </tr>
                        </thead>
                        <tbody>
                            <tr>
                                <td>$SATA_DISK1</td>
                                <td>$SATA_DISK2</td>
                                </tr>
                        </tbody>
                    </table>"
            fi

            MESSAGE+="
            <footer>
                <p>Generated by your Backup System - $(date +'%d %b %Y, %H:%M:%S')</p>
                <p>If you're enjoying this script, please 🎉 <a href='https://buymeacoffee.com/DartSteven' target='_blank' class='coffee-link'><img src='https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png' alt='Buy me a coffee' class='coffee-logo'>Buy me a coffee</a> 🎉 </p>
            </footer>
        </div>
    </body>
    </html>"

    # Send the email via msmtp
    echo -e "Subject: $SUBJECT\nTo: $EMAIL_RECIPIENT\nFrom: $SMTP_FROM\nMIME-Version: 1.0\nContent-Type: text/html\n\n$MESSAGE" | \
    msmtp --host="$SMTP_HOST" --port="$SMTP_PORT" --auth=on --user="$SMTP_USER" --passwordeval="echo $SMTP_PASSWORD" \
          --tls=on --tls-starttls=on --from="$SMTP_FROM" "$EMAIL_RECIPIENT"
}


# Function to calculate the total size of a directory in bytes
calculate_total_size() {
    local dir="$1"
    du -sb "$dir" | awk '{print $1}'
}

# Calculate backup size in bytes and convert to a readable format
calculate_backup_size() {
    local file_path=$1
    local size_bytes=$(stat -c%s "$file_path")

    # Function to convert size to a readable scale (B, KiB, MiB, GiB, TiB)
    human_readable_size() {
        local size=$1
        local unit="B"
        if (( $(echo "$size >= 1024" | bc -l) )); then
            size=$(echo "scale=2; $size / 1024" | bc)
            unit="KiB"
        fi
        if (( $(echo "$size >= 1024" | bc -l) )); then
            size=$(echo "scale=2; $size / 1024" | bc)
            unit="MiB"
        fi
        if (( $(echo "$size >= 1024" | bc -l) )); then
            size=$(echo "scale=2; $size / 1024" | bc)
            unit="GiB"
        fi
        if (( $(echo "$size >= 1024" | bc -l) )); then
            size=$(echo "scale=2; $size / 1024" | bc)
            unit="TiB"
        fi
        echo "$size $unit"
    }

    # Calculate the backup size in a readable format
    BACKUP_SIZE=$(human_readable_size "$size_bytes")
}

# Calculate the total size of the backup directories (non-compressed)
TOTAL_BACKUP_DIR_SIZE=$(calculate_total_size "$BACKUP_DIR")
TOTAL_BACKUP_DATABASE_DIR_SIZE=$(calculate_total_size "$BACKUP_DATABASE_DIR")

# Calculate the total size of the compressed backup files
if [ "$ENCRYPT_BACKUP" == "Y" ]; then
    TOTAL_COMPRESSED_BACKUP_SIZE=$(find "$BACKUP_DIR" -type f -name "*.tar.gz.enc" -exec stat -c%s {} + | awk '{s+=$1} END {print s}')
    TOTAL_COMPRESSED_DATABASE_BACKUP_SIZE=$(find "$BACKUP_DATABASE_DIR" -type f -name "*.tar.gz.enc" -exec stat -c%s {} + | awk '{s+=$1} END {print s}')
else
    TOTAL_COMPRESSED_BACKUP_SIZE=$(find "$BACKUP_DIR" -type f -name "*.tar.gz" -exec stat -c%s {} + | awk '{s+=$1} END {print s}')
    TOTAL_COMPRESSED_DATABASE_BACKUP_SIZE=$(find "$BACKUP_DATABASE_DIR" -type f -name "*.tar.gz" -exec stat -c%s {} + | awk '{s+=$1} END {print s}')
fi

# Convert the sizes to integers to avoid scientific notation issues
TOTAL_COMPRESSED_BACKUP_SIZE=$(printf "%.0f" "$TOTAL_COMPRESSED_BACKUP_SIZE")
TOTAL_COMPRESSED_DATABASE_BACKUP_SIZE=$(printf "%.0f" "$TOTAL_COMPRESSED_DATABASE_BACKUP_SIZE")

# List of excluded directories in HTML
for EXCLUDED_DIR in "${EXCLUDE_DIRS[@]}"; do
    EXCLUDE_DIR_LIST="$EXCLUDE_DIR_LIST<li>${EXCLUDED_DIR}</li>"
done

# Cleanup old backups based on the defined retention days
for DIR in "${SOURCE_DIRS[@]}"; do
    find "$BACKUP_DIR" -type f -name "$(basename "$DIR")*.tar.gz" -mtime +$DAYS_TO_KEEP -exec rm -f {} \;
done

# Send the final email with all the backup files and database reports
if [ "$BACKUP_123" == "Y" ]; then
    copy_backups_to_destinations "${BACKUP_FILES[@]}" "${DATABASE_BACKUP_FILES[@]}"
fi
send_email
# END! :)
