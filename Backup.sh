#!/bin/bash

# Variable for naming the backup that will be sent via email
BACKUP_NAME=""

# Variable for the Server name
SERVER_NAME=""

# Variable to enable backup encryption (Y/N)
ENCRYPT_BACKUP="Y"

# Default variables for the source directories
SOURCE_DIRS=(
    "/home/JohnDoe"
    "/etc"
)

EXCLUDE_DIRS=(
    "/home/JohnDoe/Personal"
)

# Backup destination directory
BACKUP_DIR=""

LOG_FILE="$BACKUP_DIR/Compose.log"

EMAIL_RECIPIENT=""
SMTP_HOST=""
SMTP_PORT=""
SMTP_FROM=""
SMTP_USER=""
SMTP_PASSWORD=""
CURRENT_DATE=$(date +%Y%m%d)

# Variable to define how many days to retain backups, Change the number of days as needed
DAYS_TO_KEEP=6

# Variable to stop Docker before the backup
STOP_DOCKER_BEFORE_BACKUP="Y"


#################################################################################
#										#
#               !!  END OF VARIABLES TO MODIFY !!				#
#										#
#################################################################################

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
    else
        echo "Unable to determine the Linux distribution." >&2
        exit 1
    fi

    # Required packages
    REQUIRED_PACKAGES="tar pv pigz openssl msmtp"

    case "$DISTRO" in
        ubuntu|debian)
            # Check if packages are already installed
            for pkg in $REQUIRED_PACKAGES; do
                if ! dpkg -s $pkg > /dev/null 2>&1; then
                    echo "Installing package $pkg on $DISTRO..."
                    apt update && apt install -y $pkg
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

