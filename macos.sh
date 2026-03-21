#!/usr/bin/env bash

ADMIN="admin"
USER="termontwouter"

LANG="en"
REGION="GB"
VALUTA="EUR"
METRIC="true"
UNIT="Centimeters"
TIME_ZONE="Europe/Brussels"
TIME_SERVER="" # TODO

DEVICE="TP-Link_WT2_991.m"

HOST_NAME="$DEVICE"
LOCAL_NAME="$DEVICE"
COMPUTER_NAME="$DEVICE"

###############################################################################
# PREPARATION
###############################################################################

if [[ $(id -u) -ne 0 ]];
	echo "Need to run this script as root"
	exit 1
fi

osascript -e 'tell application "System Preferences" to quit'

set +x -euo pipefail

disable() {
  local SERVS=(
    "system/$1"
    "user/$UID_ADMIN/$1"
    "user/$UID_USER/$1"
    "gui/$UID_ADMIN/$1"
    "gui/$UID_USER/$1"
  )
  for SRV in "${SERVS[@]}"; do
    if [[ $(launchctl print "$SRV") ]]; then
      launchctl disable "$SRV"
      launchctl bootout  "$SRV"
    fi
  done
}

configure() {
  local SCOPE="$1"; shift
  if [[ $SCOPE -eq "-g" || $SCOPE -eq "NSGlobalDomain" ]]; then
    SCOPE=.GlobalPreferences
  fi
  local PREFS=(
    "/Library/Preferences/$1"
    "/Users/Library/Preferences/$ADMIN/$1"
    "/Users/Library/Preferences/$USER/$1"
  )
  for PRF in "${PREFS[@]}"; do
    if [[ -f "$PRF.plist" ]]; then
      defaults write "$PRF" "$@"
    fi
  done
}

edit() {
  local SCOPE="$1"; shift
  if [[ $SCOPE -eq "-g" || $SCOPE -eq "NSGlobalDomain" ]]; then
    SCOPE=.GlobalPreferences
  fi
  local PREFS=(
    "/Library/Preferences/$1"
    "/Users/Library/Preferences/$ADMIN/$1"
    "/Users/Library/Preferences/$USER/$1"
  )
  for PRF in "${PREFS[@]}"; do
    if [[ -f "$PRF.plist" ]]; then
      /usr/libexec/PlistBuddy "$@" "$PRF"
    fi
  done
}

clear


###############################################################################
# USER SETUP
###############################################################################

# create non-privileged user
sysadminctl -addUser $USER -password "-" # prompt
sysadminctl -secureTokenOn $USER
sysadminctl -secureTokenStatus $USER

# remove guest/admin from login screen, and disable automatic login
defaults delete com.apple.loginwindow autoLoginUser
fdesetup remove -user $ADMIN
fdesetup remove -user Guest
rm /etc/kcpassword

# store user ids
UID_ADMIN="$(id -u $ADMIN)"
UID_USER="$(id -u $USER)"


###############################################################################
# SYSTEM SETUP
###############################################################################

# enable gatekeeper
spctl --master-enable

# disable remote access
systemsetup -setremotelogin off
systemsetup -setremoteappleevents off

# enable safe error recovery
systemsetup -setrestartfreeze on
systemsetup -setrestartpowerfailure on
systemsetup -setallowpowerbuttontosleepcomputer on
systemsetup -setwaitforstartupafterpowerfailure on

# set time zone and server
systemsetup -setusingnetworktime on
systemsetup -setnetworktimeserver "$TIME_SERVER"
systemsetup -settimezone "$TIME_ZONE"

# set locale
configure -g AppleLocale -string "${LANG}_${REGION}@currency=${VALUTA}"
configure -g AppleLanguages -array "$LANG"
configure -g AppleMetricUnits -bool "$METRIC"
configure -g AppleMeasurementUnits -string "$UNIT"

# set host info and display it when clicking on the login clock
configure com.apple.loginwindow AdminHostInfo HostName
defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "$DEVICE"
scutil --set ComputerName $COMPUTER_NAME
scutil --set LocalHostName $LOCAL_NAME
scutil --set HostName $HOST_NAME


###############################################################################
# Session management
###############################################################################

# Turn off password hints
configure com.apple.loginwindow RetriesUntilHint -int 0

# Save app state on logout to restore on login
configure com.apple.loginwindow TALLogoutSavesState -bool true

# Hide the "Other..." option on login
configure com.apple.loginwindow SHOWOTHERUSERS_MANAGED -bool false

