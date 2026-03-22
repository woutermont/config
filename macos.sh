#!/usr/bin/env bash

ADMIN="admin"
USER="termontwouter"

LANG="en"
REGION="US"
VALUTA="EUR"
METRIC="true"
UNIT="Centimeters"
TIME_ZONE="Europe/Paris"
TIME_SERVER="pool.ntp.org"

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

set +x
set -euo pipefail

disable() {
  local SERVS=(
    "system/$1"
    "user/$UID_ADMIN/$1"
    "user/$UID_USER/$1"
    "gui/$UID_ADMIN/$1"
    "gui/$UID_USER/$1"
  )
  for SRV in "${SERVS[@]}"; do
    if launchctl print "$SRV" >/dev/null 2>&1; then
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
    "/Users/$ADMIN/Library/Preferences/$1"
    "/Users/$USER/Library/Preferences/$1"
  )
  for PRF in "${PREFS[@]}"; do
    if [[ -f "$PRF.plist" ]]; then
      defaults write "$PRF" "$@"
    fi
  done
}

clear

# /Library/Preferences/Audio/com.apple.audio.DeviceSettings.plist
# /Library/Preferences/Audio/com.apple.audio.SystemSettings.plist
# /Library/Preferences/Logging/Subsystems/com.apple.WebBookmarks.plist
# /Library/Preferences/Logging/Subsystems/com.apple.WebInspector.plist
# /Library/Preferences/OpenDirectory/Configurations/Contacts.plist
# /Library/Preferences/OpenDirectory/Configurations/Search.plist
# /Library/Preferences/OpenDirectory/opendirectoryd.plist
# /Library/Preferences/SystemConfiguration/NetworkInterfaces.plist
# /Library/Preferences/SystemConfiguration/com.apple.AutoWake.plist
# /Library/Preferences/SystemConfiguration/com.apple.Boot.plist
# /Library/Preferences/SystemConfiguration/com.apple.accounts.exists.plist
# /Library/Preferences/SystemConfiguration/com.apple.airport.preferences.plist
# /Library/Preferences/SystemConfiguration/com.apple.nat.plist
# /Library/Preferences/SystemConfiguration/com.apple.network.eapolclient.configuration.plist
# /Library/Preferences/SystemConfiguration/com.apple.smb.server.plist
# /Library/Preferences/SystemConfiguration/com.apple.vmnet.plist
# /Library/Preferences/SystemConfiguration/preferences-pre-upgrade-new-target.pli
# /Library/Preferences/SystemConfiguration/preferences-pre-upgrade-source.plist
# /Library/Preferences/SystemConfiguration/preferences.plist
# /Library/Preferences/com.apple.AppleFileServer.plist
# /Library/Preferences/com.apple.AssetCache.plist
# /Library/Preferences/com.apple.BezelServices.plist
# /Library/Preferences/com.apple.Bluetooth.plist
# /Library/Preferences/com.apple.ByteRangeLocking.plist
# /Library/Preferences/com.apple.FindMyMac.plist
# /Library/Preferences/com.apple.HIToolbox.plist
# /Library/Preferences/com.apple.MCX.plist
# /Library/Preferences/com.apple.PowerManagement.F083DAD1-C5AB-5DA1-AADA-EDF095E95442.plist
# /Library/Preferences/com.apple.PowerManagement.plist
# /Library/Preferences/com.apple.SoftwareUpdate.plist
# /Library/Preferences/com.apple.TextInputMenu.plist
# /Library/Preferences/com.apple.TimeMachine.plist
# /Library/Preferences/com.apple.apsd.plist
# /Library/Preferences/com.apple.biometrickitd.plist
# /Library/Preferences/com.apple.captive.plist
# /Library/Preferences/com.apple.commerce.plist
# /Library/Preferences/com.apple.dock.plist
# /Library/Preferences/com.apple.driver.AppleIRController.plist
# /Library/Preferences/com.apple.gridDataServices.plist
# /Library/Preferences/com.apple.iclouddrive.features.plist
# /Library/Preferences/com.apple.keyboardtype.plist
# /Library/Preferences/com.apple.loginwindow.plist
# /Library/Preferences/com.apple.mdmclient.plist
# /Library/Preferences/com.apple.networkd.networknomicon.plist
# /Library/Preferences/com.apple.networkd.plist
# /Library/Preferences/com.apple.networkd.sysctl.plist
# /Library/Preferences/com.apple.networkextension.control.plist
# /Library/Preferences/com.apple.networkextension.necp.plist
# /Library/Preferences/com.apple.networkextension.plist
# /Library/Preferences/com.apple.networkextension.uuidcache.plist
# /Library/Preferences/com.apple.noticeboard.plist
# /Library/Preferences/com.apple.powerd.charging.plist
# /Library/Preferences/com.apple.powerlogHelperd.plist
# /Library/Preferences/com.apple.powerlogd.plist
# /Library/Preferences/com.apple.security.appsandbox.plist
# /Library/Preferences/com.apple.security.plist
# /Library/Preferences/com.apple.security.systemidentities.plist
# /Library/Preferences/com.apple.systemprefs.plist
# /Library/Preferences/com.apple.timezone.auto.plist
# /Library/Preferences/com.apple.updatesettings.plist
# /Library/Preferences/com.apple.wifi.known-networks.plistno
# /Library/Preferences/com.apple.windowserver.plist
# /Library/Preferences/com.microsoft.autoupdate2.plist
# /Library/Preferences/com.microsoft.teams.plist
# /Library/Preferences/org.cups.printers.plist


