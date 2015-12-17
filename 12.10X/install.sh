#!/bin/bash

### Gathering all input required for a full automated installation
LOGFILE="/var/log/automatedKodi.install.log"
export NCURSES_NO_UTF8_ACS=1
echo 'Dpkg::Progress-Fancy "1";' > /etc/apt/apt.conf.d/99progressbar
if [ "$(id -u)" != "0" ]; then
	echo "Sorry, you must run this script as root. Add to the beginning of your start command(bash SCRIPT)"
	exit 1
fi

echo "starting installer"
apt-get -y install dialog >> ${LOGFILE}

if (dialog --title "Automated Kodi installer" --yesno "Version: 0.1 Installation will start soon. Please read the following carefully. The script has been confirmed to work on Ubuntu 14.04. 2. While several testing runs identified no known issues, the author cannot be held accountable for any problems that might occur due to the script." 12 78); then
    echo
else
    dialog --title "ABORT" --infobox "You have aborted. Please try again." 6 50
	exit 0
fi

UNAME=$(dialog --title "System Username" --inputbox "Enter the user you want your scripts to run as. (Case sensitive, Suggested username is \"kodi\")" 10 50 kodi 3>&1 1>&2 2>&3)

if [ ! -d "/home/$UNAME" ]; then
  if (dialog --yesno 'The user, '${UNAME}', you entered does not exist. Add new user?' 10 30)
  then
    UPASSWORD=$(dialog --title "System Username" --inputbox "Enter a Password for your new user." 10 50 3>&1 1>&2 2>&3)
	adduser ${UNAME} --gecos  "Knight,Cinema,0,000-000-0000,000-000-0000" --disabled-password
	echo ${UNAME}":"${UPASSWORD} | chpasswd
  else
    exit 0
  fi
fi

DLCLIENT=$(dialog --checklist "Choose which download method you would like installed:" 12 50 4 \
"Torrents" "" on \
"Newsgroups" "" on 3>&1 1>&2 2>&3)

APPS=$(dialog --checklist "Choose which apps you would like installed:" 12 50 4 \
"KODI" "" on \
"SABnzbd" "" on \
"Deluge" "" on \
"Sonarr" "" on \
"SickRage" "" on \
"CouchPotato" "" on \
"ReverseProxy" "" on 3>&1 1>&2 2>&3)

if [[ ${APPS} == *ReverseProxy* ]]; then
    PROXY=$(dialog --checklist "Choose which Reverse Proxy you would like installed:" 12 50 4 \
    "Apache" "" on \
    "Nginx" "" on 3>&1 1>&2 2>&3)
fi

USERNAME=$(dialog --title "Username" --inputbox "Enter the username you want to use to log into your web applications" 10 50 3>&1 1>&2 2>&3)
PASSWORD=$(dialog --title "Password" --passwordbox "Enter the Password you want to use to log into your web applications" 10 50 3>&1 1>&2 2>&3)
DOWNLOADDIR=$(dialog --title "Storage Directory" --inputbox "Enter the directory where you would like downloads saved. (/home/john would save completed downloads in /home/john/Downloads/Complete" 10 50 /home/${UNAME} 3>&1 1>&2 2>&3)
DOWNLOADDIR=${DOWNLOADDIR%/}
MOVIEDIR=$(dialog --title "Movie Directory" --inputbox "Enter the directory where you would like movies saved. (/home/john would save completed movies in /home/john/Movies" 10 50 /home/${UNAME} 3>&1 1>&2 2>&3)
MOVIEDIR=${MOVIEDIR%/}
TVSHOWDIR=$(dialog --title "TVshow Directory" --inputbox "Enter the directory where you would like TVshows saved. (/home/john would save completed movies in /home/john/TVshows" 10 50 /home/${UNAME} 3>&1 1>&2 2>&3)
TVSHOWDIR=${TVSHOWDIR%/}

if [[ ${APPS} == *SABnzbd* ]] && [[ ${DLCLIENT} == *Newsgroups* ]]; then
    USENETHOST=$(dialog --title "Usenet" --inputbox "Please enter your Usenet servers Hostname" 10 50 3>&1 1>&2 2>&3)
	USENETUSR=$(dialog --title "Usenet" --inputbox "Please enter your Usenet servers Username" 10 50 3>&1 1>&2 2>&3)
	USENETPASS=$(dialog --title "Usenet" --insecure --passwordbox "Please enter your Usenet servers Password" 10 50 3>&1 1>&2 2>&3)
	USENETPORT=$(dialog --title "Usenet" --inputbox "Please enter your Usenet servers connection Port" 10 50 3>&1 1>&2 2>&3)
	USENETCONN=$(dialog --title "Usenet" --inputbox "Please enter the maximum number of connections your server allows " 10 50 3>&1 1>&2 2>&3)
	if (dialog --title "Usenet" --yesno "Does your usenet server use SSL?" 8 50); then
		USENETSSL=1
	else
		USENETSSL=0
	fi
fi

if [[ ${APPS} == *CouchPotato* ]] || [[ ${APPS} == *Sonarr* ]]; then
	if [[ ${DLCLIENT} == *Newsgroups* ]]; then
	    INDEXHOST=$(dialog --title "Usenet Indexer" --inputbox "Please enter your Newsnab powered Indexers hostname" 10 50 3>&1 1>&2 2>&3)
	    INDEXAPI=$(dialog --title "Usenet Indexer" --inputbox "Please enter your Newsnab powered Indexers API key" 10 50 3>&1 1>&2 2>&3)
	    INDEXNAME=$(dialog --title "Usenet Indexer" --inputbox "Please enter a name for your Newsnab powered Indexer (This can be anything)" 10 50 3>&1 1>&2 2>&3)
	    API=$(date +%s | sha256sum | base64 | head -c 32 ; echo)
	fi
	if [[ ${DLCLIENT} == *Torrent* ]]; then
	    BLACKHOLE=$(dialog --title "Blackhole" --inputbox "Please enter your Blackhole folder" 10 50 ${DOWNLOADDIR}/Downloads/Torrents 3>&1 1>&2 2>&3)
    fi
fi

if [[ ${APPS} == *KODI* ]]; then
    KODI=1
    GFX_CARD=$(lspci |grep VGA |awk -F: {' print $3 '} |awk {'print $1'} |tr [a-z] [A-Z])

    KODI_PPA=$(dialog --radiolist "Choose which Kodi version you would like:" 20 50 3 \
    1 "Official PPA - Install the release version." on \
    2 "Unstable PPA - Install the Alpha/Beta/RC version." off 3>&1 1>&2 2>&3)

    if getent passwd kodi > /dev/null 2>&1; then
	    echo "User KODI already exists"
	    KODI_USER="kodi"
    else
        adduser kodi --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password
	    echo "User KODI has been added"
	    echo "kodi:"${PASSWORD} | chpasswd
	    passwd -l root
	    KODI_USER="kodi"
    fi
fi
### Finished gathering all input

THIS_FILE=$0
SCRIPT_VERSION="0.1"
VIDEO_DRIVER=""
HOME_DIRECTORY="/home/$KODI_USER/"
KERNEL_DIRECTORY=${HOME_DIRECTORY}"kernel/"
TEMP_DIRECTORY=${HOME_DIRECTORY}"temp/"
ENVIRONMENT_FILE="/etc/environment"
CRONTAB_FILE="/etc/crontab"
DIST_UPGRADE_FILE="/etc/cron.d/dist_upgrade.sh"
DIST_UPGRADE_LOG_FILE="/var/log/updates.log"
KODI_ADDONS_DIR=${HOME_DIRECTORY}".kodi/addons/"
KODI_USERDATA_DIR=${HOME_DIRECTORY}".kodi/userdata/"
KODI_KEYMAPS_DIR=${KODI_USERDATA_DIR}"keymaps/"
KODI_ADVANCEDSETTINGS_FILE=${KODI_USERDATA_DIR}"advancedsettings.xml"
KODI_INIT_CONF_FILE="/etc/init/kodi.conf"
KODI_XSESSION_FILE="/home/kodi/.xsession"
UPSTART_JOB_FILE="/lib/init/upstart-job"
XWRAPPER_FILE="/etc/X11/Xwrapper.config"
GRUB_CONFIG_FILE="/etc/default/grub"
GRUB_HEADER_FILE="/etc/grub.d/00_header"
SYSTEM_LIMITS_FILE="/etc/security/limits.conf"
INITRAMFS_SPLASH_FILE="/etc/initramfs-tools/conf.d/splash"
INITRAMFS_MODULES_FILE="/etc/initramfs-tools/modules"
XWRAPPER_CONFIG_FILE="/etc/X11/Xwrapper.config"
MODULES_FILE="/etc/modules"
REMOTE_WAKEUP_RULES_FILE="/etc/udev/rules.d/90-enable-remote-wakeup.rules"
AUTO_MOUNT_RULES_FILE="/etc/udev/rules.d/media-by-label-auto-mount.rules"
SYSCTL_CONF_FILE="/etc/sysctl.conf"
RSYSLOG_FILE="/etc/init/rsyslog.conf"
POWERMANAGEMENT_DIR="/etc/polkit-1/localauthority/50-local.d/"
DOWNLOAD_URL="https://github.com/dtctd/Kodi/raw/master/12.10X/download/"
KODI_PPA_STABLE="ppa:team-xbmc/ppa"
KODI_PPA_UNSTABLE="ppa:team-xbmc/unstable"
HTS_TVHEADEND_PPA="ppa:jabbors/hts-stable"
OSCAM_PPA="ppa:oscam/ppa"
XSWAT_PPA="ppa:ubuntu-x-swat/x-updates"
MESA_PPA="ppa:wsnipex/mesa"

DIALOG_WIDTH=70
SCRIPT_TITLE="KODI ubuntu universal installer v$SCRIPT_VERSION for Ubuntu 12.04 to 14.04 by Me"

# import Ubuntu release variables
. /etc/lsb-release

## ------ START functions ---------

function showInfo() {
    CUR_DATE=$(date +%Y-%m-%d" "%H:%M)
    echo "$CUR_DATE - INFO :: $@" >> ${LOGFILE}
    dialog --title "Installing & configuring..." --backtitle "$SCRIPT_TITLE" --infobox "\n$@" 5 ${DIALOG_WIDTH}
}

