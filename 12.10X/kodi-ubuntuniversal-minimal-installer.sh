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

UNAME=$(dialog --title "System Username" --inputbox "Enter the user you want your scripts to run as. (Case sensitive, Suggested username is \"kodi\")" 10 50 3>&1 1>&2 2>&3)

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

GFX_CARD=$(lspci |grep VGA |awk -F: {' print $3 '} |awk {'print $1'} |tr [a-z] [A-Z])

KODI_PPA=$(dialog --radiolist "Choose which Kodi version you would like:" 20 50 3 \
1 "Official PPA - Install the release version." on \
2 "Unstable PPA - Install the Alpha/Beta/RC version." off 3>&1 1>&2 2>&3)

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
RewriteRule ^/(.*) https://%{HTTP_HOST}/$1 [NC,R,L]
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
Order deny,allow
deny from all
</Location>

SSLEngine On
SSLProxyEngine On
SSLCertificateFile /etc/ssl/certs/apache.crt
SSLCertificateKeyFile /etc/ssl/private/apache.key

RewriteEngine on
RewriteRule ^/kodi$ /kodi/ [R]

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
    RequestHeader append X-Deluge-Base "/deluge/"
    ProxyPass http://127.0.0.1:8112
    ProxyPassReverse http://127.0.0.1:8112
    ProxyPassReverseCookieDomain 127.0.0.1 localhost
    ProxyPassReverseCookiePath / /deluge/
</Location>

### SickRage ###
<Location /sickrage>
    ProxyPass http://localhost:8081/sickrage
    ProxyPassReverse http://localhost:8081/sickrage
</Location>

### Kodi ###
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
    dialog --title "COUCHPOTATO" --infobox "Installing Git and Python" 6 50
    apt-get -y install git-core python >> ${LOGFILE}

    dialog --title "COUCHPOTATO" --infobox "Killing and version of couchpotato currently running" 6 50
    sleep 2
    killall couchpotato* >> ${LOGFILE}

    dialog --title "COUCHPOTATO" --infobox "Downloading the latest version of CouchPotato" 6 50
    sleep 2
    git clone git://github.com/RuudBurger/CouchPotatoServer.git /home/${UNAME}/.couchpotato > /dev/null 2>&1

    dialog --title "COUCHPOTATO" --infobox "Installing upstart configurations" 6 50
    sleep 2

cat > /etc/init/couchpotato.conf << EOF
description "Upstart Script to run couchpotato as a service on Ubuntu/Debian based systems"

setuid ${UNAME}
setgid ${UNAME}
D
start on runlevel [2345]
stop on runlevel [016]

respawn
respawn limit 10 10

exec python /home/${UNAME}/.couchpotato/CouchPotato.py
EOF

PASSWORDHASH=$(printf '%s' '${PASSWORD}' | md5sum | cut -d ' ' -f 1)

cat << EOF > /home/${UNAME}/.couchpotato/settings.conf
[core]
api_key = ${API}
username = ${USERNAME}
ssl_key =
proxy_server =
ssl_cert =
data_dir =
use_proxy = 0
permission_file = 0755
proxy_password = 0
bookmarklet_host = 0
dereferer = http://www.nullrefer.com/?
permission_folder = 0755
dark_theme = False
development = 0
proxy_username =
ipv6 = 0
debug = 0
launch_browser = 0
password = ${PASSWORDHASH}
port = 5050
url_base = /couchpotato
show_wizard = 0

[download_providers]

[updater]
notification = True
enabled = True
git_command = git
automatic = True

[automation]
rating = 7.0
votes = 1000
hour = 12
required_genres =
year = 2011
ignored_genres =

[manage]
startup_scan = True
library_refresh_interval = 0
cleanup = True
enabled = True
library = ${MOVIEDIR}/Movies/

[renamer]
nfo_name = <filename>.orig.<ext>
from = ${DOWNLOADDIR}/Downloads/Complete/
force_every = 1
move_leftover = False
to = ${MOVIEDIR}/Movies/
file_name = <thename><cd>.<ext>
enabled = 1
next_on_failed = True
default_file_action = move
unrar = 1
rename_nfo = True
cleanup = False
separator =
folder_name = <namethe> (<year>)
run_every = 1
foldersep =
file_action = move
ntfs_permission = False
unrar_path =
unrar_modify_date = 1
check_space = True

[subtitle]
languages = en
force = False
enabled = 1

[trailer]
quality = 720p
enabled = False
name = <filename>-trailer

[blackhole]
directory = ${DOWNLOADDIR}/Downloads/Torrents/
manual = 0
enabled = 0
create_subdir = 0
use_for = both

[deluge]
username =
delete_failed = True
completed_directory =
manual = 0
enabled = 0
label =
paused = False
host = localhost:58846
delete_files = True
directory =
remove_complete = True
password =

[nzbget]
username = admin
category = Movies
delete_failed = True
manual = 0
enabled = 1
priority = 0
ssl = 0
host = localhost:6789
password = ${PASSWORD}

[nzbvortex]
group =
delete_failed = True
manual = False
enabled = 0
host = https://localhost:4321
api_key =

[pneumatic]
directory =
manual = 0
enabled = 0

[qbittorrent]
username =
manual = 0
enabled = 0
paused = False
host = http://localhost:8080/
delete_files = True
remove_complete = False
password =

[rtorrent]
username =
rpc_url = RPC2
manual = 0
enabled = 0
label =
paused = False
ssl = 0
host = localhost:80
delete_files = True
directory =
remove_complete = False
password =