###############################################################################
# USER SETUP
###############################################################################

# create non-privileged user
sysadminctl -addUser $USER -password "-" # prompt
sysadminctl -secureTokenOn $USER
sysadminctl -secureTokenStatus $USER

# remove guest/admin from login screen, and disable automatic login
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
defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "$DEVICE"
scutil --set ComputerName $COMPUTER_NAME
scutil --set LocalHostName $LOCAL_NAME
scutil --set HostName $HOST_NAME


###############################################################################
# Session management
###############################################################################

configure com.apple.AppleFileServer guestAccess -bool false
configure com.apple.smb.server AllowGuestAccess -bool false


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

# Prevent Photos from opening automatically when devices are plugged in
configure com.apple.ImageCapture disableHotPlug -bool true

# Show 30s thumbnails
configure com.apple.screencaptureui thumbnailExpiration -float 30

# Set Help Viewer windows to non-floating mode
configure com.apple.helpviewer DevMode -bool true

# Disable the crash reporter
configure com.apple.CrashReporter DialogType -string none


###############################################################################
# Text & Input
###############################################################################

# Display ASCII control characters using caret notation in standard text views
configure -g NSTextShowsControlCharacters -bool true

# Disable 'smart' (auto) corrections, capitalization, periods, dashes, quotes
configure -g NSAutomaticCapitalizationEnabled -bool false
configure -g NSAutomaticDashSubstitutionEnabled -bool false
configure -g NSAutomaticPeriodSubstitutionEnabled -bool false
configure -g NSAutomaticQuoteSubstitutionEnabled -bool false
configure -g NSAutomaticSpellingCorrectionEnabled -bool false

# Use Secure Keyboard Entry, with UTF-8, and no line marks, in Terminal
configure com.apple.Terminal SecureKeyboardEntry -bool true
configure com.apple.Terminal StringEncodings -array 4
configure com.apple.Terminal ShowLineMarks -int 0


###############################################################################
# Mouse & keyboard
###############################################################################

# Sets the mouse speed to 3
configure -g com.apple.mouse.scaling 3

# Sets the bluetooth & multi-touch mouse to two-button mode
configure com.apple.AppleMultitouchMouse MouseButtonMode -string TwoButton
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
configure com.apple.frameworks.diskimages auto-open-ro-root -bool true
configure com.apple.frameworks.diskimages auto-open-rw-root -bool true

# Disable disk image verification
# configure com.apple.frameworks.diskimages skip-verify -bool true
# configure com.apple.frameworks.diskimages skip-verify-locked -bool true
# configure com.apple.frameworks.diskimages skip-verify-remote -bool true