# Remove the list of users from the login screen
configure com.apple.loginwindow SHOWFULLNAME -int 1

# Hide language menu in the top right corner of the boot screen
configure com.apple.loginwindow showInputMenu -bool false

# Disable console access on login
configure com.apple.loginwindow DisableConsoleAccess -bool true

# disable guest login
configure com.apple.loginwindow guestEnabled -bool false
configure com.apple.AppleFileServer guestAccess -bool false
configure com.apple.smb.server AllowGuestAccess -bool false


###############################################################################
# Updates
###############################################################################

# Enable the automatic update check, with daily frequency
configure com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
configure com.apple.SoftwareUpdate ScheduleFrequency -int 1

# Download and install system data and security updates
configure com.apple.SoftwareUpdate AutomaticDownload -int 1
configure com.apple.SoftwareUpdate CriticalUpdateInstall -int 1
configure com.apple.SoftwareUpdate ConfigDataInstall -int 1

# Download and install app updates
configure com.apple.commerce.plist AutoUpdateRestartRequired -bool true
configure com.apple.commerce.plist AutoUpdate -bool true

# Keep indicator of available updates on Settings icon
configure com.apple.systempreferences AttentionPrefBundleIDs 1


###############################################################################
# User interface
###############################################################################

# Disable transparency in the menu bar and elsewhere
configure com.apple.universalaccess reduceTransparency -bool true

# Set highlight color to green
configure -g AppleHighlightColor -string "0.764700 0.976500 0.568600"

# Always show scrollbars
configure -g AppleShowScrollBars -string Always

# Set sidebar icon size to medium
configure -g NSTableViewDefaultSizeMode -int 2

# Adjust toolbar title rollover delay
configure -g NSToolbarTitleViewRolloverDelay -float 0.001

# Increase window resize speed for Cocoa applications
configure -g NSWindowResizeTime -float 0.001

# Disable the over-the-top focus ring animation
configure -g NSUseAnimatedFocusRing -bool false

# Disable window animations
configure -g NSAutomaticWindowAnimationsEnabled -bool false

# Disable quicklook animations
configure -g QLPanelAnimationDuration -float 0.001


###############################################################################
# Panels, Pop-ups & Dialogs
###############################################################################

# Expand save and print panels by default
configure -g NSNavPanelExpandedStateForSaveMode -bool true
configure -g NSNavPanelExpandedStateForSaveMode2 -bool true
configure -g PMPrintingExpandedStateForPrint -bool true
configure -g PMPrintingExpandedStateForPrint2 -bool true

# Automatically quit printer app once the print jobs complete
configure com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Prevent any action when inserting a cd/dvd (blank or not, any content)
configure com.apple.digihub com.apple.digihub.blank.cd.appeared -dict action -int 1
configure com.apple.digihub com.apple.digihub.blank.dvd.appeared -dict action -int 1
configure com.apple.digihub com.apple.digihub.cd.music.appeared -dict action -int 1
configure com.apple.digihub com.apple.digihub.cd.picture.appeared -dict action -int 1
configure com.apple.digihub com.apple.digihub.dvd.video.appeared -dict action -int 1

# Prevent Photos from opening automatically when devices are plugged in
configure com.apple.ImageCapture disableHotPlug -bool true

# Save screenshots to the desktop, as PNGs, without shadow, and show 30s thumb
# (options: BMP, GIF, JPG, PDF, TIFF)
configure com.apple.screencapture type -string png
configure com.apple.screencapture disable-shadow -bool true
configure com.apple.screencapture location -string "${HOME}/Desktop"
configure com.apple.screencaptureui thumbnailExpiration -float 30

# Set Help Viewer windows to non-floating mode
configure com.apple.helpviewer DevMode -bool true

# Disable the crash reporter
configure com.apple.CrashReporter DialogType -string none

# Disable the “Are you sure you want to open this application?” dialog
configure com.apple.LaunchServices LSQuarantine -bool false


###############################################################################
# Text & Input
###############################################################################

# Fix for ancient UTF-8 bug in QuickLook
echo "0x08000100:0" > ~/.CFUserTextEncoding

# Display ASCII control characters using caret notation in standard text views
configure -g NSTextShowsControlCharacters -bool true

# Disable 'smart' (auto) corrections, capitalization, periods, dashes, quotes
configure -g NSAutomaticCapitalizationEnabled -bool false
configure -g NSAutomaticDashSubstitutionEnabled -bool false
configure -g NSAutomaticPeriodSubstitutionEnabled -bool false
configure -g NSAutomaticQuoteSubstitutionEnabled -bool false
configure -g NSAutomaticSpellingCorrectionEnabled -bool false