# Function to generate a secure password
generate_password() {
    openssl rand -base64 32
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

# Function to send an email
send_email() {
    SUBJECT="Backup Report - "$SERVER_NAME" - Executed on $(date +'%d %b %Y, %H:%M:%S')"

    # HTML template for the email
    MESSAGE="
    <!DOCTYPE html>
    <html lang='en'>
    <head>
        <meta charset='UTF-8'>
        <meta name='viewport' content='width=device-width, initial-scale=1.0'>
        <title>Backup Report</title>
        <style>
            body {
                font-family: 'Courier New', Courier, monospace;
                background-color: #2a2a38;
                color: #f0f0f0;
                margin: 0;
                padding: 0;
                text-align: center;
            }
            .container {
                max-width: 800px;
                margin: 20px auto;
                background-color: #3a3a4f;
                padding: 20px;
                border-radius: 8px;
                border: 1px solid #4c4c6c;
            }
            h1 {
                font-size: 24px;
                color: #ffffff;
                margin-bottom: 20px;
            }
            h2 {
                color: #f0f0f0;
                margin-bottom: 15px;
                font-size: 20px;
            }
            table {
                width: 100%;
                border-collapse: collapse;
                margin-bottom: 20px;
            }
            th, td {
                padding: 12px;
                border: 1px solid #555;
                text-align: left;
            }
            th {
                background-color: #2c2c40;
                color: #ffffff;
            }
            td {
                background-color: #3c3c50;
                color: #f0f0f0;
            }
            .metrics {
                background-color: #4a4a60;
                padding: 20px;
                border-radius: 8px;
                border: 1px solid #555;
                text-align: left;
            }
            .metrics p {
                font-size: 16px;
                line-height: 1.6;
                margin: 8px 0;
                color: #ffffff;
            }
            footer {
                margin-top: 20px;
                font-size: 12px;
                color: #b0b0b0;
            }
            .highlight {
                font-family: 'Courier New', Courier, monospace;
                color: #ffffff;
            }
            .command {
                font-family: 'Courier New', Courier, monospace;
                background-color: #333;
                color: #fff;
                padding: 10px;
                border-radius: 5px;
                white-space: pre-wrap;
                word-wrap: break-word;
                overflow-x: auto;
            }
        </style>
    </head>
    <body>
       <div class='container'>
            <h1>Backup \"$BACKUP_NAME\"<br> $(date +'%d %b %Y, %H:%M:%S')</h1>
            <h2>"$SERVER_NAME"</h2>

            <h2>Information:</h2>
            <table>
                <thead>
                    <tr>
                        <th>Backup Name</th>
                        <th>Source Directory</th>
                        <th>Destination Directory</th>
                    </tr>
                </thead>
                <tbody>
                   $SOURCE_DIR_LIST
                </tbody>
            </table>

            <h2>Directories Excluded from Backup</h2>
            <div class='metrics'>
                <ul>
                    $EXCLUDE_DIR_LIST
                </ul>
            </div>

            <!-- We add passwords and decryption commands -->
            <h2>Details:</h2>
            <div class='metrics'>"

    # Dynamically construct the metrics block to be inserted into the template
    for i in "${!BACKUP_FILES[@]}"; do
        local password="${BACKUP_PASSWORDS[$i]}"
        local encrypted_file="${BACKUP_FILES[$i]}"
        
        # Decryption command for each backup
        local decrypt_command=""
        local command_label=""

        if [ "$ENCRYPT_BACKUP" == "Y" ]; then
            decrypt_command="openssl enc -d -aes-256-cbc -pbkdf2 -iter 10000 -in $encrypted_file -pass pass:$password | pigz -d | tar -xvf - -C $BACKUP_DIR"
            command_label="Command to decrypt and decompress the backup:"
        else
            decrypt_command="pigz -d < $encrypted_file | tar -xvf - -C $BACKUP_DIR"
            command_label="Command to decompress the backup:"
        fi

        MESSAGE="$MESSAGE
            <p><strong>Backup Name:</strong> <span class='highlight'>${BACKUP_FILES[$i]}</span></p>
            <p><strong>Backup Size:</strong> ${BACKUP_SIZES[$i]}</p>
            <p><strong>MD5 Checksum:</strong> ${MD5_SUMS[$i]}</p>
            <p><strong>Disk Write Speed:</strong> ${DISK_SPEEDS[$i]} MB/s</p>
            <p><strong>Backup Duration:</strong> ${BACKUP_DURATIONS[$i]}</p>
            <p>Start: ${BACKUP_STARTS[$i]}</p>
            <p>End: ${BACKUP_ENDS[$i]}</p>
            <p><strong>Backup Test Status:</strong> ${TEST_STATUSES[$i]}</p>
            <p><strong>Decryption Password:</strong> <span class='highlight'>${BACKUP_PASSWORDS[$i]}</span></p>
            <p><strong>$command_label</strong></p>
            <pre class='command'>$decrypt_command</pre>
            <br><br>"
    done

    # Close the HTML
    MESSAGE="$MESSAGE
            </div>
            <footer>
                <p>Generated by your Backup System</p>
                <p>If you're enjoying this script, please Buy me a coffee here: <a href='https://buymeacoffee.com/DartSteven' target='_blank' style='color: #ffffff;'>buymeacoffee.com/DartSteven</a></p> <!-- Added the link -->
            </footer>
        </div>
    </body>
    </html>"

    # Sending the email via msmtp
    echo -e "Subject: $SUBJECT\nTo: $EMAIL_RECIPIENT\nFrom: $SMTP_FROM\nMIME-Version: 1.0\nContent-Type: text/html\n\n$MESSAGE" | \
    msmtp --host="$SMTP_HOST" --port="$SMTP_PORT" --auth=on --user="$SMTP_USER" --passwordeval="echo $SMTP_PASSWORD" \
          --tls=on --tls-starttls=on --from="$SMTP_FROM" "$EMAIL_RECIPIENT"
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

    # Assign the result to the global BACKUP_DURATION variable
    BACKUP_DURATION="${minutes} minutes and ${seconds} seconds"
}

# Function to calculate disk write speed
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


# Avoid duplication of disk speed when inserting it in the email
#echo "Disk Write Speed: ${DISK_SPEED} MB/s" | tee -a "$LOG_FILE"

# Function to verify the backup using pigz for parallel decompression
verify_backup() {
    local file="$1"
    TEST_START=$(date +%s)

    # Verify the backup using pigz for parallel decompression
    if pigz -dc -9 "$file" | tar -tf - > /dev/null 2>&1; then
        TEST_END=$(date +%s)
        TEST_STATUS="Successful"
    else
        TEST_END=$(date +%s)
        TEST_STATUS="Failed"
    fi

    # Calculate the test duration in minutes and seconds
    local test_duration=$(( TEST_END - TEST_START ))
    local test_minutes=$(( test_duration / 60 ))
    local test_seconds=$(( test_duration % 60 ))
    TEST_DURATION="${test_minutes} minutes and ${test_seconds} seconds"

    # Convert the timestamps to a readable format
    TEST_START_READABLE=$(convert_timestamp_to_date "$TEST_START")
    TEST_END_READABLE=$(convert_timestamp_to_date "$TEST_END")
}


# Stop Docker only if necessary
if [ "$STOP_DOCKER_BEFORE_BACKUP" == "Y" ];then
    sudo systemctl stop docker.service
    sudo systemctl stop docker.socket
    sudo systemctl stop containerd.service
fi

# List of excluded directories in HTML
for EXCLUDED_DIR in "${EXCLUDE_DIRS[@]}"; do
    EXCLUDE_DIR_LIST="$EXCLUDE_DIR_LIST<li>${EXCLUDED_DIR}</li>"
done

# Start backup for all source directories
# Array to store generated passwords
BACKUP_PASSWORDS=()

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

    # Create the backup with 'pv' to show progress
    tar $EXCLUDE_OPTIONS -cf - "$DIR" -P | pv -s $(du -sb "$DIR" | awk '{print $1}') | pigz -9 > "$BACKUP_FILE" 2>> "$LOG_FILE"
    
    # Log the backup end time
    BACKUP_END=$(date +%s)

    # Write a log with the end timestamp
    echo "Backup completed for $DIR_NAME at $(date)" | tee -a "$LOG_FILE"

    # Convert timestamps to a readable format
    BACKUP_START_READABLE=$(convert_timestamp_to_date "$BACKUP_START")
    BACKUP_END_READABLE=$(convert_timestamp_to_date "$BACKUP_END")

    # Calculate the backup duration
    calculate_backup_duration "$BACKUP_START" "$BACKUP_END"

    # Calculate disk write speed (use a separate variable)
    DISK_SPEED=$(calculate_disk_speed "$BACKUP_FILE" "$BACKUP_START" "$BACKUP_END")

    # Calculate backup size in bytes
    BACKUP_SIZE_BYTES=$(stat -c%s "$BACKUP_FILE")

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

    # Verify the backup
    verify_backup "$BACKUP_FILE"

    # If encryption is enabled, generate a password and encrypt the backup
    if [ "$ENCRYPT_BACKUP" == "Y" ]; then
        PASSWORD=$(generate_password)
        BACKUP_FILE=$(encrypt_backup "$BACKUP_FILE" "$PASSWORD")
        BACKUP_PASSWORDS+=("$PASSWORD")  # Store the password for this backup
    else
        BACKUP_PASSWORDS+=("No encryption")  # No password if encryption is disabled
    fi

    # Add the source directory to the HTML report
    SOURCE_DIR_LIST="$SOURCE_DIR_LIST<tr><td>${BACKUP_FILE}</td><td><center>${DIR_NAME}</center></td><td>${BACKUP_DIR}</td></tr>"

    # Store values in their respective arrays
    BACKUP_FILES+=("$BACKUP_FILE")
    BACKUP_SIZES+=("$BACKUP_SIZE")
    MD5_SUMS+=("$MD5_SUM")
    DISK_SPEEDS+=("$DISK_SPEED")
    BACKUP_DURATIONS+=("$BACKUP_DURATION")
    BACKUP_STARTS+=("$BACKUP_START_READABLE")
    BACKUP_ENDS+=("$BACKUP_END_READABLE")
    TEST_STATUSES+=("$TEST_STATUS")
done


# Cleanup old backups based on the defined retention days
for DIR in "${SOURCE_DIRS[@]}"; do
    find "$BACKUP_DIR" -type f -name "$(basename "$DIR")*.tar.gz" -mtime +$DAYS_TO_KEEP -exec rm -f {} \;
done


# Restart Docker if necessary
if [ "$STOP_DOCKER_BEFORE_BACKUP" == "Y" ]; then
    sudo systemctl start docker.service
    sudo systemctl start docker.socket
    sudo systemctl start containerd.service
fi

# Send the final email with the password if encryption is enabled
if [ "$ENCRYPT_BACKUP" == "Y" ]; then
    # Ensure the generated password is sent
    send_email "$PASSWORD" "$BACKUP_FILE"
else
    send_email "No encryption" "$BACKUP_FILE"
fi