[sabnzbd]
category = Movies
delete_failed = True
manual = False
enabled = 1
priority = 0
ssl = 0
host = localhost:8085
remove_complete = False
api_key = ${API}

[synology]
username =
manual = 0
destination =
enabled = 0
host = localhost:5000
password =
use_for = both

[transmission]
username = admin
stalled_as_failed = 0
delete_failed = True
rpc_url = transmission
manual = 0
enabled = 0
paused = False
host = http://localhost:9091
delete_files = True
directory = ${MOVIEDIR}/Movies/
remove_complete = True
password = ${PASSWORD}

[utorrent]
username =
delete_failed = True
manual = 0
enabled = 0
label =
paused = False
host = localhost:8000
delete_files = True
remove_complete = True
password =

[notification_providers]

[boxcar2]
token =
enabled = 0
on_snatch = 0

[email]
starttls = 0
smtp_pass =
on_snatch = 0
from =
to =
smtp_port = 25
enabled = 0
smtp_server =
smtp_user =
ssl = 0

[growl]
password =
on_snatch = False
hostname =
enabled = 0
port =

[nmj]
host = localhost
enabled = 0
mount =
database =

[notifymyandroid]
priority = 0
dev_key =
api_key =
enabled = 0
on_snatch = 0

[notifymywp]
priority = 0
dev_key =
api_key =
enabled = 0
on_snatch = 0

[plex]
on_snatch = 0
clients =
enabled = 0
media_server = localhost

[prowl]
priority = 0
on_snatch = 0
api_key =
enabled = 0

[pushalot]
auth_token =
important = 0
enabled = 0
silent = 0
on_snatch = 0

[pushbullet]
on_snatch = 0
api_key =
enabled = 0
devices =

[pushover]
sound =
on_snatch = 0
user_key =
enabled = 0
priority = 0
api_token = YkxHMYDZp285L265L3IwH3LmzkTaCy

[synoindex]
enabled = 0

[toasty]
on_snatch = 0
api_key =
enabled = 0

[trakt]
remove_watchlist_enabled = False
notification_enabled = False
automation_password =
automation_enabled = False
automation_username =
automation_api_key =

[twitter]
on_snatch = 0
screen_name =
enabled = 0
access_token_key =
mention =
access_token_secret =
direct_message = 0

[${UNAME}]
username = ${USERNAME} >> /home/${UNAME}/.couchpotato/settings.conf
on_snatch = False
force_full_scan = 0
only_first = 0
enabled = 1
remote_dir_scan = 0
host = localhost:8080
password = ${PASSWORD} >> /home/${UNAME}/.couchpotato/settings.conf
meta_disc_art_name = disc.png
meta_extra_thumbs_name = extrathumbs/thumb<i>.jpg
meta_thumbnail = True
meta_extra_fanart = 1
meta_logo = 1
meta_enabled = 1
meta_landscape_name = landscape.jpg
meta_nfo_name = %s.nfo
meta_banner_name = banner.jpg
meta_landscape = 1
meta_extra_fanart_name = extrafanart/extrafanart<i>.jpg
meta_nfo = True
meta_fanart = True
meta_thumbnail_name = %s.tbn
meta_url_only = False
meta_fanart_name = %s-fanart.jpg
meta_logo_name = logo.png
meta_banner = False
meta_clear_art = False
meta_clear_art_name = clearart.png
meta_extra_thumbs = 1
meta_disc_art = 1

[xmpp]
username =
on_snatch = 0
hostname = talk.google.com
enabled = 0
to =
password =
port = 5222

[nzb_providers]

[binsearch]
enabled =
extra_score = 0

[newznab]
use = 1,0,0,0,0
extra_score = 10,0,0,0,0
enabled = 1
host = ${INDEXHOST},api.nzb.su,api.dognzb.cr,nzbs.org,https://api.nzbgeek.info
custom_tag = ,,,,
api_key = ${INDEXAPI},,,,

[nzbclub]
enabled =
extra_score = 0

[omgwtfnzbs]
username =
api_key =
enabled =
extra_score = 20

[torrent_providers]

[awesomehd]
seed_time = 40
extra_score = 20
only_internal = 1
passkey =
enabled = False
favor = both
prefer_internal = 1
seed_ratio = 1

[bithdtv]
username =
seed_time = 40
extra_score = 20
enabled = False
password =
seed_ratio = 1

[bitsoup]
username =
seed_time = 40
extra_score = 20
enabled = False
password =
seed_ratio = 1

[hdbits]
username =
seed_time = 40
extra_score = 0
passkey =
enabled = False
seed_ratio = 1

[ilovetorrents]
username =
seed_time = 40
extra_score = 0
enabled = False
password =
seed_ratio = 1

[iptorrents]
username =
freeleech = 0
extra_score = 0
enabled = False
seed_time = 40
password =
seed_ratio = 1

[kickasstorrents]
domain =
seed_time = 0
extra_score = 0
enabled = 0
only_verified = False
seed_ratio = 0

[passthepopcorn]
username =
domain =
seed_time = 40
extra_score = 20
passkey =
prefer_scene = 0
enabled = False
prefer_golden = 1
require_approval = 0
password =
seed_ratio = 1
prefer_freeleech = 1

[sceneaccess]
username =
seed_time = 40
extra_score = 20
enabled = False
password =
seed_ratio = 1

[thepiratebay]
seed_time = 1
domain =
enabled = 0
seed_ratio = .5
extra_score = 0

[torrentbytes]
username =
seed_time = 40
extra_score = 20
enabled = False
password =
seed_ratio = 1

[torrentday]
username =
seed_time = 40
extra_score = 0
enabled = False
password =
seed_ratio = 1