# Use plain text mode with UTF-8 in TextEdit
configure com.apple.TextEdit RichText -int 0
configure com.apple.TextEdit PlainTextEncoding -int 4
configure com.apple.TextEdit PlainTextEncodingForWrite -int 4

# Use Secure Keyboard Entry, with UTF-8, and no line marks, in Terminal
configure com.apple.terminal SecureKeyboardEntry -bool true
configure com.apple.terminal StringEncodings -array 4
configure com.apple.Terminal ShowLineMarks -int 0


###############################################################################
# Mouse & keyboard
###############################################################################

# Sets the mouse speed to 3
configure -g com.apple.mouse.scaling 3

# Sets the bluetooth & multi-touch mouse to two-button mode
configure com.apple.AppleMultitouchMouse.plist MouseButtonMode -string TwoButton
configure com.apple.driver.AppleBluetoothMultitouch.mouse MouseButtonMode -string TwoButton

# Sets the trackpad speed to 3
configure -g com.apple.trackpad.scaling 3

# Enable tap-to-click trackpad
configure -g com.apple.mouse.tapBehavior -int 1
configure com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

# Map bottom right trackpad corner to right-click
# configure -g com.apple.trackpad.enableSecondaryClick -bool true
# configure -g com.apple.trackpad.trackpadCornerClickBehavior -int 1
# configure com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
# configure com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2

# Disable “natural” (Lion-style) scrolling
# configure -g com.apple.swipescrolldirection -bool false

# Enable full keyboard access for all controls (e.g. Tab in modal dialogs)
configure -g AppleKeyboardUIMode -int 3

# Use Ctrl + scroll to zoom, and follow keyboard focus while zoomed in
configure com.apple.universalaccess closeViewZoomFollowsFocus -bool true
configure com.apple.universalaccess closeViewScrollWheelToggle -bool true
configure com.apple.universalaccess HIDScrollZoomModifierMask -int 262144

# Disable press-and-hold in favor of fast key repeat rate
configure -g ApplePressAndHoldEnabled -bool false
configure -g InitialKeyRepeat -int 10
configure -g KeyRepeat -int 1


###############################################################################
# Energy saving                                                               #
###############################################################################

# Restart automatically on power loss, or if the computer freezes
pmset -a autorestart 1

# Enable lid wakeup
pmset -a lidwake 1

# Sleep display after 15 minutes
pmset -a displaysleep 15

# Sleep disk after 30 minutes
# pmset -a disksleep 30

# Sleep machine after 5 minutes on battery, never while charging
pmset -b sleep 5
pmset -c sleep 0

# Standby to hibernation after 1h, by storing and powering off RAM
pmset -a standbydelay 3600
pmset -a hibernatemode 25

# Disable waking on network or modem ring
pmset -a womp 0
pmset -a ring 0

# Disable Resume system-wide
configure com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false

# Require password immediately after sleep or screen saver begins
configure com.apple.screensaver askForPassword -int 1
configure com.apple.screensaver askForPasswordDelay -int 0


###############################################################################
# Finder
###############################################################################

# Show the ~/Library & /Volumes folders
chflags nohidden /Volumes
chflags nohidden ~/Library
xattr -d com.apple.FinderInfo ~/Library

# Enable spring loading for directories, without delay
configure -g com.apple.springing.enabled -bool true
configure -g com.apple.springing.delay -float 0.001

# Show all file extensions
configure -g AppleShowAllExtensions -bool true

# Show hidden files
configure com.apple.Finder AppleShowAllFiles -bool true

# Disable the warning when changing a file extension
configure com.apple.Finder FXEnableExtensionChangeWarning -bool false

# Expand the General, Open with, and Sharing & Permissions info panes
configure com.apple.Finder FXInfoPanesExpanded -dict \
  General -bool true \
  OpenWith -bool true \
  Privileges -bool true

# Set default view style to list
# Codes are: `icnv`, `clmv`, `Flwv`, `Nlsv`)
configure com.apple.Finder FXPreferredViewStyle -string Nlsv

# Set default search location to current folder
# Codes: `SCcf`, ... ?
configure com.apple.Finder FXDefaultSearchScope -string SCcf

# Set default location for new Finder to Home
# Codes are: `PfDe`, `PfHm`, `PfLo`
configure com.apple.Finder NewWindowTarget -string PfHm
configure com.apple.Finder NewWindowTargetPath -string "file://${HOME}/"