function showError() {
    CUR_DATE=$(date +%Y-%m-%d" "%H:%M)
    echo "$CUR_DATE - ERROR :: $@" >> ${LOGFILE}
    dialog --title "Error" --backtitle "$SCRIPT_TITLE" --msgbox "$@" 8 ${DIALOG_WIDTH}
}

function showDialog() {
	dialog --title "KODI installation script" \
		--backtitle "$SCRIPT_TITLE" \
		--msgbox "\n$@" 12 ${DIALOG_WIDTH}
}

function update() {
    sudo apt-get update > /dev/null 2>&1
}

function createFile() {
    FILE="$1"
    IS_ROOT="$2"
    REMOVE_IF_EXISTS="$3"
    
    if [ -e "$FILE" ] && [ "$REMOVE_IF_EXISTS" == "1" ]; then
        sudo rm "$FILE" > /dev/null
    else
        if [ "$IS_ROOT" == "0" ]; then
            touch "$FILE" > /dev/null
        else
            sudo touch "$FILE" > /dev/null
        fi
    fi
}

function createDirectory() {
    DIRECTORY="$1"
    GOTO_DIRECTORY="$2"
    IS_ROOT="$3"
    
    if [ ! -d "$DIRECTORY" ];
    then
        if [ "$IS_ROOT" == "0" ]; then
            mkdir -p "$DIRECTORY" > /dev/null 2>&1
        else
            sudo mkdir -p "$DIRECTORY" > /dev/null 2>&1
        fi
    fi
    
    if [ "$GOTO_DIRECTORY" == "1" ];
    then
        cd ${DIRECTORY}
    fi
}

function handleFileBackup() {
    FILE="$1"
    BACKUP="$1.bak"
    IS_ROOT="$2"
    DELETE_ORIGINAL="$3"

    if [ -e "$BACKUP" ];
	then
	    if [ "$IS_ROOT" == "1" ]; then
	        sudo rm "$FILE" > /dev/null 2>&1
		    sudo cp "$BACKUP" "$FILE" > /dev/null 2>&1
	    else
		    rm "$FILE" > /dev/null 2>&1
		    cp "$BACKUP" "$FILE" > /dev/null 2>&1
		fi
	else
	    if [ "$IS_ROOT" == "1" ]; then
		    sudo cp "$FILE" "$BACKUP" > /dev/null 2>&1
		else
		    cp "$FILE" "$BACKUP" > /dev/null 2>&1
		fi
	fi
	
	if [ "$DELETE_ORIGINAL" == "1" ]; then
	    sudo rm "$FILE" > /dev/null 2>&1
	fi
}

function appendToFile() {
    FILE="$1"
    CONTENT="$2"
    IS_ROOT="$3"
    
    if [ "$IS_ROOT" == "0" ]; then
        echo "$CONTENT" | tee -a "$FILE" > /dev/null 2>&1
    else
        echo "$CONTENT" | sudo tee -a "$FILE" > /dev/null 2>&1
    fi
}

function addRepository() {
    REPOSITORY=$@
    KEYSTORE_DIR=${HOME_DIRECTORY}".gnupg/"
    createDirectory "$KEYSTORE_DIR" 0 0
    sudo add-apt-repository -y ${REPOSITORY} > /dev/null 2>&1

    if [ "$?" == "0" ]; then
        update
        showInfo "$REPOSITORY repository successfully added"
        echo 1
    else
        showError "Repository $REPOSITORY could not be added (error code $?)"
        echo 0
    fi
}

function isPackageInstalled() {
    PACKAGE=$@
    sudo dpkg-query -l ${PACKAGE} > /dev/null 2>&1
    
    if [ "$?" == "0" ]; then
        echo 1
    else
        echo 0
    fi
}

function aptInstall() {
    PACKAGE=$@
    IS_INSTALLED=$(isPackageInstalled ${PACKAGE})

    if [ "$IS_INSTALLED" == "1" ]; then
        showInfo "Skipping installation of $PACKAGE. Already installed."
        echo 1
    else
        sudo apt-get -f install > /dev/null 2>&1
        sudo apt-get -y install ${PACKAGE} > /dev/null 2>&1
        
        if [ "$?" == "0" ]; then
            showInfo "$PACKAGE successfully installed"
            echo 1
        else
            showError "$PACKAGE could not be installed (error code: $?)"
            echo 0
        fi 
    fi
}

function download() {
    URL="$@"
    wget -q "$URL" > /dev/null 2>&1
}

function move() {
    SOURCE="$1"
    DESTINATION="$2"
    IS_ROOT="$3"
    
    if [ -e "$SOURCE" ];
	then
	    if [ "$IS_ROOT" == "0" ]; then
	        mv "$SOURCE" "$DESTINATION" > /dev/null 2>&1
	    else
	        sudo mv "$SOURCE" "$DESTINATION" > /dev/null 2>&1
	    fi
	    
	    if [ "$?" == "0" ]; then
	        echo 1
	    else
	        showError "$SOURCE could not be moved to $DESTINATION (error code: $?)"
	        echo 0
	    fi
	else
	    showError "$SOURCE could not be moved to $DESTINATION because the file does not exist"
	    echo 0
	fi
}

function installDependencies() {
    echo "-- Installing script dependencies..."
    echo ""
    sudo apt-get -y install python-software-properties > /dev/null 2>&1
	sudo apt-get -y install dialog software-properties-common > /dev/null 2>&1
}

function fixLocaleBug() {
    createFile ${ENVIRONMENT_FILE}
    handleFileBackup ${ENVIRONMENT_FILE} 1
    appendToFile ${ENVIRONMENT_FILE} "LC_MESSAGES=\"C\""
    appendToFile ${ENVIRONMENT_FILE} "LC_ALL=\"en_US.UTF-8\""
	showInfo "Locale environment bug fixed"
}

function fixUsbAutomount() {
    handleFileBackup "$MODULES_FILE" 1 1
    appendToFile ${MODULES_FILE} "usb-storage"
    createDirectory "$TEMP_DIRECTORY" 1 0
    download ${DOWNLOAD_URL}"media-by-label-auto-mount.rules"

    if [ -e ${TEMP_DIRECTORY}"media-by-label-auto-mount.rules" ]; then
	    IS_MOVED=$(move ${TEMP_DIRECTORY}"media-by-label-auto-mount.rules" "$AUTO_MOUNT_RULES_FILE")
	    showInfo "USB automount successfully fixed"
	else
	    showError "USB automount could not be fixed"
	fi
}

function applyKodiNiceLevelPermissions() {
	createFile ${SYSTEM_LIMITS_FILE}
    appendToFile ${SYSTEM_LIMITS_FILE} "$KODI_USER             -       nice            -1"
	showInfo "Allowed KODI to prioritize threads"
}

function addUserToRequiredGroups() {
	sudo adduser ${KODI_USER} video > /dev/null 2>&1
	sudo adduser ${KODI_USER} audio > /dev/null 2>&1
	sudo adduser ${KODI_USER} users > /dev/null 2>&1
	sudo adduser ${KODI_USER} fuse > /dev/null 2>&1
	sudo adduser ${KODI_USER} cdrom > /dev/null 2>&1
	sudo adduser ${KODI_USER} plugdev > /dev/null 2>&1
    sudo adduser ${KODI_USER} dialout > /dev/null 2>&1
	showInfo "KODI user added to required groups"
}

function addKodiPpa() {
    if [ ${KODI_PPA} == 2 ]
	then
        IS_ADDED=$(addRepository "$KODI_PPA_UNSTABLE")
	else
		IS_ADDED=$(addRepository "$KODI_PPA_STABLE")
	fi
}

function distUpgrade() {
    showInfo "Updating Ubuntu with latest packages (may take a while)..."
	update
	sudo apt-get -y dist-upgrade > /dev/null 2>&1
	showInfo "Ubuntu installation updated"
}

function installXinit() {
    showInfo "Installing xinit..."
    IS_INSTALLED=$(aptInstall xinit)
}

function installPowerManagement() {
    showInfo "Installing power management packages..."
    createDirectory "$TEMP_DIRECTORY" 1 0
    sudo apt-get install -y policykit-1 > /dev/null 2>&1
    sudo apt-get install -y upower > /dev/null 2>&1
    sudo apt-get install -y udisks > /dev/null 2>&1
    sudo apt-get install -y acpi-support > /dev/null 2>&1
    sudo apt-get install -y consolekit > /dev/null 2>&1
    sudo apt-get install -y pm-utils > /dev/null 2>&1
	download ${DOWNLOAD_URL}"custom-actions.pkla"
	createDirectory "$POWERMANAGEMENT_DIR"
    IS_MOVED=$(move ${TEMP_DIRECTORY}"custom-actions.pkla" "$POWERMANAGEMENT_DIR")
}

function installAudio() {
    showInfo "Installing audio packages....\n!! Please make sure no used channels are muted !!"
    sudo apt-get install -y linux-sound-base alsa-base alsa-utils > /dev/null 2>&1
    sudo alsamixer
}

function Installnfscommon() {
    showInfo "Installing ubuntu package nfs-common (kernel based NFS client support)"
    sudo apt-get install -y nfs-common > /dev/null 2>&1
}

function installLirc() {
    clear
    echo ""
    echo "Installing lirc..."
    echo ""
    echo "------------------"
    echo ""
    
	sudo apt-get -y install lirc
	
	if [ "$?" == "0" ]; then
        showInfo "Lirc successfully installed"
    else
        showError "Lirc could not be installed (error code: $?)"
    fi
}

function allowRemoteWakeup() {
    showInfo "Allowing for remote wakeup (won't work for all remotes)..."
	createDirectory "$TEMP_DIRECTORY" 1 0
	handleFileBackup "$REMOTE_WAKEUP_RULES_FILE" 1 1
	download ${DOWNLOAD_URL}"remote_wakeup_rules"
	
	if [ -e ${TEMP_DIRECTORY}"remote_wakeup_rules" ]; then
	    sudo mv ${TEMP_DIRECTORY}"remote_wakeup_rules" "$REMOTE_WAKEUP_RULES_FILE" > /dev/null 2>&1
	    showInfo "Remote wakeup rules successfully applied"
	else
	    showError "Remote wakeup rules could not be downloaded"
	fi
}