[torrentleech]
username =
seed_time = 40
extra_score = 20
enabled = False
password =
seed_ratio = 1

[torrentpotato]
use =
seed_time = 40
name =
extra_score = 0
enabled = False
host =
pass_key = ,
seed_ratio = 1

[torrentshack]
username =
seed_time = 40
extra_score = 0
enabled = False
scene_only = False
password =
seed_ratio = 1

[torrentz]
verified_only = True
extra_score = 0
minimal_seeds = 1
enabled = 0
seed_time = 40
seed_ratio = 1

[yify]
seed_time = 40
domain =
enabled = 0
seed_ratio = 1
extra_score = 0

[searcher]
preferred_method = nzb
required_words =
ignored_words = german, dutch, french, truefrench, danish, swedish, spanish, italian, korean, dubbed, swesub, korsub, dksubs, vain
preferred_words =

[nzb]
retention = 1500

[torrent]
minimum_seeders = 1

[charts]
hide_wanted = False
hide_library = False
max_items = 5

[automation_providers]

[bluray]
automation_enabled = False
chart_display_enabled = True
backlog = False

[flixster]
automation_ids_use =
automation_enabled = False
automation_ids =

[goodfilms]
automation_enabled = False
automation_username =

[imdb]
automation_charts_top250 = False
chart_display_boxoffice = True
chart_display_top250 = False
automation_enabled = False
chart_display_rentals = True
automation_urls_use =
automation_urls =
automation_providers_enabled = False
automation_charts_rentals = True
chart_display_theater = False
automation_charts_theater = True
chart_display_enabled = True
automation_charts_boxoffice = True

[itunes]
automation_enabled = False
automation_urls_use = ,
automation_urls = https://itunes.apple.com/rss/topmovies/limit=25/xml,

[kinepolis]
automation_enabled = False

[letterboxd]
automation_enabled = False
automation_urls_use =
automation_urls =

[moviemeter]
automation_enabled = False

[moviesio]
automation_enabled = False
automation_urls_use =
automation_urls =

[popularmovies]
automation_enabled = False

[rottentomatoes]
automation_enabled = False
tomatometer_percent = 80
automation_urls_use = 1
automation_urls = http://www.rottentomatoes.com/syndication/rss/in_theaters.xml

[themoviedb]
api_key = 9b939aee0aaafc12a65bf448e4af9543

[mediabrowser]
meta_enabled = False

[sonyps3]
meta_enabled = False

[windowsmediacenter]
meta_enabled = False

[moviesearcher]
cron_day = *
cron_hour = */6
cron_minute = 53
always_search = False
run_on_launch = 0
search_on_add = 1
EOF

    sudo chown -R ${UNAME}: /home/${UNAME}/.couchpotato
    sudo chmod -R 755 /home/${UNAME}/.couchpotato
    dialog --title "COUCHPOTATO" --infobox "Starting CouchPotato for the first time" 6 50
    (python /home/${UNAME}/.couchpotato/CouchPotato.py) & pid=$!
    (sleep 10 && kill -9 $pid) &
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