# Disable Finder animations
configure com.apple.Finder DisableAllAnimations -bool true

# Show status bar & path bar
configure com.apple.Finder ShowStatusBar -bool true
configure com.apple.Finder ShowPathbar -bool true

# Display full POSIX path as window title
configure com.apple.Finder _FXShowPosixPathInTitle -bool true

# Keep folders on top when sorting by name
configure com.apple.Finder _FXSortFoldersFirst -bool true

# Disable the warning before emptying the Trash
configure com.apple.Finder WarnOnEmptyTrash -bool false

# Allow quitting Finder with ⌘ + Q
configure com.apple.Finder QuitMenuItem -bool true

# Show mounted paths on the desktop
configure com.apple.Finder ShowExternalHardDrivesOnDesktop -bool true
configure com.apple.Finder ShowHardDrivesOnDesktop -bool true
configure com.apple.Finder ShowMountedServersOnDesktop -bool true
configure com.apple.Finder ShowRemovableMediaOnDesktop -bool true

# Automatically open a new Finder window when a volume is mounted
configure com.apple.Finder OpenWindowForNewRemovableDisk -bool true
configure com.apple.frameworks.diskimages auto-open-ro-root -bool true
configure com.apple.frameworks.diskimages auto-open-rw-root -bool true

# Disable disk image verification
# configure com.apple.frameworks.diskimages skip-verify -bool true
# configure com.apple.frameworks.diskimages skip-verify-locked -bool true
# configure com.apple.frameworks.diskimages skip-verify-remote -bool true

# Avoid creating .DS_Store files on network or USB volumes
configure com.apple.desktopservices DSDontWriteUSBStores -bool true
configure com.apple.desktopservices DSDontWriteNetworkStores -bool true

# In icon views:
# - Increase icon size
# - Increase grid spacing
# - Enable snap-to-grid
# - Show item info to the right of icons
edit com.apple.Finder \
  -c "Set :DesktopViewSettings:IconViewSettings:showItemInfo true" \
  -c "Set :FK_StandardViewSettings:IconViewSettings:showItemInfo true" \
  -c "Set :StandardViewSettings:IconViewSettings:showItemInfo true" \
  -c "Set :DesktopViewSettings:IconViewSettings:labelOnBottom false" \
  -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" \
  -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" \
  -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" \
  -c "Set :DesktopViewSettings:IconViewSettings:gridSpacing 100" \
  -c "Set :FK_StandardViewSettings:IconViewSettings:gridSpacing 100" \
  -c "Set :StandardViewSettings:IconViewSettings:gridSpacing 100" \
  -c "Set :DesktopViewSettings:IconViewSettings:iconSize 80" \
  -c "Set :FK_StandardViewSettings:IconViewSettings:iconSize 80" \
  -c "Set :StandardViewSettings:IconViewSettings:iconSize 80"


###############################################################################
# Dock, Dashboard, and hot corners                                            #
###############################################################################

# Wipe all (default) app icons from the Dock
configure com.apple.dock persistent-apps -array

# Show only open applications in the Dock
configure com.apple.dock static-only -bool true

# Disable highlight hover effect for the grid view of a dock stack
configure com.apple.dock mouse-over-hilite-stack -bool false

# Set the icon size of Dock items to 24 pixels
configure com.apple.dock tilesize -int 24

# Minimize windows into their application’s icon
configure com.apple.dock minimize-to-application -bool true

# Enable spring loading for all Dock items
configure com.apple.dock enable-spring-load-actions-on-all-items -bool true

# Disable indicator lights for open applications in the Dock
configure com.apple.dock show-process-indicators -bool false

# Disable Dashboard, and don't show it as a Space
configure com.apple.dashboard mcx-disabled -bool true
configure com.apple.dock dashboard-in-overlay -bool true

# Don’t automatically rearrange Spaces based on most recent use
configure com.apple.dock mru-spaces -bool false

# Remove Dock animations
configure com.apple.dock autohide-delay -float 0.001
configure com.apple.dock autohide-time-modifier -float 0.001
configure com.apple.dock expose-animation-duration -float 0.001
configure com.apple.dock launchanim -bool false
configure com.apple.dock mineffect -string none

# Automatically hide and show the Dock
configure com.apple.dock autohide -bool true

# Make Dock icons of hidden applications translucent
configure com.apple.dock showhidden -bool true

# Don’t show recent applications in Dock
configure com.apple.dock show-recents -bool false