function installTvHeadend() {
    showInfo "Adding jabbors hts-stable PPA..."
	addRepository "$HTS_TVHEADEND_PPA"

    clear
    echo ""
    echo "Installing tvheadend..."
    echo ""
    echo "------------------"
    echo ""

    sudo apt-get -y install tvheadend
    
    if [ "$?" == "0" ]; then
        showInfo "TvHeadend successfully installed"
    else
        showError "TvHeadend could not be installed (error code: $?)"
    fi
}

function installOscam() {
    showInfo "Adding oscam PPA..."
    addRepository "$OSCAM_PPA"

    showInfo "Installing oscam..."
    IS_INSTALLED=$(aptInstall oscam-svn)
}

function installKodi() {
    showInfo "Installing Kodi..."
    IS_INSTALLED=$(aptInstall Kodi)
}

function installKodiAddonRepositoriesInstaller() {
    showInfo "Installing Addon Repositories Installer addon..."
	createDirectory "$TEMP_DIRECTORY" 1 0
	download ${DOWNLOAD_URL}"plugin.program.repo.installer-1.0.5.tar.gz"
    createDirectory "$KODI_ADDONS_DIR" 0 0

    if [ -e ${TEMP_DIRECTORY}"plugin.program.repo.installer-1.0.5.tar.gz" ]; then
        tar -xvzf ${TEMP_DIRECTORY}"plugin.program.repo.installer-1.0.5.tar.gz" -C "$KODI_ADDONS_DIR" > /dev/null 2>&1
        
        if [ "$?" == "0" ]; then
	        showInfo "Addon Repositories Installer addon successfully installed"
	    else
	        showError "Addon Repositories Installer addon could not be installed (error code: $?)"
	    fi
    else
	    showError "Addon Repositories Installer addon could not be downloaded"
    fi
}

function configureAtiDriver() {
    sudo aticonfig --initial -f > /dev/null 2>&1
    sudo aticonfig --sync-vsync=on > /dev/null 2>&1
    sudo aticonfig --set-pcs-u32=MCIL,HWUVD_H264Level51Support,1 > /dev/null 2>&1
}

function ChooseATIDriver() {
         cmd=(dialog --title "Radeon-OSS drivers" \
                     --backtitle "$SCRIPT_TITLE" \
             --radiolist "It seems you are running ubuntu 13.10. You may install updated radeon oss drivers with VDPAU support. this allows for HD audio amung other things. This is the new default for Gotham and XVBA is depreciated. bottom line. this is what you want." 
             15 ${DIALOG_WIDTH} 6)
        
        options=(1 "Yes- install radeon-OSS (will install 3.13 kernel)" on
                 2 "No - Keep old fglrx drivers (NOT RECOMENDED)" off)
         
        choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

         case ${choice//\"/} in
             1)
                     InstallRadeonOSS
                 ;;
             2)
                     VIDEO_DRIVER="fglrx"
                 ;;
             *)
                     ChooseATIDriver
                 ;;
         esac
}

function InstallRadeonOSS() {
    VIDEO_DRIVER="xserver-xorg-video-ati"
    if [ ${DISTRIB_RELEASE//[^[:digit:]]} -ge 1404 ]; then
        showinfo "installing mesa VDPAU packages..."
        sudo apt-get install -y mesa-vdpau-drivers vdpauinfo
        showinfo "Radeon OSS VDPAU install completed"
    else
        showInfo "Adding Wsnsprix MESA PPA..."
        IS_ADDED=$(addRepository "$MESA_PPA")
        sudo apt-get update
        sudo apt-get dist-upgrade
        showinfo "installing required mesa patches..."
        sudo apt-get install -y libg3dvl-mesa vdpauinfo linux-firmware
        showinfo "Mesa patches installation complete"
        mkdir -p ~/kernel
        cd ~/kernel
        showinfo "Downloading and installing 3.13 kernel (may take awhile)..."
        wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v3.13.5-trusty/linux-headers-3.13.5-031305-generic_3.13.5-031305.201402221823_amd64.deb http://kernel.ubuntu.com/~kernel-ppa/mainline/v3.13.5-trusty/linux-headers-3.13.5-031305_3.13.5-031305.201402221823_all.deb http://kernel.ubuntu.com/~kernel-ppa/mainline/v3.13.5-trusty/linux-image-3.13.5-031305-generic_3.13.5-031305.201402221823_amd64.deb
        sudo dpkg -i *3.13.5*deb
        sudo rm -rf ~/kernel
        showinfo "kernel Installation Complete, Radeon OSS VDPAU install completed"
    fi
}

function disableAtiUnderscan() {
	sudo kill $(pidof X) > /dev/null 2>&1
	sudo aticonfig --set-pcs-val=MCIL,DigitalHDTVDefaultUnderscan,0 > /dev/null 2>&1
    showInfo "Underscan successfully disabled"
}

function enableAtiUnderscan() {
	sudo kill $(pidof X) > /dev/null 2>&1
	sudo aticonfig --set-pcs-val=MCIL,DigitalHDTVDefaultUnderscan,1 > /dev/null 2>&1
    showInfo "Underscan successfully enabled"
}

function addXswatPpa() {
    showInfo "Adding x-swat/x-updates ppa (“Ubuntu-X” team).."
	IS_ADDED=$(addRepository "$XSWAT_PPA")
}

function InstallLTSEnablementStack() {
     if [ "$DISTRIB_RELEASE" == "12.04" ]; then
         cmd=(dialog --title "LTS Enablement Stack (LTS Backports)" \
                     --backtitle "$SCRIPT_TITLE" \
             --radiolist "Enable Ubuntu's LTS Enablement stack to update to 12.04.3. The updates include the 3.8 kernel as well as a lot of updates to Xorg. On a non-minimal install these would be selected by default. Do you have to install/enable this?" 
             15 ${DIALOG_WIDTH} 6)
        
        options=(1 "No - keep 3.2.xx kernel (default)" on
                 2 "Yes - Install (recomended)" off)
         
        choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

         case ${choice//\"/} in
             1)
                     #do nothing
                 ;;
             2)
                     LTSEnablementStack
                 ;;
             *)
                     InstallLTSEnablementStack
                 ;;
         esac
     fi
}

function LTSEnablementStack() {
showInfo "Installing Ubuntu LTS Enablement Stack..."
sudo apt-get install --install-recommends -y linux-generic-lts-raring xserver-xorg-lts-raring libgl1-mesa-glx-lts-raring > /dev/null 2>&1
# HACK: dpkg is still processsing during next functions, allow some time to settle
sleep 2
showInfo "Ubuntu LTS Enablement Stack install completed..."
#sleep again to make sure dpkg is freed for next function
sleep 3
}

function selectNvidiaDriver() {
    cmd=(dialog --title "Choose which nvidia driver version to install (required)" \
                --backtitle "$SCRIPT_TITLE" \
        --radiolist "Some driver versions play nicely with different cards, Please choose one!" 
        15 ${DIALOG_WIDTH} 6)
        
   options=(1 "304.88 - ubuntu LTS default (default)" on
            2 "319.xx - Shipped with OpenELEC" off
            3 "331.xx - latest (will install additional x-swat ppa)" off)
         
    choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

    case ${choice//\"/} in
        1)
                VIDEO_DRIVER="nvidia-current"
            ;;
        2)
                VIDEO_DRIVER="nvidia-319-updates"
            ;;
        3)
                addXswatPpa
                VIDEO_DRIVER="nvidia-331"
            ;;
        *)
                selectNvidiaDriver
            ;;
    esac
}

function installVideoDriver() {
    if [[ ${GFX_CARD} == NVIDIA ]]; then
        selectNvidiaDriver
    elif [[ ${GFX_CARD} == ATI ]] || [[ ${GFX_CARD} == AMD ]] || [[ ${GFX_CARD} == ADVANCED ]]; then
        if [ ${DISTRIB_RELEASE//[^[:digit:]]} -ge 1310 ]; then
            ChooseATIDriver
            else
            VIDEO_DRIVER="fglrx"
            fi
    elif [[ ${GFX_CARD} == INTEL ]]; then
        VIDEO_DRIVER="i965-va-driver"
    elif [[ ${GFX_CARD} == VMWARE ]]; then
        VIDEO_DRIVER="i965-va-driver"
    else
        cleanUp
        clear
        echo ""
        echo "$(tput setaf 1)$(tput bold)Installation aborted...$(tput sgr0)" 
        echo "$(tput setaf 1)Only NVIDIA, ATI/AMD or INTEL videocards are supported. Please install a compatible videocard and run the script again.$(tput sgr0)"
        echo ""
        echo "$(tput setaf 1)You have a $GFX_CARD videocard.$(tput sgr0)"
        echo ""
        exit
    fi

    showInfo "Installing $GFX_CARD video drivers (may take a while)..."
    IS_INSTALLED=$(aptInstall ${VIDEO_DRIVER})

    if [ "IS_INSTALLED=$(isPackageInstalled ${VIDEO_DRIVER}) == 1" ]; then
        if [ "$GFX_CARD" == "ATI" ] || [ "$GFX_CARD" == "AMD" ] || [ "$GFX_CARD" == "ADVANCED" ]; then
            configureAtiDriver

            dialog --title "Disable underscan" \
                --backtitle "$SCRIPT_TITLE" \
                --yesno "Do you want to disable underscan (removes black borders)? Do this only if you're sure you need it!" 7 ${DIALOG_WIDTH}

            RESPONSE=$?
            case ${RESPONSE//\"/} in
                0) 
                    disableAtiUnderscan
                    ;;
                1) 
                    enableAtiUnderscan
                    ;;
                255) 
                    showInfo "ATI underscan configuration skipped"
                    ;;
            esac
        fi
        
        showInfo "$GFX_CARD video drivers successfully installed and configured"
    fi
}

function installAutomaticDistUpgrade() {
    showInfo "Enabling automatic system upgrade..."
	createDirectory "$TEMP_DIRECTORY" 1 0
	download ${DOWNLOAD_URL}"dist_upgrade.sh"
	IS_MOVED=$(move ${TEMP_DIRECTORY}"dist_upgrade.sh" "$DIST_UPGRADE_FILE" 1)
	
	if [ "$IS_MOVED" == "1" ]; then
	    IS_INSTALLED=$(aptInstall cron)
	    sudo chmod +x "$DIST_UPGRADE_FILE" > /dev/null 2>&1
	    handleFileBackup "$CRONTAB_FILE" 1
	    appendToFile "$CRONTAB_FILE" "0 */4  * * * root  $DIST_UPGRADE_FILE >> $DIST_UPGRADE_LOG_FILE"
	else
	    showError "Automatic system upgrade interval could not be enabled"
	fi
}