cat > /home/${UNAME}/.sickrage/config.ini << EOF
[General]
git_autoissues = 0
git_username = ""
git_password = ""
git_reset = 1
branch = master
git_remote = origin
git_remote_url = https://github.com/SickRage/SickRage.git
cur_commit_hash =
cur_commit_branch = ""
git_newver = 0
config_version = 7
encryption_version = 0
encryption_secret = u3oKdlqMTdWDBipKzFQnE1BjhryaqEHKoO1uErS0y5s=
log_dir = Logs
log_nr = 5
log_size = 1048576
socket_timeout = 30
web_port = 8081
web_host = 0.0.0.0
web_ipv6 = 0
web_log = 0
web_root = "/sickrage"
web_username = ${UNAME}
web_password = ${PASSWORD}
web_cookie_secret = 6XmTzRfrQjmUNSB3RP7qX3s0leW0BE1NhG44+lncwn4=
web_use_gzip = 1
ssl_verify = 1
download_url = ""
localhost_ip = ""
cpu_preset = NORMAL
anon_redirect = http://dereferer.org/?
api_key = 9290f2d83fa7952e0839df0e786c65f2
debug = 0
default_page = home
enable_https = 0
notify_on_login = 0
https_cert = server.crt
https_key = server.key
handle_reverse_proxy = 0
use_nzbs = 0
use_torrents = 1
nzb_method = blackhole
torrent_method = blackhole
usenet_retention = 500
autopostprocesser_frequency = 10
dailysearch_frequency = 40
backlog_frequency = 720
update_frequency = 1
showupdate_hour = 3
download_propers = 1
randomize_providers = 0
check_propers_interval = daily
allow_high_priority = 1
skip_removed_files = 0
allowed_extensions = "nfo,srr,sfv"
quality_default = 22053375
status_default = 5
status_default_after = 3
flatten_folders_default = 0
indexer_default = 0
indexer_timeout = 20
anime_default = 0
scene_default = 0
archive_default = 0
provider_order = torrentz nyaatorrents cpasbien kickasstorrents rarbg bitcannon strike extratorrent btdigg torrentproject hounddawgs hdbits alpharatio scenetime btn hdspace torrentbytes elitetorrent speedcd tntvillage xthor shazbat_tv iptorrents morethantv tvchaosuk titansoftv pretome torrentday sceneaccess bitsoup newpct tokyotoshokan hdtorrents thepiratebay bluetigers fnt freshontv t411 torrentleech transmitthenet gftracker bitsnoop danishbits
version_notify = 1
auto_update = 1
notify_on_update = 1
naming_strip_year = 0
naming_pattern = Season %0S/%SN - S%0SE%0E - %EN
naming_custom_abd = 0
naming_abd_pattern = %SN - %A.D - %EN
naming_custom_sports = 0
naming_sports_pattern = %SN - %A-D - %EN
naming_custom_anime = 0
naming_anime_pattern = Season %0S/%SN - S%0SE%0E - %EN
naming_multi_ep = 1
naming_anime_multi_ep = 1
naming_anime = 3
indexerDefaultLang = en
ep_default_deleted_status = 6
launch_browser = 0
trash_remove_show = 0
trash_rotate_logs = 0
sort_article = 0
proxy_setting = ""
proxy_indexers = 0
use_listview = 0
metadata_kodi = 0|0|0|0|0|0|0|0|0|0
metadata_kodi_12plus = 0|0|0|0|0|0|0|0|0|0
metadata_mediabrowser = 0|0|0|0|0|0|0|0|0|0
metadata_ps3 = 0|0|0|0|0|0|0|0|0|0
metadata_wdtv = 0|0|0|0|0|0|0|0|0|0
metadata_tivo = 0|0|0|0|0|0|0|0|0|0
metadata_mede8er = 0|0|0|0|0|0|0|0|0|0
backlog_days = 7
cache_dir = cache
root_dirs = 0|${TVSHOWDIR}
tv_download_dir = ${DOWNLOADDIR}/Download/Complete
keep_processed_dir = 0
process_method = move
del_rar_contents = 1
move_associated_files = 1
sync_files = "!sync,lftp-pget-status,part,bts,!qb"
postpone_if_sync_files = 1
postpone_if_no_subs = 0
nfo_rename = 1
process_automatically = 1
no_delete = 0
unpack = 1
rename_episodes = 1
airdate_episodes = 0
file_timestamp_timezone = network
create_missing_show_dirs = 1
add_shows_wo_dir = 0
extra_scripts = ""
git_path = ""
ignore_words = "german,french,core2hd,dutch,swedish,reenc,MrLss"
trackers_list = "udp://coppersurfer.tk:6969/announce,udp://open.demonii.com:1337,udp://exodus.desync.com:6969,udp://9.rarbg.me:2710/announce,udp://glotorrents.pw:6969/announce,udp://tracker.openbittorrent.com:80/announce,udp://9.rarbg.to:2710/announce"
require_words = ""
ignored_subs_list = "dk,fin,heb,kor,nor,nordic,pl,swe"
calendar_unprotected = 0
calendar_icons = 0
no_restart = 0
developer = 0
display_all_seasons = 1
news_last_read = 1970-01-01
[Blackhole]
nzb_dir = ""
torrent_dir = ${DOWNLOADDIR}/Downloads/torrents
[TORRENTZ]
torrentz = 1
torrentz_confirmed = 1
torrentz_ratio = ""
torrentz_minseed = 1
torrentz_minleech = 0
torrentz_search_mode = eponly
torrentz_search_fallback = 0
torrentz_enable_daily = 1
torrentz_enable_backlog = 1
[NYAATORRENTS]
nyaatorrents = 1
nyaatorrents_confirmed = 1
nyaatorrents_ratio = ""
nyaatorrents_minseed = 1
nyaatorrents_minleech = 0
nyaatorrents_search_mode = eponly
nyaatorrents_search_fallback = 0
nyaatorrents_enable_daily = 1
nyaatorrents_enable_backlog = 1
[CPASBIEN]
cpasbien = 1
cpasbien_ratio = ""
cpasbien_search_mode = eponly
cpasbien_search_fallback = 0
cpasbien_enable_daily = 1
cpasbien_enable_backlog = 1
[KICKASSTORRENTS]
kickasstorrents = 1
kickasstorrents_custom_url = ""
kickasstorrents_confirmed = 1
kickasstorrents_ratio = ""
kickasstorrents_minseed = 1
kickasstorrents_minleech = 0
kickasstorrents_search_mode = eponly
kickasstorrents_search_fallback = 0
kickasstorrents_enable_daily = 1
kickasstorrents_enable_backlog = 1
[RARBG]
rarbg = 0
rarbg_ranked = 1
rarbg_sorting = seeders
rarbg_ratio = ""
rarbg_minseed = 1
rarbg_minleech = 0
rarbg_search_mode = eponly
rarbg_search_fallback = 0
rarbg_enable_daily = 1
rarbg_enable_backlog = 1
[BITCANNON]
bitcannon = 0
bitcannon_custom_url = /
bitcannon_api_key = ""
bitcannon_ratio = ""
bitcannon_minseed = 1
bitcannon_minleech = 0
bitcannon_search_mode = eponly
bitcannon_search_fallback = 0
bitcannon_enable_daily = 1
bitcannon_enable_backlog = 1
[STRIKE]
strike = 0
strike_ratio = ""
strike_minseed = 1
strike_minleech = 0
strike_search_mode = eponly
strike_search_fallback = 0
strike_enable_daily = 1
strike_enable_backlog = 1
[EXTRATORRENT]
extratorrent = 0
extratorrent_ratio = ""
extratorrent_minseed = 1
extratorrent_minleech = 0
extratorrent_search_mode = eponly
extratorrent_search_fallback = 0
extratorrent_enable_daily = 1
extratorrent_enable_backlog = 1
[BTDIGG]
btdigg = 0
btdigg_ratio = ""
btdigg_search_mode = eponly
btdigg_search_fallback = 0
btdigg_enable_daily = 1
btdigg_enable_backlog = 1
[TORRENTPROJECT]
torrentproject = 0
torrentproject_ratio = ""
torrentproject_minseed = 1
torrentproject_minleech = 0
torrentproject_search_mode = eponly
torrentproject_search_fallback = 0
torrentproject_enable_daily = 1
torrentproject_enable_backlog = 1
[HOUNDDAWGS]
hounddawgs = 0
hounddawgs_username = ""
hounddawgs_password = ""
hounddawgs_ranked = 1
hounddawgs_ratio = ""
hounddawgs_minseed = 1
hounddawgs_minleech = 0
hounddawgs_freeleech = 0
hounddawgs_search_mode = eponly
hounddawgs_search_fallback = 0
hounddawgs_enable_daily = 1
hounddawgs_enable_backlog = 1
[HDBITS]
hdbits = 0
hdbits_username = ""
hdbits_passkey = ""
hdbits_ratio = ""
hdbits_search_mode = eponly
hdbits_search_fallback = 0
hdbits_enable_daily = 1
hdbits_enable_backlog = 1
[ALPHARATIO]
alpharatio = 0
alpharatio_username = ""
alpharatio_password = ""
alpharatio_ratio = ""
alpharatio_minseed = 1
alpharatio_minleech = 0
alpharatio_search_mode = eponly
alpharatio_search_fallback = 0
alpharatio_enable_daily = 1
alpharatio_enable_backlog = 1
[SCENETIME]
scenetime = 0
scenetime_username = ""
scenetime_password = ""
scenetime_ratio = ""
scenetime_minseed = 1
scenetime_minleech = 0
scenetime_search_mode = eponly
scenetime_search_fallback = 0
scenetime_enable_daily = 1
scenetime_enable_backlog = 1
[BTN]
btn = 0
btn_api_key = ""
btn_ratio = ""
btn_search_mode = eponly
btn_search_fallback = 0
btn_enable_daily = 1
btn_enable_backlog = 1
[HDSPACE]
hdspace = 0
hdspace_username = ""
hdspace_password = ""
hdspace_ratio = ""
hdspace_minseed = 1
hdspace_minleech = 0
hdspace_search_mode = eponly
hdspace_search_fallback = 0
hdspace_enable_daily = 1
hdspace_enable_backlog = 1
[TORRENTBYTES]
torrentbytes = 0
torrentbytes_username = ""
torrentbytes_password = ""
torrentbytes_ratio = ""
torrentbytes_minseed = 1
torrentbytes_minleech = 0
torrentbytes_freeleech = 0
torrentbytes_search_mode = eponly
torrentbytes_search_fallback = 0
torrentbytes_enable_daily = 1
torrentbytes_enable_backlog = 1
[ELITETORRENT]
elitetorrent = 0
elitetorrent_onlyspasearch = 0
elitetorrent_minseed = 1
elitetorrent_minleech = 0
elitetorrent_search_mode = eponly
elitetorrent_search_fallback = 0
elitetorrent_enable_daily = 1
elitetorrent_enable_backlog = 1
[SPEEDCD]
speedcd = 0
speedcd_username = ""
speedcd_password = ""
speedcd_ratio = ""
speedcd_minseed = 1
speedcd_minleech = 0
speedcd_freeleech = 0
speedcd_search_mode = eponly
speedcd_search_fallback = 0
speedcd_enable_daily = 1
speedcd_enable_backlog = 1
[TNTVILLAGE]
tntvillage = 0
tntvillage_username = ""
tntvillage_password = ""
tntvillage_engrelease = 0
tntvillage_ratio = ""
tntvillage_minseed = 1
tntvillage_minleech = 0
tntvillage_search_mode = eponly
tntvillage_search_fallback = 0
tntvillage_enable_daily = 1
tntvillage_enable_backlog = 1
tntvillage_cat = 0
tntvillage_subtitle = 0
[XTHOR]
xthor = 0
xthor_username = ""
xthor_password = ""
xthor_ratio = ""
xthor_search_mode = eponly
xthor_search_fallback = 0
xthor_enable_daily = 1
xthor_enable_backlog = 1
[SHAZBAT_TV]
shazbat_tv = 0
shazbat_tv_passkey = ""
shazbat_tv_ratio = ""
shazbat_tv_options = ""
shazbat_tv_search_mode = eponly
shazbat_tv_search_fallback = 0
shazbat_tv_enable_daily = 1
shazbat_tv_enable_backlog = 0
[IPTORRENTS]
iptorrents = 0
iptorrents_username = ""
iptorrents_password = ""
iptorrents_ratio = ""
iptorrents_minseed = 1
iptorrents_minleech = 0
iptorrents_freeleech = 0
iptorrents_search_mode = eponly
iptorrents_search_fallback = 0
iptorrents_enable_daily = 1
iptorrents_enable_backlog = 1
[MORETHANTV]
morethantv = 0
morethantv_username = ""
morethantv_password = ""
morethantv_ratio = ""
morethantv_minseed = 1
morethantv_minleech = 0
morethantv_search_mode = eponly
morethantv_search_fallback = 0
morethantv_enable_daily = 1
morethantv_enable_backlog = 1
[TVCHAOSUK]
tvchaosuk = 0
tvchaosuk_username = ""
tvchaosuk_password = ""
tvchaosuk_ratio = ""
tvchaosuk_minseed = 1
tvchaosuk_minleech = 0
tvchaosuk_freeleech = 0
tvchaosuk_search_mode = eponly
tvchaosuk_search_fallback = 0
tvchaosuk_enable_daily = 1
tvchaosuk_enable_backlog = 1
[TITANSOFTV]
titansoftv = 0
titansoftv_api_key = ""
titansoftv_ratio = ""
titansoftv_search_mode = eponly
titansoftv_search_fallback = 0
titansoftv_enable_daily = 1
titansoftv_enable_backlog = 1
[PRETOME]
pretome = 0
pretome_username = ""
pretome_password = ""
pretome_pin = ""
pretome_ratio = ""
pretome_minseed = 1
pretome_minleech = 0
pretome_search_mode = eponly
pretome_search_fallback = 0
pretome_enable_daily = 1
pretome_enable_backlog = 1
[TORRENTDAY]
torrentday = 0
torrentday_username = ""
torrentday_password = ""
torrentday_ratio = ""
torrentday_minseed = 1
torrentday_minleech = 0
torrentday_freeleech = 0
torrentday_search_mode = eponly
torrentday_search_fallback = 0
torrentday_enable_daily = 1
torrentday_enable_backlog = 1
[SCENEACCESS]
sceneaccess = 0
sceneaccess_username = ""
sceneaccess_password = ""
sceneaccess_ratio = ""
sceneaccess_minseed = 1
sceneaccess_minleech = 0
sceneaccess_search_mode = eponly
sceneaccess_search_fallback = 0
sceneaccess_enable_daily = 1
sceneaccess_enable_backlog = 1
[BITSOUP]
bitsoup = 0
bitsoup_username = ""
bitsoup_password = ""
bitsoup_ratio = ""
bitsoup_minseed = 1
bitsoup_minleech = 0
bitsoup_search_mode = eponly
bitsoup_search_fallback = 0
bitsoup_enable_daily = 1
bitsoup_enable_backlog = 1
[NEWPCT]
newpct = 0
newpct_onlyspasearch = 0
newpct_search_mode = eponly
newpct_search_fallback = 0
newpct_enable_daily = 1
newpct_enable_backlog = 1
[TOKYOTOSHOKAN]
tokyotoshokan = 0
tokyotoshokan_ratio = ""
tokyotoshokan_search_mode = eponly
tokyotoshokan_search_fallback = 0
tokyotoshokan_enable_daily = 1
tokyotoshokan_enable_backlog = 1
[HDTORRENTS]
hdtorrents = 0
hdtorrents_username = ""
hdtorrents_password = ""
hdtorrents_ratio = ""
hdtorrents_minseed = 1
hdtorrents_minleech = 0
hdtorrents_search_mode = eponly
hdtorrents_search_fallback = 0
hdtorrents_enable_daily = 1
hdtorrents_enable_backlog = 1
[THEPIRATEBAY]
thepiratebay = 0
thepiratebay_custom_url = ""
thepiratebay_confirmed = 1
thepiratebay_ratio = ""
thepiratebay_minseed = 1
thepiratebay_minleech = 0
thepiratebay_search_mode = eponly
thepiratebay_search_fallback = 0
thepiratebay_enable_daily = 1
thepiratebay_enable_backlog = 1
[BLUETIGERS]
bluetigers = 0
bluetigers_username = ""
bluetigers_password = ""
bluetigers_ratio = ""
bluetigers_search_mode = eponly
bluetigers_search_fallback = 0
bluetigers_enable_daily = 1
bluetigers_enable_backlog = 1
[FNT]
fnt = 0
fnt_username = ""
fnt_password = ""
fnt_ratio = ""
fnt_minseed = 1
fnt_minleech = 0
fnt_search_mode = eponly
fnt_search_fallback = 0
fnt_enable_daily = 1
fnt_enable_backlog = 1
[FRESHONTV]
freshontv = 0
freshontv_username = ""
freshontv_password = ""
freshontv_ratio = ""
freshontv_minseed = 1
freshontv_minleech = 0
freshontv_freeleech = 0
freshontv_search_mode = eponly
freshontv_search_fallback = 0
freshontv_enable_daily = 1
freshontv_enable_backlog = 1
[T411]
t411 = 0
t411_username = ""
t411_password = ""
t411_confirmed = 1
t411_ratio = ""
t411_minseed = 1
t411_minleech = 0
t411_search_mode = eponly
t411_search_fallback = 0
t411_enable_daily = 1
t411_enable_backlog = 1
[TORRENTLEECH]
torrentleech = 0
torrentleech_username = ""
torrentleech_password = ""
torrentleech_ratio = ""
torrentleech_minseed = 1
torrentleech_minleech = 0
torrentleech_search_mode = eponly
torrentleech_search_fallback = 0
torrentleech_enable_daily = 1
torrentleech_enable_backlog = 1
[TRANSMITTHENET]
transmitthenet = 0
transmitthenet_username = ""
transmitthenet_password = ""
transmitthenet_ratio = ""
transmitthenet_minseed = 1
transmitthenet_minleech = 0
transmitthenet_freeleech = 0
transmitthenet_search_mode = eponly
transmitthenet_search_fallback = 0
transmitthenet_enable_daily = 1
transmitthenet_enable_backlog = 1
[GFTRACKER]
gftracker = 0
gftracker_username = ""
gftracker_password = ""
gftracker_ratio = ""
gftracker_minseed = 1
gftracker_minleech = 0
gftracker_search_mode = eponly
gftracker_search_fallback = 0
gftracker_enable_daily = 1
gftracker_enable_backlog = 1
[BITSNOOP]
bitsnoop = 0
bitsnoop_ratio = ""
bitsnoop_minseed = 1
bitsnoop_minleech = 0
bitsnoop_search_mode = eponly
bitsnoop_search_fallback = 0
bitsnoop_enable_daily = 1
bitsnoop_enable_backlog = 1
[DANISHBITS]
danishbits = 0
danishbits_username = ""
danishbits_password = ""
danishbits_ratio = ""
danishbits_minseed = 1
danishbits_minleech = 0
danishbits_freeleech = 0
danishbits_search_mode = eponly
danishbits_search_fallback = 0
danishbits_enable_daily = 1
danishbits_enable_backlog = 1
[HD4FREE]
hd4free = 0
hd4free_api_key = ""
hd4free_username = ""
hd4free_ratio = ""
hd4free_minseed = 1
hd4free_minleech = 0
hd4free_freeleech = 0
hd4free_search_mode = eponly
hd4free_search_fallback = 0
hd4free_enable_daily = 1
hd4free_enable_backlog = 1
[NZBS_ORG]
nzbs_org = 0
nzbs_org_search_mode = eponly
nzbs_org_search_fallback = 0
nzbs_org_enable_daily = 1
nzbs_org_enable_backlog = 1
[NZBGEEK]
nzbgeek = 0
nzbgeek_search_mode = eponly
nzbgeek_search_fallback = 0
nzbgeek_enable_daily = 1
nzbgeek_enable_backlog = 1
[ANIMENZB]
animenzb = 0
animenzb_search_mode = eponly
animenzb_search_fallback = 0
animenzb_enable_daily = 1
animenzb_enable_backlog = 0
[BINSEARCH]
binsearch = 0
binsearch_search_mode = eponly
binsearch_search_fallback = 0
binsearch_enable_daily = 1
binsearch_enable_backlog = 0
[OMGWTFNZBS]
omgwtfnzbs = 0
omgwtfnzbs_api_key = ""
omgwtfnzbs_username = ""
omgwtfnzbs_search_mode = eponly
omgwtfnzbs_search_fallback = 0
omgwtfnzbs_enable_daily = 1
omgwtfnzbs_enable_backlog = 1
[WOMBLE_S_INDEX]
womble_s_index = 0
womble_s_index_search_mode = eponly
womble_s_index_search_fallback = 0
womble_s_index_enable_daily = 1
womble_s_index_enable_backlog = 0
[NZB_CAT]
nzb_cat = 0
nzb_cat_search_mode = eponly
nzb_cat_search_fallback = 0
nzb_cat_enable_daily = 1
nzb_cat_enable_backlog = 1
[USENET_CRAWLER]
usenet_crawler = 0
usenet_crawler_search_mode = eponly
usenet_crawler_search_fallback = 0
usenet_crawler_enable_daily = 1
usenet_crawler_enable_backlog = 1
[NZBs]
nzbs = 0
nzbs_uid = ""
nzbs_hash = ""
[Newzbin]
newzbin = 0
newzbin_username = ""
newzbin_password = ""
[SABnzbd]
sab_username = ""
sab_password = ""
sab_apikey = ""
sab_category = tv
sab_category_backlog = tv
sab_category_anime = anime
sab_category_anime_backlog = anime
sab_host = ""
sab_forced = 0
[NZBget]
nzbget_username = nzbget
nzbget_password = tegbzn6789
nzbget_category = tv
nzbget_category_backlog = tv
nzbget_category_anime = anime
nzbget_category_anime_backlog = anime
nzbget_host = ""
nzbget_use_https = 0
nzbget_priority = 100
[TORRENT]
torrent_username = ""
torrent_password = ${PASSWORD}
torrent_host = http://localhost:8112/
torrent_path = ${DOWNLOADDIR}/Downloads/Complete
torrent_seed_time = 0
torrent_paused = 0
torrent_high_bandwidth = 0
torrent_label = tvshow
torrent_label_anime = animeshow
torrent_verify_cert = 0
torrent_rpcurl = transmission
torrent_auth_type = none
[KODI]
use_kodi = 1
kodi_always_on = 1
kodi_notify_onsnatch = 1
kodi_notify_ondownload = 1
kodi_notify_onsubtitledownload = 1
kodi_update_library = 1
kodi_update_full = 1
kodi_update_onlyfirst = 0
kodi_host = localhost:8080
kodi_username = ${UNAME}
kodi_password = ${PASSWORD}
[Plex]
use_plex = 0
plex_notify_onsnatch = 0
plex_notify_ondownload = 0
plex_notify_onsubtitledownload = 0
plex_update_library = 0
plex_server_host = ""
plex_server_token = ""
plex_host = ""
plex_username = ""
plex_password = ""
[Emby]
use_emby = 0
emby_host = ""
emby_apikey = ""
[Growl]
use_growl = 0
growl_notify_onsnatch = 0
growl_notify_ondownload = 0
growl_notify_onsubtitledownload = 0
growl_host = ""
growl_password = ""
[FreeMobile]
use_freemobile = 0
freemobile_notify_onsnatch = 0
freemobile_notify_ondownload = 0
freemobile_notify_onsubtitledownload = 0
freemobile_id = ""
freemobile_apikey = ""
[Prowl]
use_prowl = 0
prowl_notify_onsnatch = 0
prowl_notify_ondownload = 0
prowl_notify_onsubtitledownload = 0
prowl_api = ""
prowl_priority = 0
prowl_message_title = SickRage
[Twitter]
use_twitter = 0
twitter_notify_onsnatch = 0
twitter_notify_ondownload = 0
twitter_notify_onsubtitledownload = 0
twitter_username = ""
twitter_password = ""
twitter_prefix = SickRage
twitter_dmto = ""
twitter_usedm = 0
[Boxcar2]
use_boxcar2 = 0
boxcar2_notify_onsnatch = 0
boxcar2_notify_ondownload = 0
boxcar2_notify_onsubtitledownload = 0
boxcar2_accesstoken = ""
[Pushover]
use_pushover = 0
pushover_notify_onsnatch = 0
pushover_notify_ondownload = 0
pushover_notify_onsubtitledownload = 0
pushover_userkey = ""
pushover_apikey = ""
pushover_device = ""
pushover_sound = pushover
[Libnotify]
use_libnotify = 0
libnotify_notify_onsnatch = 0
libnotify_notify_ondownload = 0
libnotify_notify_onsubtitledownload = 0
[NMJ]
use_nmj = 0
nmj_host = ""
nmj_database = ""
nmj_mount = ""
[NMJv2]
use_nmjv2 = 0
nmjv2_host = ""
nmjv2_database = ""
nmjv2_dbloc = ""
[Synology]
use_synoindex = 0
[SynologyNotifier]
use_synologynotifier = 0
synologynotifier_notify_onsnatch = 0
synologynotifier_notify_ondownload = 0
synologynotifier_notify_onsubtitledownload = 0
[Trakt]
use_trakt = 0
trakt_username = ""
trakt_access_token = ""
trakt_refresh_token = ""
trakt_remove_watchlist = 0
trakt_remove_serieslist = 0
trakt_remove_show_from_sickrage = 0
trakt_sync_watchlist = 0
trakt_method_add = 0
trakt_start_paused = 0
trakt_use_recommended = 0
trakt_sync = 0
trakt_sync_remove = 0
trakt_default_indexer = 1
trakt_timeout = 30
trakt_blacklist_name = ""
[pyTivo]
use_pytivo = 0
pytivo_notify_onsnatch = 0
pytivo_notify_ondownload = 0
pytivo_notify_onsubtitledownload = 0
pyTivo_update_library = 0
pytivo_host = ""
pytivo_share_name = ""
pytivo_tivo_name = ""
[NMA]
use_nma = 0
nma_notify_onsnatch = 0
nma_notify_ondownload = 0
nma_notify_onsubtitledownload = 0
nma_api = ""
nma_priority = 0
[Pushalot]
use_pushalot = 0
pushalot_notify_onsnatch = 0
pushalot_notify_ondownload = 0
pushalot_notify_onsubtitledownload = 0
pushalot_authorizationtoken = ""
[Pushbullet]
use_pushbullet = 0
pushbullet_notify_onsnatch = 0
pushbullet_notify_ondownload = 0
pushbullet_notify_onsubtitledownload = 0
pushbullet_api = ""
pushbullet_device = ""
[Email]
use_email = 0
email_notify_onsnatch = 0
email_notify_ondownload = 0
email_notify_onsubtitledownload = 0
email_host = ""
email_port = 25
email_tls = 0
email_user = ""
email_password = ""
email_from = ""
email_list = ""
[Newznab]
newznab_data = "NZBGeek|https://api.nzbgeek.info/||5030,5040|0|eponly|0|1|1!!!Usenet-Crawler|https://www.usenet-crawler.com/||5030,5040|0|eponly|0|1|1"
[TorrentRss]
torrentrss_data = ""
[GUI]
gui_name = slick
theme_name = dark
home_layout = poster
history_layout = detailed
history_limit = 100
display_show_specials = 1
coming_eps_layout = banner
coming_eps_display_paused = 0
coming_eps_sort = date
coming_eps_missed_range = 7
fuzzy_dating = 0
trim_zero = 0
date_preset = %x
time_preset = %I:%M:%S %p
timezone_display = local
poster_sortby = name
poster_sortdir = 1
[Subtitles]
use_subtitles = 1
subtitles_languages = "dut,eng"
SUBTITLES_SERVICES_LIST = "addic7ed,legendastv,napiprojekt,opensubtitles,podnapisi,thesubdb,tvsubtitles"
SUBTITLES_SERVICES_ENABLED = 0|0|1|0|1|1|1
subtitles_dir = ""
subtitles_default = 1
subtitles_history = 0
subtitles_perfect_match = 1
embedded_subtitles_all = 0
subtitles_hearing_impaired = 0
subtitles_finder_frequency = 1
subtitles_multi = 1
subtitles_extra_scripts = ""
subtitles_download_in_pp = 0
addic7ed_username = ""
addic7ed_password = ""
legendastv_username = ""
legendastv_password = ""
opensubtitles_username = ""
opensubtitles_password = ""
[FailedDownloads]
use_failed_downloads = 1
delete_failed = 1
[ANIDB]
use_anidb = 0
anidb_username = ""
anidb_password = ""
anidb_use_mylist = 0
[ANIME]
anime_split_home = 0
EOF

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
    installApache
    IPADDR=$(/sbin/ifconfig eth0 | awk '/inet / { print $2 }' | sed 's/addr://')

    dialog --title "FINISHED" --msgbox "Apache rewrite installed. Use https://$IPADDR/sonarr to access sonarr, same for couchpotato and sabnzbd" 10 50
    dialog --title "FINISHED" --msgbox "All done. A restart will be triggered within 10-20 seconds" 10 50
fi

if [[ ${APPS} == *SABnzbd* ]]; then
    start sabnzbd  > /dev/null 2>&1
fi

if [[ ${APPS} == *Sonarr* ]]; then
    start sonarr  > /dev/null 2>&1
fi

if [[ ${APPS} == *CouchPotato* ]]; then
    start couchpotato  > /dev/null 2>&1
fi

if [[ ${APPS} == *SickRage* ]]; then
    start sickrage  > /dev/null 2>&1
fi

sleep 10
rebootMachine