# Disable "hot corners"
configure com.apple.dock wvous-tl-corner -int 0
configure com.apple.dock wvous-tl-modifier -int 0
configure com.apple.dock wvous-tr-corner -int 0
configure com.apple.dock wvous-tr-modifier -int 0
configure com.apple.dock wvous-bl-corner -int 0
configure com.apple.dock wvous-bl-modifier -int 0
configure com.apple.dock wvous-br-corner -int 0
configure com.apple.dock wvous-br-modifier -int 0


###############################################################################
# Safari & WebKit                                                             #
###############################################################################

# Enable “Do Not Track”
# configure com.apple.Safari SendDoNotTrackHTTPHeader -bool true

# Don’t send search queries to Apple
configure com.apple.Safari UniversalSearchEnabled -bool false
configure com.apple.Safari SuppressSearchSuggestions -bool true

# Warn about fraudulent websites
configure com.apple.Safari WarnAboutFraudulentWebsites -bool true

# Prevent Safari from opening ‘safe’ files automatically after downloading
configure com.apple.Safari AutoOpenSafeDownloads -bool false

# Disable Safari’s thumbnail cache for History and Top Sites
configure com.apple.Safari DebugSnapshotsUpdatePolicy -int 2

# Update extensions automatically
configure com.apple.Safari InstallExtensionUpdatesAutomatically -bool true

# Disable plug-ins
configure com.apple.Safari WebKitPluginsEnabled -bool false
configure com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2PluginsEnabled -bool false

# Disable Java
configure com.apple.Safari WebKitJavaEnabled -bool false
configure com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled -bool false
configure com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabledForLocalFiles -bool false

# Block pop-up windows
configure com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -bool false
configure com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically -bool false

# Disable AutoFill
configure com.apple.Safari AutoFillFromAddressBook -bool false
configure com.apple.Safari AutoFillPasswords -bool false
configure com.apple.Safari AutoFillCreditCardData -bool false
configure com.apple.Safari AutoFillMiscellaneousForms -bool false

# Disable auto-playing video
configure com.apple.Safari WebKitMediaPlaybackAllowsInline -bool false
configure com.apple.SafariTechnologyPreview WebKitMediaPlaybackAllowsInline -bool false
configure com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2AllowsInlineMediaPlayback -bool false
configure com.apple.SafariTechnologyPreview com.apple.Safari.ContentPageGroupIdentifier.WebKit2AllowsInlineMediaPlayback -bool false


###############################################################################
# Spotlight                                                                   #
###############################################################################

# Hide Spotlight tray-icon (and subsequent helper)
chmod 600 /System/Library/CoreServices/Search.bundle/Contents/MacOS/Search

# Disable Spotlight for any volume (here: root)
mdutil -i off /

# Disable Spotlight indexing for any (not yet indexed) volume that gets mounted
# configure /.Spotlight-V100/VolumeConfiguration Exclusions -array "/Volumes"

# Change indexing order and disable some search results
# configure com.apple.spotlight orderedItems -array \
# 	'{"enabled" = 1;"name" = "APPLICATIONS";}' \
# 	'{"enabled" = 1;"name" = "SYSTEM_PREFS";}' \
# 	'{"enabled" = 1;"name" = "DIRECTORIES";}' \
# 	'{"enabled" = 1;"name" = "PDF";}' \
# 	'{"enabled" = 1;"name" = "FONTS";}' \
# 	'{"enabled" = 0;"name" = "DOCUMENTS";}' \
# 	'{"enabled" = 0;"name" = "MESSAGES";}' \
# 	'{"enabled" = 0;"name" = "CONTACT";}' \
# 	'{"enabled" = 0;"name" = "EVENT_TODO";}' \
# 	'{"enabled" = 0;"name" = "IMAGES";}' \
# 	'{"enabled" = 0;"name" = "BOOKMARKS";}' \
# 	'{"enabled" = 0;"name" = "MUSIC";}' \
# 	'{"enabled" = 0;"name" = "MOVIES";}' \
# 	'{"enabled" = 0;"name" = "PRESENTATIONS";}' \
# 	'{"enabled" = 0;"name" = "SPREADSHEETS";}' \
# 	'{"enabled" = 0;"name" = "SOURCE";}' \
# 	'{"enabled" = 0;"name" = "MENU_DEFINITION";}' \
# 	'{"enabled" = 0;"name" = "MENU_OTHER";}' \
# 	'{"enabled" = 0;"name" = "MENU_CONVERSION";}' \
# 	'{"enabled" = 0;"name" = "MENU_EXPRESSION";}' \
# 	'{"enabled" = 0;"name" = "MENU_WEBSEARCH";}' \
# 	'{"enabled" = 0;"name" = "MENU_SPOTLIGHT_SUGGESTIONS";}'