function removeAutorunFiles()
{
    if [ -e "$KODI_INIT_FILE" ]; then
        showInfo "Removing existing autorun script..."
        sudo update-rc.d kodi remove > /dev/null 2>&1
        sudo rm "$KODI_INIT_FILE" > /dev/null 2>&1

        if [ -e "$KODI_INIT_CONF_FILE" ]; then
		    sudo rm "$KODI_INIT_CONF_FILE" > /dev/null 2>&1
	    fi
	    
	    if [ -e "$KODI_CUSTOM_EXEC" ]; then
	        sudo rm "$KODI_CUSTOM_EXEC" > /dev/null 2>&1
	    fi
	    
	    if [ -e "$KODI_XSESSION_FILE" ]; then
	        sudo rm "$KODI_XSESSION_FILE" > /dev/null 2>&1
	    fi

	    if [ -e "$DELUGED_INIT_CONF_FILE" ]; then
	        sudo rm "$DELUGED_INIT_CONF_FILE" > /dev/null 2>&1
	    fi

	    if [ -e "$DELUGEWEB_INIT_CONF_FILE" ]; then
	        sudo rm "$DELUGEWEB_INIT_CONF_FILE" > /dev/null 2>&1
	    fi
	    
	    showInfo "Old autorun script successfully removed"
    fi
}

function installKodiUpstartScript() {
    removeAutorunFiles
    showInfo "Installing KODI upstart autorun support..."
    createDirectory "$TEMP_DIRECTORY" 1 0
	download ${DOWNLOAD_URL}"kodi_upstart_script_2"

	if [ -e ${TEMP_DIRECTORY}"kodi_upstart_script_2" ]; then
	    IS_MOVED=$(move ${TEMP_DIRECTORY}"kodi_upstart_script_2" "$KODI_INIT_CONF_FILE")

	    if [ "$IS_MOVED" == "1" ]; then
	        sudo ln -s "$UPSTART_JOB_FILE" "$KODI_INIT_FILE" > /dev/null 2>&1
	    else
	        showError "KODI upstart configuration failed"
	    fi
	else
	    showError "Download of KODI upstart configuration file failed"
	fi
}

function installNyxBoardKeymap() {
    showInfo "Applying Pulse-Eight Motorola NYXboard advanced keymap..."
	createDirectory "$TEMP_DIRECTORY" 1 0
	download ${DOWNLOAD_URL}"nyxboard.tar.gz"
    createDirectory "$KODI_KEYMAPS_DIR" 0 0

    if [ -e ${KODI_KEYMAPS_DIR}"keyboard.xml" ]; then
        handleFileBackup ${KODI_KEYMAPS_DIR}"keyboard.xml" 0 1
    fi

    if [ -e ${TEMP_DIRECTORY}"nyxboard.tar.gz" ]; then
        tar -xvzf ${TEMP_DIRECTORY}"nyxboard.tar.gz" -C "$KODI_KEYMAPS_DIR" > /dev/null 2>&1
        
        if [ "$?" == "0" ]; then
	        showInfo "Pulse-Eight Motorola NYXboard advanced keymap successfully applied"
	    else
	        showError "Pulse-Eight Motorola NYXboard advanced keymap could not be applied (error code: $?)"
	    fi
    else
	    showError "Pulse-Eight Motorola NYXboard advanced keymap could not be downloaded"
    fi
}

function installKodiBootScreen() {
    showInfo "Installing KODI boot screen (please be patient)..."
    sudo apt-get install -y plymouth-label v86d > /dev/null
    createDirectory "$TEMP_DIRECTORY" 1 0
    download ${DOWNLOAD_URL}"plymouth-theme-kodi-logo.deb"
    
    if [ -e ${TEMP_DIRECTORY}"plymouth-theme-kodi-logo.deb" ]; then
        sudo dpkg -i ${TEMP_DIRECTORY}"plymouth-theme-kodi-logo.deb" > /dev/null 2>&1
        update-alternatives --install /lib/plymouth/themes/default.plymouth default.plymouth /lib/plymouth/themes/kodi-logo/kodi-logo.plymouth 100 > /dev/null 2>&1
        handleFileBackup "$INITRAMFS_SPLASH_FILE" 1 1
        createFile "$INITRAMFS_SPLASH_FILE" 1 1
        appendToFile "$INITRAMFS_SPLASH_FILE" "FRAMEBUFFER=y"
        showInfo "KODI boot screen successfully installed"
    else
        showError "Download of KODI boot screen package failed"
    fi
}

function applyScreenResolution() {
    RESOLUTION="$1"
    
    showInfo "Applying bootscreen resolution (will take a minute or so)..."
    handleFileBackup "$GRUB_HEADER_FILE" 1 0
    sudo sed -i '/gfxmode=/ a\  set gfxpayload=keep' "$GRUB_HEADER_FILE" > /dev/null 2>&1
    GRUB_CONFIG="nomodeset usbcore.autosuspend=-1 video=uvesafb:mode_option=$RESOLUTION-24,mtrr=3,scroll=ywrap"
    
    if [[ ${GFX_CARD} == INTEL ]]; then
        GRUB_CONFIG="usbcore.autosuspend=-1 video=uvesafb:mode_option=$RESOLUTION-24,mtrr=3,scroll=ywrap"
    fi
    if [[ ${RADEON_OSS} == 1 ]]; then
        GRUB_CONFIG="usbcore.autosuspend=-1 video=uvesafb:mode_option=$RESOLUTION-24,mtrr=3,scroll=ywrap radeon.audio=1 radeon.dpm=1 quiet splash"
    fi
    
    handleFileBackup "$GRUB_CONFIG_FILE" 1 0
    appendToFile "$GRUB_CONFIG_FILE" "GRUB_CMDLINE_LINUX=\"$GRUB_CONFIG\""
    appendToFile "$GRUB_CONFIG_FILE" "GRUB_GFXMODE=$RESOLUTION"
    appendToFile "$GRUB_CONFIG_FILE" "GRUB_RECORDFAIL_TIMEOUT=0"
    
    handleFileBackup "$INITRAMFS_MODULES_FILE" 1 0
    appendToFile "$INITRAMFS_MODULES_FILE" "uvesafb mode_option=$RESOLUTION-24 mtrr=3 scroll=ywrap"
    
    sudo update-grub > /dev/null 2>&1
    sudo update-initramfs -u > /dev/null
    
    if [ "$?" == "0" ]; then
        showInfo "Bootscreen resolution successfully applied"
    else
        showError "Bootscreen resolution could not be applied"
    fi
}

function installLmSensors() {
    showInfo "Installing temperature monitoring package (will apply all defaults)..."
    aptInstall lm-sensors
    sudo yes "" | sensors-detect > /dev/null 2>&1

    if [ ! -e "$KODI_ADVANCEDSETTINGS_FILE" ]; then
	    createDirectory "$TEMP_DIRECTORY" 1 0
	    download ${DOWNLOAD_URL}"temperature_monitoring.xml"
	    createDirectory "$KODI_USERDATA_DIR" 0 0
	    IS_MOVED=$(move ${TEMP_DIRECTORY}"temperature_monitoring.xml" "$KODI_ADVANCEDSETTINGS_FILE")

	    if [ "$IS_MOVED" == "1" ]; then
            showInfo "Temperature monitoring successfully enabled in KODI"
        else
            showError "Temperature monitoring could not be enabled in KODI"
        fi
    fi
    
    showInfo "Temperature monitoring successfully configured"
}

function reconfigureXServer() {
    showInfo "Configuring X-server..."
    handleFileBackup "$XWRAPPER_FILE" 1
    createFile "$XWRAPPER_FILE" 1 1
	appendToFile "$XWRAPPER_FILE" "allowed_users=anybody"
	showInfo "X-server successfully configured"
}

function selectKodiTweaks() {
    cmd=(dialog --title "Optional KODI tweaks and additions" 
        --backtitle "$SCRIPT_TITLE" 
        --checklist "Plese select to install or apply:" 
        15 ${DIALOG_WIDTH} 6)
        
   options=(1 "Enable temperature monitoring (confirm with ENTER)" on
            2 "Install Addon Repositories Installer addon" off
            3 "Apply improved Pulse-Eight Motorola NYXboard keymap" off)
            
    choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

    for choice in ${choices}
    do
        case ${choice//\"/} in
            1)
                installLmSensors
                ;;
            2)
                installKodiAddonRepositoriesInstaller 
                ;;
            3)
                installNyxBoardKeymap 
                ;;
        esac
    done
}

function selectScreenResolution() {
    cmd=(dialog --backtitle "Select bootscreen resolution (required)"
        --radiolist "Please select your screen resolution, or the one sligtly lower then it can handle if an exact match isn't availabel:" 
        15 ${DIALOG_WIDTH} 6)
        
    options=(1 "720 x 480 (NTSC)" off
            2 "720 x 576 (PAL)" off
            3 "1280 x 720 (HD Ready)" on
            4 "1366 x 768 (HD Ready)" off
            5 "1920 x 1080 (Full HD)" off)
         
    choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

    case ${choice//\"/} in
        1)
            applyScreenResolution "720x480"
            ;;
        2)
            applyScreenResolution "720x576"
            ;;
        3)
            applyScreenResolution "1280x720"
            ;;
        4)
            applyScreenResolution "1366x768"
            ;;
        5)
            applyScreenResolution "1920x1080"
            ;;
        *)
            selectScreenResolution
            ;;
    esac
}

function selectAdditionalPackages() {
    cmd=(dialog --title "Other optional packages and features" 
        --backtitle "$SCRIPT_TITLE" 
        --checklist "Plese select to install:" 
        15 ${DIALOG_WIDTH} 6)
        
    options=(1 "Lirc (IR remote support)" off
            2 "Hts tvheadend (live TV backend)" off
            3 "Oscam (live HDTV decryption tool)" off
            4 "Automatic upgrades (every 4 hours)" off
            5 "OS-based NFS Support (nfs-common)" off)
            
    choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

    for choice in ${choices}
    do
        case ${choice//\"/} in
            1)
                installLirc
                ;;
            2)
                installTvHeadend 
                ;;
            3)
                installOscam 
                ;;
            4)
                installAutomaticDistUpgrade
                ;;
            5)
                Installnfscommon
                ;;
        esac
    done
}