# Avoid creating .DS_Store files on network or USB volumes
configure com.apple.desktopservices DSDontWriteUSBStores -bool true
configure com.apple.desktopservices DSDontWriteNetworkStores -bool true


###############################################################################
# Dock, Dashboard, and hot corners                                            #
###############################################################################

# Disable Dashboard
configure com.apple.dashboard mcx-disabled -bool true


###############################################################################
# Spotlight                                                                   #
###############################################################################

# Enable indexing for root, and rebuild index from scratch
mdutil -i on / > /dev/null
mdutil -E / > /dev/null


###############################################################################
# Display & Audio
###############################################################################

# Enable HiDPI display modes
configure com.apple.windowserver DisplayResolutionEnabled -bool true

# Enable subpixel font rendering on non-Apple LCDs
configure -g AppleFontSmoothing -int 1


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

# Enable the debug menu in Disk Utility
configure com.apple.DiskUtility DUDebugMenuEnabled -bool true
configure com.apple.DiskUtility advanced-image-options -bool true

# Disable Time Machine
tmutil disable

# Restrict the system and userwide umask
# launchctl config system umask 022 # default
# launchctl config user umask 022 # default

# Set the system and userwide PATH
# launchctl config system path "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"


###############################################################################
# Network
###############################################################################

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
disable com.apple.AMPArtworkAgent
disable com.apple.amsengagementd
disable com.apple.amsondevicestoraged
disable com.apple.analyticsagent
disable com.apple.ap.adservicesd
disable com.apple.appleseed.seedusaged
disable com.apple.appleseed.seedusaged.postinstall
disable com.apple.arkitd
disable com.apple.assessmentagent
disable com.apple.assistant_cdmd
disable com.apple.assistant_service
disable com.apple.assistantd
disable com.apple.AssistiveControl
disable com.apple.BiomeAgent
disable com.apple.biomesyncd
disable com.apple.bird
disable com.apple.bookassetd
disable com.apple.bookdatastored
disable com.apple.cache_delete
disable com.apple.calaccessd
disable com.apple.callintelligenced
disable com.apple.cloud
disable com.apple.cloudphotod
disable com.apple.cloudsettingssyncagent
disable com.apple.cmfsyncagent
disable com.apple.cmio.ContinuityCaptureAgent
disable com.apple.CommCenter
disable com.apple.commerce
disable com.apple.companiond
disable com.apple.ContextStoreAgent
disable com.apple.contextstored
disable com.apple.continuityd
disable com.apple.diagnosticextensionsd
disable com.apple.diagnostics_agent
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
disable com.apple.findmylocateagent
disable com.apple.findmymacmessenger
disable com.apple.frauddefensed
disable com.apple.GameCenter
disable com.apple.gamed
disable com.apple.GameOverlayUI
disable com.apple.GamePolicyAgent
disable com.apple.gamesaved
disable com.apple.generativeexperiencesd
disable com.apple.geoanalyticsd
disable com.apple.handoffd
disable com.apple.helpd
disable com.apple.homed
disable com.apple.homeenergyd
disable com.apple.homeeventsd
disable com.apple.icloud.findmydeviced.findmydevice-user-agent
disable com.apple.icloud.searchpartyuseragent
disable com.apple.icloudmailagent
disable com.apple.idsfoundation.IDSRemoteURLConnectionAgent
disable com.apple.imagent
disable com.apple.imautomatichistorydeletionagent
disable com.apple.imcore.imtransferagent
disable com.apple.imklaunchagent
disable com.apple.IMLoggingAgent
disable com.apple.imtransferagent
disable com.apple.inputanalyticsd
disable com.apple.intelligencecontextd
disable com.apple.intelligenceflowd
disable com.apple.intelligenceplatformd
disable com.apple.intelligencetasksd
disable com.apple.itunecloudd
disable com.apple.iTunesHelper.launcher
disable com.apple.java.updateSharing
disable com.apple.knowledge-agent
disable com.apple.knowledgeconstructiond
disable com.apple.LinkedNotesUIService
disable com.apple.locationaccessstored
disable com.apple.lookup.shared
disable com.apple.macos.studentd
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
disable com.apple.SafariBookmarksSyncAgent
disable com.apple.SafariHistoryServiceAgent
disable com.apple.SafariLaunchAgent
disable com.apple.ScreenReaderUIServer
disable com.apple.ScreenTimeAgent
disable com.apple.ScreenTimeApp
disable com.apple.screentimed
disable com.apple.securemessagingagent
disable com.apple.shazamd
disable com.apple.sidecar-display-agent
disable com.apple.sidecar-hid-relay
disable com.apple.sidecar-relay
disable com.apple.sidecar-service
disable com.apple.Siri.agent
disable com.apple.siri.context.service
disable com.apple.siri.distributed-evaluation
disable com.apple.siriactionsd
disable com.apple.siriinferenced
disable com.apple.siriknowledged
disable com.apple.SiriNCService
disable com.apple.sirittsd
disable com.apple.SiriTTSTrainingAgent
disable com.apple.soagent
disable com.apple.sociallayerd
disable com.apple.SocialPushAgent
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
disable com.apple.familycontrols
disable com.apple.GameController.gamecontrollerd
disable com.apple.calendar.CalendarAgentBookmarkMigrationService
disable com.apple.contacts.postersyncd
disable com.apple.contacts.donation-agent
disable com.apple.Maps.mapssyncd
disable com.apple.Maps.mapspushd
disable com.apple.amsondevicestoraged
disable com.apple.amsaccountsd
disable com.apple.amsengagementd
disable com.apple.applespell
disable com.apple.appleseed.seedusaged
disable com.apple.appleaccountd
disable com.apple.appleidsetupd
disable com.apple.appleseed.seedusaged.postinstall
disable com.apple.AssetCache.agent
disable com.apple.AssetCacheLocatorService
disable com.apple.callhistoryd
disable com.apple.CallHistoryPluginHelper
disable com.apple.callintelligenced
disable com.apple.CallHistorySyncHelper
disable com.apple.cmio.LaunchCMIOUserExtensionsAgent
disable com.apple.cmio.ContinuityCaptureAgent
disable com.apple.diagnosticextensionsd
disable com.apple.diagnostics_agent
disable com.apple.diagnosticspushd
disable com.apple.DiagnosticsReporter
disable com.apple.findmymacmessenger
disable com.apple.findmy.findmylocateagent
disable com.apple.followupd
disable com.apple.FollowUpUI
disable com.apple.icloud.searchpartyuseragent
disable com.apple.iCloudUserNotificationsd
disable com.apple.iCloudNotificationAgent
disable com.apple.icloudmailagent
disable com.apple.iCloudHelper
disable com.apple.icloud.findmydeviced.findmydevice-user-agent
disable com.apple.syncservices.uihandler
disable com.apple.syncservices.SyncServer
disable com.apple.syncdefaultsd
disable com.apple.siri.context.service
disable com.apple.siriactionsd
disable com.apple.siriknowledged
disable com.apple.siriinferenced
disable com.apple.sirittsd
disable com.apple.sidecar-relay
disable com.apple.sidecar-display-agent
disable com.apple.SafariHistoryServiceAgent
disable com.apple.SafariBookmarksSyncAgent
disable com.apple.Safari.PasswordBreachAgent
disable com.apple.Safari.SafeBrowsing.Service
disable com.apple.SafariNotificationAgent
disable com.apple.SafariLaunchAgent
disable com.apple.Safari.History
disable com.apple.imdpersistence.IMDPersistenceAgent
disable com.apple.imklaunchagent
disable com.apple.imcore.imtransferagent
disable com.apple.imagent
disable com.apple.imautomatichistorydeletionagent
disable com.apple.idsfoundation.IDSRemoteURLConnectionAgent

# =============================================================================

read -r -p "[DONE] The machine will now reboot. Press ENTER to continue..."

reboot
exit