# Load new settings, enable indexing for root, and rebuild index from scratch
killall mds > /dev/null 2>&1
# mdutil -i on / > /dev/null
mdutil -E / > /dev/null


###############################################################################
# Siri
###############################################################################

# Disable siri
configure com.apple.assistant.support "Assistant Enabled" -int 0


###############################################################################
# Display & Audio
###############################################################################

# Enable HiDPI display modes
configure com.apple.windowserver DisplayResolutionEnabled -bool true

# Enable subpixel font rendering on non-Apple LCDs
configure -g AppleFontSmoothing -int 1

# Increase sound quality for Bluetooth headphones/headsets
configure com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40


###############################################################################
# App management
###############################################################################

# Disable automatic termination of inactive apps
configure -g NSDisableAutomaticTermination -bool true

# Show all processes in Activity Monitor
configure com.apple.ActivityMonitor ShowCategory -int 0

# Show the main window when launching Activity Monitor
configure com.apple.ActivityMonitor OpenMainWindow -bool true

# Sort Activity Monitor results by CPU usage, and visualise in Dock icon
configure com.apple.ActivityMonitor SortColumn -string "CPUUsage"
configure com.apple.ActivityMonitor SortDirection -int 0
# configure com.apple.ActivityMonitor IconType -int 5


###############################################################################
# Storage
###############################################################################

# Save to disk (not to iCloud) by default
configure -g NSDocumentSaveNewDocumentsToCloud -bool false

# Turn off the icloud login prompt
configure com.apple.SetupAssistant DidSeeCloudSetup -bool true
configure com.apple.SetupAssistant GestureMovieSeen -string none
configure com.apple.SetupAssistant LastSeenCloudProductVersion -string "26.2"

# Enable the debug menu in Disk Utility
configure com.apple.DiskUtility DUDebugMenuEnabled -bool true
configure com.apple.DiskUtility advanced-image-options -bool true

# Prevent Time Machine from prompting to use new hard drives as backup volume
configure com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# Disable local Time Machine backups
tmutil disablelocal

# Disable Time Machine
tmutil disable

# Keep low priority I/O throttled
sysctl debug.lowpri_throttle_enabled=1

# Restrict the system and userwide umask
# launchctl config system umask 022 # default
# launchctl config user umask 022 # default

# Set the system and userwide PATH
# launchctl config system path "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"


###############################################################################
# Network
###############################################################################

# Enable firewall (block all; stealth mode; no whitelisting)
/usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on
/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
/usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
/usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on
/usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned off
/usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp off

# Stop the sending of diagnostic info to apple
defaults write  "/Library/Application Support/CrashReporter/DiagnosticMessagesHistory" AutoSubmit -bool false

# Enable AirDrop over Ethernet and on unsupported Macs running Lion
# configure com.apple.NetworkBrowser BrowseAllInterfaces -bool true

# Enable Mail Privacy Protection
configure com.apple.mail PrivacyProtectionEnabled -bool true

# Prevent bonjour service advertadvertisements broadcasting
configure com.apple.mDNSResponder.plist NoMulticastAdvertisements -bool true

# Disable iCloud Private Relay
configure com.apple.networkextension.plist PrivateRelayEnabled -bool false

# Disable infrared reciever
configure com.apple.driver.AppleIRController DeviceEnabled -bool false

# Disable bluetooth
# configure com.apple.Bluetooth ControllerPowerState -int -0


###############################################################################
# Agents & daemons
###############################################################################

#
# AGENTS
#