function optimizeInstallation() {
    showInfo "Optimizing installation..."

    sudo echo "none /tmp tmpfs defaults 0 0" >> /etc/fstab

    sudo service apparmor stop > /dev/null 2>&1
    sleep 2
    sudo service apparmor teardown > /dev/null 2>&1
    sleep 2
    sudo update-rc.d -f apparmor remove > /dev/null 2>&1
    sleep 2
    sudo apt-get purge apparmor -y > /dev/null 2>&1
    sleep 3
    
    createDirectory "$TEMP_DIRECTORY" 1 0
	handleFileBackup ${RSYSLOG_FILE} 0 1
	download ${DOWNLOAD_URL}"rsyslog.conf"
	move ${TEMP_DIRECTORY}"rsyslog.conf" "$RSYSLOG_FILE" 1
    
    handleFileBackup "$SYSCTL_CONF_FILE" 1 0
    createFile "$SYSCTL_CONF_FILE" 1 0
    appendToFile "$SYSCTL_CONF_FILE" "dev.cdrom.lock=0"
    appendToFile "$SYSCTL_CONF_FILE" "vm.swappiness=10"
}

function cleanUp() {
    showInfo "Cleaning up..."
	sudo apt-get -y autoremove > /dev/null 2>&1
        sleep 1
	sudo apt-get -y autoclean > /dev/null 2>&1
        sleep 1
	sudo apt-get -y clean > /dev/null 2>&1
        sleep 1
        sudo chown -R ${UNAME}:${UNAME} /home/${UNAME}/.kodi > /dev/null 2>&1
        showInfo "fixed permissions for kodi userdata folder"
	
	if [ -e "$TEMP_DIRECTORY" ]; then
	    sudo rm -R "$TEMP_DIRECTORY" > /dev/null 2>&1
	fi
}

function rebootMachine() {
    showInfo "Reboot system..."
	dialog --title "Installation complete" \
		--backtitle "$SCRIPT_TITLE" \
		--yesno "Do you want to reboot now?" 7 ${DIALOG_WIDTH}

	case $? in
        0)
            showInfo "Installation complete. Rebooting..."
            clear
            echo ""
            echo "Installation complete. Rebooting..."
            echo ""
            sudo reboot > /dev/null 2>&1
	        ;;
	    1) 
	        showInfo "Installation complete. Not rebooting."
            quit
	        ;;
	    255) 
	        showInfo "Installation complete. Not rebooting."
	        quit
	        ;;
	esac
}

function quit() {
	clear
	exit
}

control_c() {
    cleanUp
    echo "Installation aborted..."
    quit
}

function installNginx () {
    dialog --title "Nginx" --infobox "Installing Nginx" 6 50
    apt-get install nginx apache2-utils -y >> ${LOGFILE}
    openssl req -x509 -nodes -days 7200 -newkey rsa:2048 -subj "/C=US/ST=NONE/L=NONE/O=Private/CN=Private" -keyout /etc/ssl/private/nginx.key -out /etc/ssl/certs/nginx.crt > /dev/null 2>&1

cat << EOF > /etc/nginx/proxy.conf
proxy_connect_timeout       59s;
proxy_send_timeout          600;
proxy_read_timeout          36000s;
proxy_buffer_size           64k;
proxy_buffers               16 32k;
proxy_pass_header           Set-Cookie;
proxy_hide_header           Vary;
proxy_busy_buffers_size     64k;
proxy_temp_file_write_size  64k;
proxy_set_header            Accept-Encoding      '';
proxy_ignore_headers        Cache-Control        Expires;
proxy_set_header            Referer              \$http_referer;
proxy_set_header            Host                 \$host;
proxy_set_header            Cookie               \$http_cookie;
proxy_set_header            X-Real-IP            \$remote_addr;
proxy_set_header            X-Forwarded-Host     \$host;
proxy_set_header            X-Forwarded-Server   \$host;
proxy_set_header            X-Forwarded-For      \$proxy_add_x_forwarded_for;
proxy_set_header            X-Forwarded-Port     '443';
proxy_set_header            X-Forwarded-Ssl      on;
proxy_set_header            X-Forwarded-Proto    https;
proxy_set_header            Authorization        '';
proxy_buffering             off;
proxy_redirect              off;
proxy_http_version          1.1;
proxy_set_header            Upgrade             \$http_upgrade;
proxy_set_header            Connection          "upgrade";
EOF

cat << EOF > /etc/nginx/auth.conf
satisfy any;
allow 127.0.0.1;
auth_basic "Restricted";
auth_basic_user_file /etc/nginx/htpasswd;
EOF

cat << EOF > /etc/nginx/sites-available/reverse
server {
    listen 443;
    server_name _;

    access_log  /var/log/nginx/access.log;
    error_log  /var/log/nginx/error.log;

    ssl_certificate           /etc/ssl/certs/nginx.crt;
    ssl_certificate_key       /etc/ssl/private/nginx.key;

    ssl on;
    ssl_session_cache  builtin:1000  shared:SSL:10m;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS;
    ssl_prefer_server_ciphers on;

    location /sabnzbd {
		proxy_pass http://127.0.0.1:8080;
		include /etc/nginx/proxy.conf;
        include /etc/nginx/auth.conf;
	}

    location /sonarr {
		proxy_pass http://127.0.0.1:8989;
		include /etc/nginx/proxy.conf;
        include /etc/nginx/auth.conf;
	}

    location /couchpotato {
		proxy_pass http://127.0.0.1:5050;
	    include /etc/nginx/proxy.conf;
        include /etc/nginx/auth.conf;
	}

    location /deluge {
        proxy_pass http://127.0.0.1:8086/;
        proxy_set_header  X-Deluge-Base "/deluge/";
        include /etc/nginx/proxy.conf;
        include /etc/nginx/auth.conf;
    }

    location /sickrage {
        proxy_pass http://127.0.0.1:8081;
        include /etc/nginx/proxy.conf;
        include /etc/nginx/auth.conf;
    }

    location /kodi {
        proxy_pass http://127.0.0.1:8080;
        include /etc/nginx/proxy.conf;
        include /etc/nginx/auth.conf;
    }
}
EOF

    htpasswd -b -c /etc/nginx/htpasswd ${UNAME} ${PASSWORD}

    unlink /etc/nginx/sites-enabled/default > /dev/null 2>&1
    ln -s /etc/nginx/sites-available/reverse /etc/nginx/sites-enabled/reverse > /dev/null 2>&1
    service nginx restart > /dev/null 2>&1

}

function installApache () {
    dialog --title "Apache" --infobox "Installing Apache" 6 50
    apt-get -y install apache2 > /dev/null 2>&1

    a2enmod proxy > /dev/null 2>&1
    a2enmod proxy_http > /dev/null 2>&1
    a2enmod rewrite > /dev/null 2>&1
    a2enmod ssl > /dev/null 2>&1
    a2enmod headers > /dev/null 2>&1
    openssl req -x509 -nodes -days 7200 -newkey rsa:2048 -subj "/C=US/ST=NONE/L=NONE/O=Private/CN=Private" -keyout /etc/ssl/private/apache.key -out /etc/ssl/certs/apache.crt > /dev/null 2>&1

cat << EOF > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
RewriteEngine on
ReWriteCond %{SERVER_PORT} !^443$
RewriteRule ^/(.*) https://%{HTTP_HOST}/\$1 [NC,R,L]
</VirtualHost>

<VirtualHost *:443>
ServerAdmin admin@domain.com
ServerName localhost

ProxyRequests Off
ProxyPreserveHost On

<Proxy *>
Order deny,allow
Allow from all
</Proxy>

<Location />
Order allow,deny
allow from all
</Location>

SSLEngine On
SSLProxyEngine On
SSLCertificateFile /etc/ssl/certs/apache.crt
SSLCertificateKeyFile /etc/ssl/private/apache.key

### SABNzbd ###
<Location /sabnzbd>
    ProxyPass http://localhost:8085/sabnzbd
    ProxyPassReverse http://localhost:8085/sabnzbd
</Location>

### Sonarr ###
<Location /sonarr>
    ProxyPass http://localhost:8989/sonarr
    ProxyPassReverse http://localhost:8989/sonarr
</Location>

### Couchpotato ###
<Location /couchpotato>
    ProxyPass http://localhost:5050/couchpotato
    ProxyPassReverse http://localhost:5050/couchpotato
</Location>

### Deluge ###
<Location /deluge/>
    ProxyPass http://127.0.0.1:8112/
    ProxyPassReverse http://127.0.0.1:8112/
    ProxyPassReverseCookieDomain 127.0.0.1 localhost
    ProxyPassReverseCookiePath / /deluge/
    RequestHeader append X-Deluge-Base "/deluge/"
</Location>

### SickRage ###
<Location /sickrage>
    ProxyPass http://localhost:8081/sickrage
    ProxyPassReverse http://localhost:8081/sickrage
</Location>

### Kodi ###
RewriteEngine on
RewriteRule ^/kodi$ /kodi/ [R]

<Location /kodi>
    ProxyPass http://localhost:8080
    ProxyPassReverse http://localhost:8080
</Location>

ErrorLog /var/log/apache2/error.log
LogLevel warn
</VirtualHost>
EOF
    service apache2 restart >> ${LOGFILE}
}

