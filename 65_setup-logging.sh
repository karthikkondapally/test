LOGS_FILESHARE_NAME="shared"
LOG_FILESHARE_MOUNT_PATH="/sharedcluster/log"

sudo mkdir -p /etc/smbcredentials

# Create credentials file if it doesn't exist
cred_file="/etc/smbcredentials/sa_cred_file.cred"
if [ ! -f "$cred_file" ]; then
    sudo bash -c "echo \"username=${AZURE_STORAGE_ACCOUNT}\" >> $cred_file"
    sudo bash -c "echo \"password=${AZURE_STORAGE_KEY}\" >> $cred_file"
fi
           
if [[ $(az storage share exists --name "${LOGS_FILESHARE_NAME}" --output tsv) == "True" ]]; then

    echo "Persisted file share exists."
    sudo mkdir -p "${LOG_FILESHARE_MOUNT_PATH}"
    mountpoint="${LOG_FILESHARE_MOUNT_PATH}"

    # Prepare fstab entry
    fstab_entry="//${AZURE_STORAGE_ACCOUNT}.file.core.windows.net/${LOGS_FILESHARE_NAME} ${mountpoint} cifs nofail,credentials=$cred_file,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30"

    # Add fstab entry if it doesn't exist
    if ! grep -qF -- "$fstab_entry" /etc/fstab; then
        echo "$fstab_entry" | sudo tee -a /etc/fstab > /dev/null
    fi

    # Mount the persisted fileshare on each instance if not already mounted

    if ! mountpoint -q "$mountpoint"; then
        sudo mount -t cifs "//${AZURE_STORAGE_ACCOUNT}.file.core.windows.net/${LOGS_FILESHARE_NAME}" "$mountpoint" -o credentials=$cred_file,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30
    fi
else
    echo "Persisted file share does not exist."
fi
LOCAL_HOSTNAME=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance/compute/osProfile/computerName?api-version=2021-02-01&format=text")
mkdir -p "${LOG_FILESHARE_MOUNT_PATH}/${LOCAL_HOSTNAME}"
sed -i "s|^#LOGBASE=.*|LOGBASE=${LOG_FILESHARE_MOUNT_PATH}/${LOCAL_HOSTNAME}/mjs|g" /usr/local/matlab/toolbox/parallel/bin/mjs_def.sh