disable com.apple.AddressBook.abd
disable com.apple.AddressBook.AssistantService
disable com.apple.AddressBook.SourceSync
disable com.apple.adprivacyd
disable com.apple.AirPortBaseStationAgent
disable com.apple.AMP*
disable com.apple.AMPArtworkAgent
disable com.apple.ams*
disable com.apple.amsengagementd
disable com.apple.amsondevicestoraged
disable com.apple.analyticsagent
disable com.apple.ap.adservicesd
disable com.apple.appleseed.seedusaged
disable com.apple.appleseed.seedusaged.postinstall
disable com.apple.appleseed*
disable com.apple.arkitd
disable com.apple.ask*
disable com.apple.assessmentagent
disable com.apple.AssetCache*
disable com.apple.assistant_cdmd
disable com.apple.assistant_service
disable com.apple.assistantd
disable com.apple.AssistiveControl
disable com.apple.avconferenced
disable com.apple.BiomeAgent
disable com.apple.biomesyncd
disable com.apple.bird
disable com.apple.bookassetd
disable com.apple.bookdatastored
disable com.apple.cache_delete
disable com.apple.calaccessd
disable com.apple.calendar.*
disable com.apple.callhistory*
disable com.apple.callintelligenced
disable com.apple.cloud
disable com.apple.cloudphotod
disable com.apple.cloudsettingssyncagent
disable com.apple.cmfsyncagent
disable com.apple.cmio.ContinuityCaptureAgent
disable com.apple.cmio*
disable com.apple.CommCenter
disable com.apple.commerce
disable com.apple.companiond
disable com.apple.contacts.*
disable com.apple.ContextStoreAgent
disable com.apple.contextstored
disable com.apple.continuityd
disable com.apple.diagnosticextensionsd
disable com.apple.diagnostics_agent
disable com.apple.diagnostics*
disable com.apple.diagnosticspushd
disable com.apple.DictationIM
disable com.apple.duetexpertd
disable com.apple.DwellControl
disable com.apple.email.maild
disable com.apple.enhancedloggingd
disable com.apple.exchange.exchangesyncd
disable com.apple.facetimemessagestored
disable com.apple.familycircled
disable com.apple.familycontrols.useragent
disable com.apple.FamilyControlsAgent
disable com.apple.familynotificationd
disable com.apple.FeatureAccessAgent
disable com.apple.feedbackd
disable com.apple.financed
disable com.apple.findmy*
disable com.apple.findmylocateagent
disable com.apple.findmymacmessenger
disable com.apple.followup*
disable com.apple.frauddefensed
disable com.apple.GameCenter
disable com.apple.gamed
disable com.apple.GameOverlayUI
disable com.apple.GamePolicyAgent
disable com.apple.gamesaved
disable com.apple.generativeexperiencesd
disable com.apple.geoanalyticsd
disable com.apple.geod
disable com.apple.geod*
disable com.apple.geodMachServiceBridge
disable com.apple.handoffd
disable com.apple.helpd
disable com.apple.homed
disable com.apple.homeenergyd
disable com.apple.homeeventsd
disable com.apple.icloud.findmydeviced.findmydevice-user-agent
disable com.apple.icloud.searchpartyuseragent
disable com.apple.icloud*
disable com.apple.icloudmailagent
disable com.apple.iCloudNotification*
disable com.apple.idsfoundation.IDSRemoteURLConnectionAgent
disable com.apple.idsfoundation*
disable com.apple.im*
disable com.apple.imagent
disable com.apple.imautomatichistorydeletionagent
disable com.apple.imcore.imtransferagent
disable com.apple.imklaunchagent
disable com.apple.IMLoggingAgent
disable com.apple.imtransferagent
disable com.apple.inputanalyticsd
disable com.apple.intelligence*
disable com.apple.intelligencecontextd
disable com.apple.intelligenceflowd
disable com.apple.intelligenceplatformd
disable com.apple.intelligencetasksd
disable com.apple.itunecloudd
disable com.apple.iTunesHelper.launcher
disable com.apple.java.updateSharing
disable com.apple.knowledge-agent
disable com.apple.knowledge*
disable com.apple.knowledgeconstructiond
disable com.apple.LinkedNotesUIService
disable com.apple.location*
disable com.apple.locationaccessstored
disable com.apple.lookup.shared
disable com.apple.macos.studentd
disable com.apple.Maps.*
disable com.apple.maps.destinationd
disable com.apple.Maps.mapspushd
disable com.apple.Maps.mapssyncd
disable com.apple.Maps.pushdaemon
disable com.apple.mbproximityhelper
disable com.apple.mediaanalysisd
disable com.apple.mediaanalysisd-access
disable com.apple.mediacontinuityd
disable com.apple.mediaremoteagent
disable com.apple.mediastream.mstreamd
disable com.apple.MENotificationService
disable com.apple.milod
disable com.apple.mlhostd
disable com.apple.mlruntimed
disable com.apple.ModelCatalogAgent
disable com.apple.musickitd
disable com.apple.naturallanguaged
disable com.apple.navd
disable com.apple.news.subscriptiond
disable com.apple.news.todayd
disable com.apple.newsd
disable com.apple.nexusd
disable com.apple.notes.exchangenotesd
disable com.apple.nowplayingtouchui
disable com.apple.parentalcontrols.check
disable com.apple.parsec-fbf
disable com.apple.parsecd
disable com.apple.passd
disable com.apple.peopled
disable com.apple.photoanalysisd
disable com.apple.photolibraryd
disable com.apple.podcasts.PodcastContentService
disable com.apple.proactived
disable com.apple.promotedcontentd
disable com.apple.rapportd
disable com.apple.RapportUIAgent
disable com.apple.rcd
disable com.apple.remindd
disable com.apple.RemoteDesktop.agent
disable com.apple.RemoteManagementAgent
disable com.apple.replayd
disable com.apple.replicatord
disable com.apple.reversetemplated
disable com.apple.routined
disable com.apple.Safari.History
disable com.apple.Safari.PasswordBreachAgent
disable com.apple.Safari.SafeBrowsing.Service
disable com.apple.Safari*
disable com.apple.SafariBookmarksSyncAgent
disable com.apple.SafariHistoryServiceAgent
disable com.apple.SafariLaunchAgent
disable com.apple.ScreenReaderUIServer
disable com.apple.ScreenTimeAgent
disable com.apple.ScreenTimeApp
disable com.apple.screentimed
disable com.apple.searchparty*
disable com.apple.securemessagingagent
disable com.apple.sharingd
disable com.apple.shazamd
disable com.apple.sidecar-display-agent
disable com.apple.sidecar-hid-relay
disable com.apple.sidecar-relay
disable com.apple.sidecar-service
disable com.apple.sidecar*
disable com.apple.Siri.agent
disable com.apple.siri.context.service
disable com.apple.siri.distributed-evaluation
disable com.apple.siri*
disable com.apple.siriactionsd
disable com.apple.siriinferenced
disable com.apple.siriknowledged
disable com.apple.SiriNCService
disable com.apple.sirittsd
disable com.apple.SiriTTSTrainingAgent
disable com.apple.soagent
disable com.apple.sociallayerd
disable com.apple.SocialPushAgent
disable com.apple.speech.*
disable com.apple.sportsd
disable com.apple.Spotlight
disable com.apple.spotlight.index
disable com.apple.spotlightlightd
disable com.apple.SpotlightNetHelper
disable com.apple.StatusKitAgent
disable com.apple.STMUIHelper
disable com.apple.stocks.widget
disable com.apple.stocksd
disable com.apple.studentd
disable com.apple.suggestd
disable com.apple.Suggestions
disable com.apple.synapse.contentlinkingd
disable com.apple.sync*
disable com.apple.textunderstandingd
disable com.apple.tipsd
disable com.apple.triald
disable com.apple.tvremoteui
disable com.apple.UsageTrackingAgent
disable com.apple.videosubscriptionsd
disable com.apple.voicebankingd
disable com.apple.voicememod
disable com.apple.VoiceOver
disable com.apple.walletd
disable com.apple.watchlistd
disable com.apple.weather.widget
disable com.apple.weatherd
disable com.apple.webinspectord
disable com.apple.webprivacyd