function installCouchpotato () {
    dialog --title "Couchpotato" --infobox "Installing Git and Python" 6 50
    apt-get -y install git-core python >> ${LOGFILE}

    dialog --title "Couchpotato" --infobox "Killing and version of couchpotato currently running" 6 50
    killall couchpotato* >> ${LOGFILE}

    dialog --title "Couchpotato" --infobox "Downloading the latest version of CouchPotato" 6 50
        git clone git://github.com/RuudBurger/CouchPotatoServer.git /home/${UNAME}/.couchpotato > /dev/null 2>&1

    sudo chown -R ${UNAME}: /home/${UNAME}/.couchpotato
    sudo chmod -R 755 /home/${UNAME}/.couchpotato

    dialog --title "Couchpotato" --infobox "Installing upstart configurations" 6 50
    sleep 2

cat > /etc/init/couchpotato.conf << EOF
description "Upstart Script to run couchpotato as a service on Ubuntu/Debian based systems"

setuid ${UNAME}
setgid ${UNAME}

start on runlevel [2345]
stop on runlevel [016]

respawn
respawn limit 10 10

exec python /home/${UNAME}/.couchpotato/CouchPotato.py
EOF

    dialog --title "Couchpotato" --infobox "Starting CouchPotato for the first time" 6 50
    sudo service couchpotato start

    while [ ! -f /home/${UNAME}/.couchpotato/settings.conf ]; do
        sleep 5
        sudo service couchpotato restart
    done

    PASSWORDHASH=$(printf '%s' ${PASSWORD} | md5sum | cut -d ' ' -f 1)

    sudo service couchpotato stop
    sudo sed -i "/\[core\]/,/^\$/s/api_key =/api_key = $API/g" /home/${UNAME}/.couchpotato/settings.conf
    sudo sed -i "/\[core\]/,/^\$/s/username =/username = $USERNAME/g" /home/${UNAME}/.couchpotato/settings.conf
    sudo sed -i "/\[core\]/,/^\$/s/permission_file = 0644/permission_file = 0755/g" /home/${UNAME}/.couchpotato/settings.conf
    sudo sed -i "/\[core\]/,/^\$/s/launch_browser = True/launch_browser = False/g" /home/${UNAME}/.couchpotato/settings.conf
    sudo sed -i "/\[core\]/,/^\$/s/password =/password = $PASSWORDHASH" /home/${UNAME}/.couchpotato/settings.conf
    sudo sed -i "/\[core\]/,/^\$/s/url_base =/url_base = couchpotato/g" /home/${UNAME}/.couchpotato/settings.conf
    sudo sed -i "/\[core\]/,/^\$/s/show_wizard = 1/show_wizard = 0/g" /home/${UNAME}/.couchpotato/settings.conf
    sudo sed -i "/\[updater\]/,/^$/s/enabled = False/enabled = True/g" /home/${UNAME}/.couchpotato/settings.conf
    sudo sed -i "/\[manage\]/,/^\$/s/enabled = False/enabled = True/g" /home/${UNAME}/.couchpotato/settings.conf
    sudo sed -i "/\[manage\]/,/^\$/s/library =/library = \\$MOVIEDIR\/Movies\//g" /home/${UNAME}/.couchpotato/settings.conf
    sudo sed -i "/\[renamer\]/,/^\$/s/from =/from = \\$DOWNLOADDIR\/Downloads\/Complete\//g" /home/${UNAME}/.couchpotato/settings.conf
    sudo sed -i "/\[renamer\]/,/^\$/s/to =/to = \\$MOVIEDIR\/Movies\//g" /home/${UNAME}/.couchpotato/settings.conf
    sudo sed -i "/\[renamer\]/,/^\$/s/unrar_modify_date = False/unrar_modify_date = True/g" /home/${UNAME}/.couchpotato/settings.conf
    sudo sed -i "/\[renamer\]/,/^\$/s/file_action = link/file_action = move/g" /home/${UNAME}/.couchpotato/settings.conf
    sudo sed -i "/\[renamer\]/,/^\$/s/enabled = False/enabled = True/g" /home/${UNAME}/.couchpotato/settings.conf
    sudo sed -i "/\[renamer\]/,/^\$/s/unrar = False/unrar = True/g" /home/${UNAME}/.couchpotato/settings.conf
    sudo sed -i "/\[renamer\]/,/^\$/s/force_every = 2/force_every = 1/g" /home/${UNAME}/.couchpotato/settings.conf
    sudo sed -i "/\[subtitle\]/,/^\$/s/languages =/languages = en/g" /home/${UNAME}/.couchpotato/settings.conf
    sudo sed -i "/\[subtitle\]/,/^\$/s/enabled = False/enabled = True/g" /home/${UNAME}/.couchpotato/settings.conf
    sudo sed -i "/\[blackhole\]/,/^\$s/directory = \/home\/$UNAME/directory = \\${DOWNLOADDIR}\/Downloads\/Torrents/\/g" /home/${UNAME}/.couchpotato/settings.conf
    if [[ ${APPS} == *Deluge* ]]; then
        sudo sed -i "/\[deluge\]/,/^\$/s/username =/username = $USERNAME/g" /home/${UNAME}/.couchpotato/settings.conf
        sudo sed -i "/\[deluge\]/,/^\$/s/enabled = False/enabled = True/g" /home/${UNAME}/.couchpotato/settings.conf
    fi
    if [[ ${APPS} == *SABnzbd* ]]; then
        sudo sed -i "/\[sabnzbd\]/,/^\$/s/category =/category = Movies/g" /home/${UNAME}/.couchpotato/settings.conf
        sudo sed -i "/\[sabnzbd\]/,/^\$/s/enabled = False/enabled = True/g" /home/${UNAME}/.couchpotato/settings.conf
        sudo sed -i "/\[sabnzbd\]/,/^\$/s/api_key =/api_key = $API/g" /home/${UNAME}/.couchpotato/settings.conf
    fi
    if [[ ${APPS} == *Transmission* ]]; then
        sudo sed -i "/\[transmission\]/,/^\$/s/username =/username = admin/g" /home/${UNAME}/.couchpotato/settings.conf
        sudo sed -i "/\[transmission\]/,/^\$/s/stalled_as_failed = True/stalled_as_failed = False/g" /home/${UNAME}/.couchpotato/settings.conf
        sudo sed -i "/\[transmission\]/,/^\$/s/enabled = False/enabled = True/g" /home/${UNAME}/.couchpotato/settings.conf
        sudo sed -i "/\[transmission\]/,/^\$/s/directory =/directory = \\$MOVIEDIR\/Movies\//g" /home/${UNAME}/.couchpotato/settings.conf
        sudo sed -i "/\[transmission\]/,/^\$/s/password =/password = $PASSWORD" /home/${UNAME}/.couchpotato/settings.conf
    fi
    if [[ ${APPS} == *Kodi* ]]; then
        sudo sed -i "0,/[xbmc]/s/[xbmc]/[$UNAME]/g" /home/${UNAME}/.couchpotato/settings.conf
        sudo sed -i "/\[$UNAME\]/,/^\$/s/username = xbmc/username = $USERNAME/g" /home/${UNAME}/.couchpotato/settings.conf
        sudo sed -i "/\[$UNAME\]/,/^\$/s/enabled = False/enabled = True/g" /home/${UNAME}/.couchpotato/settings.conf
        sudo sed -i "/\[$UNAME\]/,/^\$/s/directory =/directory = \\$MOVIEDIR\/Movies\//g" /home/${UNAME}/.couchpotato/settings.conf
        sudo sed -i "/\[$UNAME\]/,/^\$/s/password =/password = $PASSWORDHASH" /home/${UNAME}/.couchpotato/settings.conf
    fi

    sudo service couchpotato start
    dialog --title "FINISHED" --infobox "Installation of Couchpotato is successful" 6 50
}

function installSABnzbd () {
    dialog --title "SABnzbd" --infobox "Adding SABnzbd repository" 6 50
    add-apt-repository -y ppa:jcfp/ppa >> ${LOGFILE}

    dialog --title "SABnzbd" --infobox "Updating Packages" 6 50
    apt-get -y update >> ${LOGFILE}

    dialog --title "SABnzbd" --infobox "Installing SABnzbd" 6 50
    apt-get -y install sabnzbdplus >> ${LOGFILE}

    dialog --title "SABnzbd" --infobox "Stopping SABnzbd" 6 50
    sleep 2

    service sabnzbd sabnzbdplus >> ${LOGFILE}
    killall *sabnzbd* >> ${LOGFILE}

    dialog --title "SABnzbd" --infobox "Removing Standard init scripts" 6 50
    update-rc.d -f sabnzbdplus remove  >> ${LOGFILE}

    dialog --title "SABnzbd" --infobox "Adding SABnzbd upstart config" 6 50
    sleep 2

cat > /etc/init/sabnzbd.conf << EOF
description "Upstart Script to run sabnzbd as a service on Ubuntu/Debian based systems"
setuid ${UNAME}
setgid ${UNAME}
start on runlevel [2345]
stop on runlevel [016]
respawn
respawn limit 10 10
exec sabnzbdplus -f /home/${UNAME}/.sabnzbd/config.ini -s 0.0.0.0:8085
EOF
    start sabnzbd >> ${LOGFILE}
    sleep 5
    stop sabnzbd >> ${LOGFILE}
    dialog --title "SABnzbd" --infobox "Configuring SABnzbd" 6 50
    echo "username = "${USERNAME} > /home/${UNAME}/.sabnzbd/config.ini
    echo "password = "${PASSWORD} >> /home/${UNAME}/.sabnzbd/config.ini
    echo "api_key = "${API} >> /home/${UNAME}/.sabnzbd/config.ini
    echo "complete_dir = "${DOWNLOADDIR}"/Downloads/Complete" >> /home/${UNAME}/.sabnzbd/config.ini
    echo "download_dir = "${DOWNLOADDIR}"/Downloads/Incomplete" >> /home/${UNAME}/.sabnzbd/config.ini
    echo "[servers]" >> /home/${UNAME}/.sabnzbd/config.ini
    echo "[["${USENETHOST}"]]" >> /home/${UNAME}/.sabnzbd/config.ini
    echo "username = "${USENETUSR} >> /home/${UNAME}/.sabnzbd/config.ini
    echo "enable = 1" >> /home/${UNAME}/.sabnzbd/config.ini
    echo "name = "${USENETHOST} >> /home/${UNAME}/.sabnzbd/config.ini
    echo "fillserver = 0" >> /home/${UNAME}/.sabnzbd/config.ini
    echo "connections = "${USENETCONN} >> /home/${UNAME}/.sabnzbd/config.ini
    echo "ssl = "${USENETSSL} >> /home/${UNAME}/.sabnzbd/config.ini
    echo "host = "${USENETHOST} >> /home/${UNAME}/.sabnzbd/config.ini
    echo "timeout = 120" >> /home/${UNAME}/.sabnzbd/config.ini
    echo "password = "${USENETPASS} >> /home/${UNAME}/.sabnzbd/config.ini
    echo "optional = 0" >> /home/${UNAME}/.sabnzbd/config.ini
    echo "port = "${USENETPORT} >> /home/${UNAME}/.sabnzbd/config.ini
    echo "retention = 0" >> /home/${UNAME}/.sabnzbd/config.ini
    echo "[categories]" >> /home/${UNAME}/.sabnzbd/config.ini
    echo "[[*]]" >> /home/${UNAME}/.sabnzbd/config.ini
    echo "priority = 0" >> /home/${UNAME}/.sabnzbd/config.ini
    echo "pp = 3" >> /home/${UNAME}/.sabnzbd/config.ini
    echo "name = *" >> /home/${UNAME}/.sabnzbd/config.ini
    echo "script = None" >> /home/${UNAME}/.sabnzbd/config.ini
    echo 'newzbin = ""' >> /home/${UNAME}/.sabnzbd/config.ini
    echo 'dir = ""' >> /home/${UNAME}/.sabnzbd/config.ini
    echo "[[tv]]" >> /home/${UNAME}/.sabnzbd/config.ini
    echo "priority = -100" >> /home/${UNAME}/.sabnzbd/config.ini
    echo 'pp = ""' >> /home/${UNAME}/.sabnzbd/config.ini
    echo "name = TV" >> /home/${UNAME}/.sabnzbd/config.ini
    echo "script = Default" >> /home/${UNAME}/.sabnzbd/config.ini
    echo 'newzbin = ""' >> /home/${UNAME}/.sabnzbd/config.ini
    echo "dir = "${DOWNLOADDIR}"/Downloads/Complete/TVShows" >> /home/${UNAME}/.sabnzbd/config.ini
    echo "[[movies]]" >> /home/${UNAME}/.sabnzbd/config.ini
    echo "priority = -100" >> /home/${UNAME}/.sabnzbd/config.ini
    echo 'pp = ""' >> /home/${UNAME}/.sabnzbd/config.ini
    echo "name = Movies" >> /home/${UNAME}/.sabnzbd/config.ini
    echo "script = Default" >> /home/${UNAME}/.sabnzbd/config.ini
    echo 'newzbin = ""' >> /home/${UNAME}/.sabnzbd/config.ini
    echo "dir = "${DOWNLOADDIR}"/Downloads/Complete" >> /home/${UNAME}/.sabnzbd/config.ini

    dialog --infobox "SABnzbd has finished installing. Continuing with next install." 6 50
}

