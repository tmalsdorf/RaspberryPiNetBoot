# Configuration variables for addclient.sh
CLIENT_NFS_DIRECTORY="/data/clients/"
TFTP_DIRECTORY="/data/tftp/"
CLIENT_MASTER="raspios-lite/"
TFTP_MASTER="bootmaster/"
NFS_ROOT="192.168.1.20"
OWNER="pi"
SSH_PUBKEY_PATH="pubkey"  # Add the correct path to your SSH public key

# Configuration variables for getlatest.sh
BASE_URL="https://downloads.raspberrypi.org/raspios_lite_arm64/images/"
TMPIMG_DIR="tmpimg"
CLIENTMASTERDIR="/data/clients"
BOOTMASTERDIR="/data/tftp"
OUTPUT_LINK="raspios-lite"
GITHUB_URL="https://github.com/raspberrypi/rpi-firmware/raw/master"
DEFAULT_USER="pi"
DEFAULT_PASSWORD=""