#
# DAEMONS
#

# Analytics / diagnostics (upload side)
disable com.apple.ScreenTimeAgent
disable com.apple.SubmitDiagInfo
disable com.apple.analyticsd
disable com.apple.wifianalyticsd
disable com.apple.applessdstatistics
disable com.apple.audioanalyticsd
disable com.apple.ecosystemanalyticsd
disable com.apple.osanalytics.osanalyticshelper

# Find My (after disabling via Settings!)
disable com.apple.findmymacd
disable com.apple.findmymacmessenger
disable com.apple.findmy.findmybeaconingd

# AppleSeed, betas, feedback
disable com.apple.appleseed.fbahelperd
disable com.apple.betaenrollmentd

# Asset/peer caching (if not used)
disable com.apple.AssetCacheManagerService
disable com.apple.AssetCache.builtin

# Remote management, screen sharing, MDM (if unused)
disable com.apple.screensharing
disable com.apple.remotemanagementd
disable com.apple.RemoteDesktop.PrivilegeProxy

# File sharing (Samba, NFS)
disable com.apple.smbd
disable com.apple.nfsd
disable com.apple.lockd
disable com.apple.statd.notify
disable com.apple.AppleFileServer

# Legacy (DVD, AFP, FTP)
disable com.apple.ftp-proxy
disable com.apple.dvdplayback.setregion
disable com.apple.afpfs_afpLoad

# Others
disable com.apple.musicd
disable com.apple.locationd
disable com.apple.familycontrols
disable com.apple.GameController.gamecontrollerd

# =============================================================================

read -r -p "[DONE] The machine will now reboot. Press ENTER to continue..."

reboot
exit