function installSonarr () {
    dialog --title "SONARR" --infobox "Adding Sonarr repository" 6 50
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys FDA5DFFC >> ${LOGFILE}
    echo "deb http://update.nzbdrone.com/repos/apt/debian master main" | tee -a /etc/apt/sources.list >> ${LOGFILE}

    dialog --title "SONARR" --infobox "Updating Packages" 6 50
    apt-get -y update >> ${LOGFILE}

    dialog --title "SONARR" --infobox "Installing mono \ This may take awhile. Please be patient." 6 50
    apt-get -y install mono-complete  >> ${LOGFILE}

    dialog --title "SONARR" --infobox "Checking for previous versions of NZBget/Sonarr..." 6 50
    sleep 2
    killall sonarr* >> ${LOGFILE}
    killall nzbget* >> ${LOGFILE}

    dialog --title "SONARR" --infobox "Downloading latest Sonarr..." 6 50
    sleep 2
    apt-get -y install nzbdrone >> ${LOGFILE}

    dialog --title "SONARR" --infobox "Creating new default and init scripts..." 6 50
    sleep 2

cat > /etc/init/sonarr.conf << EOF
description "Upstart Script to run sonarr as a service on Ubuntu/Debian based systems"
setuid ${UNAME}
env DIR=/opt/NzbDrone
setgid nogroup
start on runlevel [2345]
stop on runlevel [016]
respawn
respawn limit 10 10
exec mono \$DIR/NzbDrone.exe
EOF
    start sonarr >> ${LOGFILE}

    while [ ! -f /home/${UNAME}/.config/NzbDrone/config.xml ]
    do
        sleep 2
    done

    while [ ! -f /home/${UNAME}/.config/NzbDrone/nzbdrone.db ]
    do
        sleep 2
    done

    stop sonarr >> ${LOGFILE}

    sqlite3 /home/${UNAME}/.config/NzbDrone/nzbdrone.db "UPDATE Config SET value = '"${UNAME}"' WHERE Key = 'chownuser'"
    sqlite3 /home/${UNAME}/.config/NzbDrone/nzbdrone.db "UPDATE Config SET value = '"${UNAME}"' WHERE Key = 'chowngroup'"
    sqlite3 /home/${UNAME}/.config/NzbDrone/nzbdrone.db "UPDATE Config SET value = '"${DOWNLOADDIR}"/Downloads/Complete/TVshow' WHERE Key = 'downloadedepisodesfolder'"
    sqlite3 /home/${UNAME}/.config/NzbDrone/nzbdrone.db "INSERT INTO DownloadClients VALUES (NULL,'1','Sabnzbd','Sabnzbd','{\"host\": \"localhost\", \"port\": 8085, \"apiKey\": \""${API}"\", \"username\": \""${USERNAME}"\", \"password\": \""${PASSWORD}"\", \"tvCategory\": \"tvshow\", \"recentTvPriority\": 1, \"olderTvPriority\": -100, \"useSsl\": false}', 'SabnzbdSettings')"
    sqlite3 /home/${UNAME}/.config/NzbDrone/nzbdrone.db "INSERT INTO Indexers VALUES (NULL,'"${INDEXNAME}"','Newznab,'{ \"url\": \""${INDEXHOST}"\", \"apiKey\": \""${INDEXAPI}"\, \"categories\": [   5030,   5040 ], \"animeCategories\": []  }','NewznabSettings','1','1')"
    sqlite3 /home/${UNAME}/.config/NzbDrone/nzbdrone.db "INSERT INTO RootFolders VALUES (NULL,'"${TVSHOWDIR}"/TVShows')"

    echo '<?xml version="1.0" encoding="utf-8" standalone="yes"?>' > /home/${UNAME}/.config/NzbDrone/config.xml
    echo "<Config>" >> /home/${UNAME}/.config/NzbDrone/config.xml
    echo "  <Port>8989</Port>" >> /home/${UNAME}/.config/NzbDrone/config.xml
    echo "  <SslPort>9898</SslPort>" >> /home/${UNAME}/.config/NzbDrone/config.xml
    echo "  <EnableSsl>False</EnableSsl>" >> /home/${UNAME}/.config/NzbDrone/config.xml
    echo "  <LaunchBrowser>False</LaunchBrowser>" >> /home/${UNAME}/.config/NzbDrone/config.xml
    echo "  <ApiKey>32cc1aa3d523445c8612bd5d130ba74a</ApiKey>" >> /home/${UNAME}/.config/NzbDrone/config.xml
    echo "  <AuthenticationEnabled>True</AuthenticationEnabled>" >> /home/${UNAME}/.config/NzbDrone/config.xml
    echo "  <Branch>torrents</Branch>" >> /home/${UNAME}/.config/NzbDrone/config.xml
    echo "  <Username>"${USERNAME}"</Username>" >> /home/${UNAME}/.config/NzbDrone/config.xml
    echo "  <Password>"${PASSWORD}"</Password>" >> /home/${UNAME}/.config/NzbDrone/config.xml
    echo "  <LogLevel>Trace</LogLevel>" >> /home/${UNAME}/.config/NzbDrone/config.xml
    echo "  <SslCertHash>" >> /home/${UNAME}/.config/NzbDrone/config.xml
    echo "  </SslCertHash>" >> /home/${UNAME}/.config/NzbDrone/config.xml
    echo "  <UrlBase>sonarr</UrlBase>" >> /home/${UNAME}/.config/NzbDrone/config.xml
    echo "  <UpdateMechanism>BuiltIn</UpdateMechanism>" >> /home/${UNAME}/.config/NzbDrone/config.xml
    echo "  <UpdateAutomatically>True</UpdateAutomatically>" >> /home/${UNAME}/.config/NzbDrone/config.xml
    echo "</Config>" >> /home/${UNAME}/.config/NzbDrone/config.xml

    dialog --title "FINISHED" --infobox "Sonarr has finished installing. Continuing with Next install." 6 50
}

function installDeluge () {
    dialog --title "Deluge" --infobox "Installing Deluge prerequisites" 6 50
    sudo adduser --disabled-password --system --home /var/lib/deluge --gecos "SamRo Deluge server" --group deluge > /dev/null 2>&1
    sudo touch /var/log/deluged.log > /dev/null 2>&1
    sudo touch /var/log/deluge-web.log > /dev/null 2>&1
    sudo chown deluge:deluge /var/log/deluge* > /dev/null 2>&1
    sudo adduser ${UNAME} deluge > /dev/null 2>&1

    dialog --title "Deluge" --infobox "Killing and versions of Deluge currently running" 6 50
    sleep 2
    killall deluge* >> ${LOGFILE}

    dialog --title "Deluge" --infobox "Downloading the latest version of Deluge" 6 50
    sleep 2
    sudo apt-get -y install deluged deluge-webui >> ${LOGFILE}

    dialog --title "Deluge" --infobox "Installing upstart configurations for Deluge" 6 50
    sleep 2

cat > /etc/init/deluge-web.conf << EOF
# deluge-web - Deluge Web UI
#
# The Web UI component of Deluge BitTorrent client, connects to deluged and
# provides a web application interface for users. Default url: http://localhost:8112

description "Deluge Web UI"
author "Deluge Team"

start on started deluged
stop on stopping deluged

respawn
respawn limit 5 30

env uid=deluge
env gid=deluge
env umask=027

exec start-stop-daemon -S -c \$uid:\$gid -k \$umask -x /usr/bin/deluge-web
EOF
cat > /etc/init/deluged.conf << EOF
# deluged - Deluge daemon
#
# The daemon component of Deluge BitTorrent client. Deluge UI clients
# connect to this daemon via DelugeRPC protocol.

description "Deluge daemon"
author "Deluge Team"

start on filesystem and static-network-up
stop on runlevel [016]

respawn
respawn limit 5 30

env uid=deluge
env gid=deluge
env umask=000

exec start-stop-daemon -S -c \$uid:\$gid -k \$umask -x /usr/bin/deluged -- -d
EOF
    dialog --title "FINISHED" --infobox "Installation of Deluge is successful" 6 50
}

function installSickRage () {
    dialog --title "SickRage" --infobox "Installing SickRage prerequisites" 6 50
    sudo apt-get -y install python-cheetah unrar python-pip python-dev libssl-dev git >> ${LOGFILE}
    sudo pip install pyopenssl==0.13.1 > /dev/null 2>&1

    dialog --title "SickRage" --infobox "Killing and versions of SickRage currently running" 6 50
    sleep 2
    killall sickrage* >> ${LOGFILE}

    dialog --title "SickRage" --infobox "Downloading the latest version of SickRage" 6 50
    sleep 2
    sudo git clone https://github.com/SickRage/SickRage.git /home/${UNAME}/.sickrage > /dev/null 2>&1

    dialog --title "SickRage" --infobox "Installing upstart configurations for SickRage" 6 50
    sleep 2

cat > /etc/init/sickrage.conf << EOF
description "Upstart Script to run SickRage as a service on Ubuntu/Debian based distros"
setuid ${UNAME}

start on runlevel [2345]
stop on runlevel [016]

respawn
respawn limit 5 30

exec /home/${UNAME}/.sickrage/SickBeard.py
EOF

    dialog --title "SickRage" --infobox "Writing config.ini for SickRage" 6 50
    sudo sed -i "/\[General\]/,/^\$/s/web_root = \"\"/web_root = \"/sickrage\"/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[General\]/,/^\$/s/web_username = \"\"/web_username = \"$UNAME\"/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[General\]/,/^\$/s/web_password = \"\"/web_password = \"$PASSWORD\"/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[General\]/,/^\$/s/quality_default = 3/quality_default = 22053375/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[General\]/,/^\$/s/auto_update = 0/auto_update = 1/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[General\]/,/^\$/s/launch_browser = 1/launch_browser = 0/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[General\]/,/^\$/s/root_dirs \"\"/root_dirs = \"0\|\\$TVSHOWDIR\"/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[General\]/,/^\$/s/tv_download_dir \"\"/tv_download_dir = \"\\$DOWNLOADDIR\/Download\/Complete\"/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[General\]/,/^\$/s/keep_processed_dir = 1/keep_processed_dir = 0/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[General\]/,/^\$/s/process_method = copy/process_method = move/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[General\]/,/^\$/s/del_rar_contents = 0/del_rar_contents = 1/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[General\]/,/^\$/s/move_associated_files = 0/move_associated_files = 1/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[General\]/,/^\$/s/process_automatically = 0/process_automatically = 1/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[General\]/,/^\$/s/unpack = 0/unpack = 1/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[General\]/,/^\$/s/create_missing_show_dirs = 0/create_missing_show_dirs = 1/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[Blackhole\]/,/^\$/s/torrent_dir = \"\"/torrent_dir = \"\\$DOWNLOADDIR\/Downloads\/torrents\"/g" /home/${UNAME}/.sickrage/config.ini
    if [[ ${APPS} == *Deluge* ]]; then
        sudo sed -i "/\[TORRENT\]/,/^\$/s/torrent_password = \"\"/torrent_password = \"$PASSWORD\"/g" /home/${UNAME}/.sickrage/config.ini
        sudo sed -i "/\[TORRENT\]/,/^\$/s/torrent_host = \"\"/torrent_host = http:\/\/localhost:8112\//g" /home/${UNAME}/.sickrage/config.ini
        sudo sed -i "/\[TORRENT\]/,/^\$/s/torrent_path = \"\"/torrent_path = \\$DOWNLOADDIR\/Downloads\/Complete/g" /home/${UNAME}/.sickrage/config.ini
        sudo sed -i "/\[TORRENT\]/,/^\$/s/torrent_label = \"\"/torrent_label = tvshow/g" /home/${UNAME}/.sickrage/config.ini
        sudo sed -i "/\[TORRENT\]/,/^\$/s/torrent_label_anime = \"\"/torrent_label_anime = animeshow/g" /home/${UNAME}/.sickrage/config.ini
    fi
    if [[ ${APPS} == *KODI* ]]; then
        sudo sed -i "/\[KODI\]/,/^\$/s/use_kodi = 0/use_kodi = 1/g" /home/${UNAME}/.sickrage/config.ini
        sudo sed -i "/\[KODI\]/,/^\$/s/kodi_notify_onsnatch = 0/kodi_notify_onsnatch = 1/g" /home/${UNAME}/.sickrage/config.ini
        sudo sed -i "/\[KODI\]/,/^\$/s/kodi_notify_ondownload = 0/kodi_notify_ondownload = 1/g" /home/${UNAME}/.sickrage/config.ini
        sudo sed -i "/\[KODI\]/,/^\$/s/kodi_update_library = 0/kodi_update_library = 1/g" /home/${UNAME}/.sickrage/config.ini
        sudo sed -i "/\[KODI\]/,/^\$/s/kodi_update_full = 0/kodi_update_full = 1/g" /home/${UNAME}/.sickrage/config.ini
        sudo sed -i "/\[KODI\]/,/^\$/s/kodi_host = \"\"/kodi_host = localhost:8080/g" /home/${UNAME}/.sickrage/config.ini
        sudo sed -i "/\[KODI\]/,/^\$/s/kodi_username = \"\"/kodi_username = $UNAME/g" /home/${UNAME}/.sickrage/config.ini
        sudo sed -i "/\[KODI\]/,/^\$/s/kodi_password = \"\"/kodi_password = $PASSWORD/g" /home/${UNAME}/.sickrage/config.ini
    fi
    sudo sed -i "/\[Subtitles\]/,/^\$/s/use_subtitles = 0/use_subtitles = 1/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[Subtitles\]/,/^\$/s/subtitles_languages = \"\"/subtitles_languages = \"dut,eng\"/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[Subtitles\]/,/^\$/s/SUBTITLES_SERVICES_LIST = \"\"/SUBTITLES_SERVICES_LIST = \"addic7ed,legendastv,napiprojekt,opensubtitles,podnapisi,thesubdb,tvsubtitles\"/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[Subtitles\]/,/^\$/s/SUBTITLES_SERVICES_ENABLED = \"\"/SUBTITLES_SERVICES_ENABLED = 0\|0\|1\|0\|1\|1\|1/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[Subtitles\]/,/^\$/s/subtitles_default = 0/subtitles_default = 1/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[FailedDownloads\]/,/^\$/s/use_failed_downloads = 0/use_failed_downloads = 1/g" /home/${UNAME}/.sickrage/config.ini
    sudo sed -i "/\[FailedDownloads\]/,/^\$/s/delete_failed = 0/delete_failed = 1/g" /home/${UNAME}/.sickrage/config.ini

    sudo chown -R ${UNAME}: /home/${UNAME}/.sickrage
    sudo chmod -R 755 /home/${UNAME}/.sickrage
    dialog --title "FINISHED" --infobox "Installation of SickRage is successful" 6 50
}

## ------- END functions -------
dialog --title "Automated Kodi Installation" --infobox "Setting things up" 6 50

sudo mkdir ${MOVIEDIR} > /dev/null 2>&1
sudo mkdir ${MOVIEDIR}/Movies > /dev/null 2>&1
sudo mkdir ${TVSHOWDIR} > /dev/null 2>&1
sudo mkdir ${TVSHOWDIR}/TVShows > /dev/null 2>&1
sudo mkdir ${DOWNLOADDIR} > /dev/null 2>&1
sudo mkdir ${DOWNLOADDIR}/Downloads > /dev/null 2>&1
sudo mkdir ${DOWNLOADDIR}/Downloads/Complete > /dev/null 2>&1
sudo mkdir ${DOWNLOADDIR}/Downloads/Incomplete > /dev/null 2>&1
sudo mkdir ${DOWNLOADDIR}/Downloads/Torrents > /dev/null 2>&1
sudo chown -R ${UNAME}:${UNAME} ${MOVIEDIR}/Movies > /dev/null 2>&1
sudo chown -R ${UNAME}:${UNAME} ${TVSHOWDIR}/TVShows > /dev/null 2>&1
sudo chown -R ${UNAME}:${UNAME} ${DOWNLOADDIR}/Downloads > /dev/null 2>&1
sudo chmod -R 775 ${MOVIEDIR}/Movies > /dev/null 2>&1
sudo chmod -R 775 ${TVSHOWDIR}/TVShows > /dev/null 2>&1
sudo chmod -R 775 ${DOWNLOADDIR}/Downloads > /dev/null 2>&1

update

if [[ ${APPS} == *SABnzbd* ]]; then
    installSABnzbd
fi

if [[ ${APPS} == *SickRage* ]]; then
    installSickRage
fi

if [[ ${APPS} == *Deluge* ]]; then
    installDeluge
fi

if [[ ${APPS} == *Sonarr* ]]; then
    installSonarr
fi

if [[ ${APPS} == *CouchPotato* ]]; then
    installCouchpotato
fi

if [[ ${APPS} == *KODI* ]]; then
    echo ""
    installDependencies
    echo "Loading installer..."
    showDialog "Welcome to the KODI minimal installation script. Some parts may take a while to install depending on your internet connection speed.\n\nPlease be patient..."
    trap control_c SIGINT

    fixLocaleBug
    fixUsbAutomount
    applyKodiNiceLevelPermissions
    addUserToRequiredGroups
    addKodiPpa
    distUpgrade
    #installVideoDriver
    installXinit
    installKodi
    installKodiUpstartScript
    installKodiBootScreen
    selectScreenResolution
    reconfigureXServer
    installPowerManagement
    installAudio
    selectKodiTweaks
    selectAdditionalPackages
    InstallLTSEnablementStack
    allowRemoteWakeup
    optimizeInstallation
    cleanUp
fi

if [[ ${APPS} == *ReverseProxy* ]]; then
    if [[ ${PROXY} == *Apache* ]]; then
        installApache
        IPADDR=$(/sbin/ifconfig eth0 | awk '/inet / { print $2 }' | sed 's/addr://')

        dialog --title "FINISHED" --msgbox "Apache rewrite installed. Use https://$IPADDR/sonarr to access sonarr, same for couchpotato and sabnzbd" 10 50
    fi

    if [[ ${PROXY} == *Nginx* ]]; then
        installNginx
        IPADDR=$(/sbin/ifconfig eth0 | awk '/inet / { print $2 }' | sed 's/addr://')

        dialog --title "FINISHED" --msgbox "Nginx rewrite installed. Use https://$IPADDR/sonarr to access sonarr, same for couchpotato and sabnzbd" 10 50
    fi
fi

dialog --title "FINISHED" --msgbox "All done. A restart will be triggered within 10-20 seconds" 10 50

sleep 10
rebootMachine