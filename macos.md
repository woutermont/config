https://github.com/drduh/macOS-Security-and-Privacy-Guide

See https://jvns.ca/blog/2024/02/16/popular-git-config-options/
and https://blog.gitbutler.com/how-git-core-devs-configure-git/

https://github.com/northpolesec/santa



## Preparation

1. Start your new Mac.
1. Wait for the Setup Assistant.
1. Connect to a WiFi network.
1. Wait for activation to finish.
1. Restart your Mac.
1. Begin the setup wizard.
   1. Pick `English` (US) as language.
   1. Pick the major region in your time zone.
1. Skip data transfer.
1. In the overview, press 'Customize'.
   1. Remove any added language (except US English).
   1. Pick a universal keyboard layout (US, US Int., ABC ...).
   1. Remove all other layouts.
   1. Remove any added dictation languages (except US English).
   1. Do not enable any accessibility features.
1. Continue until account creation.
   1. Set full name and account name both to 'admin'.
   1. Pick a strong password, without a hint.
   1. Uncheck Apple password recovery.
1. Skip Apple Account signin (and confirm).
1. Accept the Terms and Conditions (and confirm).
1. Do not enable Location Services (and confirm).
1. Pick the major city in the selected region; do not use location.
1. Uncheck any analytics.
1. Skip Screen Time setup.
1. Skip Apple Intelligence setup.
1. Uncheck Ask Siri.
1. Turn on FileVault; write down the recovery key.
1. Do not enable Touch ID (and confirm).
1. Use the standard Light look.
1. Enable automatic updates.
1. Install any updates when promted.
1. Get started.


## Update the system

```
softwareupdate --install --all
softwareupdate --install-rosetta --agree-to-license
softwareupdate --schedule on
```

Print current SIP status with `csrutil status`.


# Profile configuration

`profiles install -type configuration -path myprofile.mobileconfig`


## Defaults configuration

The `defaults` commands edits plists for application domains (e.g., `~/Library/Preferences/com.apple.Safari.plist`) or the global domain (i.e., `~/Library/Preferences/.GlobalPreferences.plist`, abbreviated as `NSGlobalDomain` or the `-g` flag). For non-preference files, Apple is transitioning to manual plist editing (e.g., with `/usr/libexec/PlistBuddy -c "Set <:property:path> <value>" <plist/path>`. Expected types can be found with `defaults read-type <domain> <key>`.

`defaults domains`
`launchctl list`


## Agents and daemons

The `launchctl` command manages agents and daemons in the `system`, `user/<UID>/*`, and `gui/<UID>/*` domains. They can be listed with `launchctl print <domain>` (not legacy `list`). Services need to be loaded before running; loading and unloading is done with `launchctl bootstrap|bootout <domain>/<service>` (not legacy `load|unload`). Loaded services are automatically unloaded on (re)boot; to make loading permanent, enable or disable them with `launchctl enable|disable <domain>/<service>`. To force-start/stop a loaded service, use `launchctl start|stop <domain>/<service>`.

Lots of ad-hoc agents are launched from: `/System/Library/PrivateFrameworks/**/XPCServices`, `/System/Library/XPCServices`, `*.app/Contents/XPCServices`, `*.app/Contents/Helpers`. These services are often launched by other services (as NSExtension, XPCService, CFBundleIdentifier, LaunchServices, or MachServices). Launch chains are often of the form `launchd → parent → XPC microservices → task workers`, and can be discovered using the hierarchical Activity Monitor, or with a combination of the following:
   - `ps aux | grep XPC`              # prints PID
   - `launchctl blame pid <PID>`      # indicates "responsible pid/process"
   - `launchctl print pid/<PID>`      # indicates "originator" / "spawned by"
   - `log stream --predicate <pred>`  # queries (pred combos with `AND` etc.)
     - `'subsystem == "com.apple.xpc.launchd"'`
     - `'eventMessage CONTAINS "Siri"'`
   - `find /System/Library -name "*.xpc" | grep <name>`
   - `plutil -p <service>.xpc/Contents/Info.plist`
   - `ls <path>/XPCServices`


## Secure behavior

Enable **2FA** with **FIDO** security keys (WebAuthn > TOTP/HOTP)
(Config examples: drduh/Purse, drduh/pwd.sh, drduh/YubiKey-Guide)

Enable **FileVault** (Full Disk Encryption) without iCloud

Check apps before you run them! (or upload to VirusTotal)
```
codesign -dvvv --entitlements - <path>` # check com.apple.security.app-sandbox
codesign -dv <path> # check flags=0x10000(runtime)
```
```
for i in /Applications/*.app; do codesign -dv "${i}" &>> /tmp/codes; done
grep -B3 'none' /tmp/codes | grep ^Executable | sed 's/^Executable=/NOT HARDENED: /g'; rm -rf /tmp/codes
```

Configure new network (Wi-Fi and Ethernet) under 'Details':
- Select Rotating under Private Wi-Fi address
- Turn on Limit IP address tracking
```
networksetup -switchlocation Home
networksetup -setdnsservers Wi-Fi 8.8.8.8
```

Manage default file handlers.

Monitoring:
- Metadata: `xattr -l [FILE]` (delete with `xattr -d [ATTR] [FILE]`)
- OpenBSM auditing: `praudit -l /dev/auditpipe`
- Agents and daemons: `launchctl list`
- Running processes: `ps -ef`
- Network: `lsof -Pni`, `netstat -atln`


## Network and Firewall

- Set up secure DNS (Quad9, NextDNS, Cloudflare) DNS configuration profiles
  https://docs.quad9.net/Setup_Guides/MacOS/Big_Sur_and_later_(Encrypted)/

- DNSCrypt (config /usr/local/etc/dnscrypt-proxy.toml)
  ```
  brew install dnscrypt-proxy
  brew info dnscrypt-proxy
  # change ports in config's listen_addresses to non-default (53)
  brew services restart dnscrypt-proxy
  block drop quick on !lo0 proto udp from any to any port = 53
  block drop quick on !lo0 proto tcp from any to any port = 53
  ```

- DNSMasq
  ```
  brew install dnsmasq --with-dnssec
  brew services start dnsmasq
  networksetup -setdnsservers "Wi-Fi" 127.0.0.1  # sets dnsmasq as local server
  scutil --dns | head
  networksetup -getdnsservers "Wi-Fi"  # check if nameserver is configured
  dig +dnssec icann.org | head  # validate signed zones (NOERROR + ad flag)
  dig www.dnssec-failed.org | head  # validate improper zones (SERVFAIL)
  ```
  Config examples: drduh/config/dnsmasq.conf, drduh/config/domains
  See also: drduh/config/issues/24, drduh/config/scripts/macos-dns.sh

- Privoxy: local proxy web traffic filter (with web UI at https://p.p/)
  ```
  brew install privoxy
  brew services start privoxy
  sudo networksetup -setwebproxy "Wi-Fi" 127.0.0.1 8118
  sudo networksetup -setsecurewebproxy "Wi-Fi" 127.0.0.1 8118
  scutil --proxy
  ```
  Config examples: drduh/config/privoxy/config, drduh/config/privoxy/user.action

- Set up PF packet filtering
  https://gist.github.com/scy/8122924
  https://blog.scottlowe.org/2013/05/15/using-pf-on-os-x-mountain-lion/
  https://www.openbsd.org/faq/pf/

```
# Enable pfsense and configures some items
pfctl -e 2> /dev/null
cp /System/Library/LaunchDaemons/com.apple.pfctl.plist /Library/LaunchDaemons/sam.pfctl.plist
/usr/libexec/PlistBuddy -c "Add :ProgramArguments:1 string -e" /Library/LaunchDaemons/sam.pfctl.plist
/usr/libexec/PlistBuddy -c "Set:Label sam.pfctl" /Library/LaunchDaemons/sam.pfctl.plist
launchctl enable system/sam.pfctl; launchctl bootstrap system /Library/LaunchDaemons/sam.pfctl.plist; echo 'anchor "sam_pf_anchors"'>>/etc/pf.conf; echo 'load anchor "sam_pf_anchors" from "/etc/pf.anchors/sam_pf_anchors"'>>/etc/pf.conf
tee /etc/pf.anchors/sam_pf_anchors << EOF
block in proto tcp to any port { 548 }  # apple file service
block proto udp to any port 1900  # bonjour
block proto tcp to any port 79  # finger
block in proto { tcp udp } to any port { 20 21 }  # FTP
block in proto { tcp udp } to any port 80  # http
block in proto icmp  # icmp
block in proto tcp to any port 143  # imap
block in proto tcp to any port 993  # imaps
block proto tcp to any port 3689  # iTunes sharing
block proto udp to any port 5353  # mDNSResponder
block proto tcp to any port 2049  # nfs
block proto tcp to any port 49152  # optical drive sharing
block in proto tcp to any port 110  # pop3
block in proto tcp to any port 995  # pop3s
block in proto tcp to any port 631  # printer
block in  proto tcp to any port 3031  # remote apple events
block in proto tcp to any port 5900  # screen sharing
block proto tcp to any port { 139 445 }  # smb
block proto udp to any port { 137 138 }
block in proto tcp to any port 25  # smtp
block in proto { tcp udp } to any port 22  # ssh
block in proto { tcp udp } to any port 23  # telnet
block proto { tcp udp } to any port 69  # tftp
block proto tcp to any port 540  # uucp
EOF
pfctl -f /etc/pf.conf
```


https://www.murusfirewall.com/
https://www.obdev.at/products/littlesnitch/index.html
https://radiosilenceapp.com/
https://objective-see.org/tools.html

---


# first install login shell (ksh)
brew install ksh93 dash-shell nushell # but with mise ?
KSH=$(brew --prefix ksh93)/bin/ksh
DASH=$(brew --prefix dash-shell)/bin/dash
NUSH=$(brew --prefix nushell)/bin/nu
sudo sh -c 'echo $KSH >> /etc/shells'
sudo sh -c 'echo $DASH >> /etc/shells'
sudo sh -c 'echo $NUSH >> /etc/shells'
ln -s $DASH /usr/local/bin/sh
chsh -s $KSH

---

## Applications

Install Brew:

```
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>${HOME}/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
brew update && brew doctor
export HOMEBREW_NO_ANALYTICS=1              ### SHOULD ALSO BE IN PROFILE !!!
export HOMEBREW_NO_INSTALL_CLEANUP=0
export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_CASK_OPTS=--require-sha
export BREW_PREFIX=$(brew --prefix)
# brew bundle # install ./Brewfile
brew update && brew upgrade && brew cleanup && brew doctor
mkdir -p ~/Library/LaunchAgents
brew tap homebrew/autoupdate
brew autoupdate start 86400 --upgrade --cleanup --immediate --sudo # 24h
```

Commands: install, add init, load env, check, bundle, upgrade, cleanup, update

---

Install PGP and pinentry-mac (+ GUI GPG Suite of GPG Tools)
`brew install gnupg pinentry-mac`

Install (more) recent versions of macOS and GNU core utilities
```
brew install coreutils diffutils findutils moreutils bash bash-completion2 gnu-sed --with-default-names vim --with-override-system-vi wget --with-iri grep ripgrep openssh screen gmp php
ln -s "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"
```

Add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.

```
brew install age aria2 exiftool ffmpeg file-formula git git-lfs gpg gzip htop less nano parallel rsync tag terminal-notifier tmux tree unzip xz
```

FONTS:
```
# Install font tools.
brew tap bramstein/webfonttools
brew install sfnt2woff
brew install sfnt2woff-zopfli
brew install woff2

# "Installing fonts ..."
fonts=(
  font-fira-code
  font-source-code-pro
)
brew tap homebrew/cask-fonts
install 'brew install' "${fonts[@]}"
```

Ghostty / WezTerm
m-cli
XCode
VScodium
PDF Toolbox
UnArchiver
CopyClip
WireShark / TShark
BlockBlock / maclaunch.sh
Tresorit / restic
shellcheck
thefuck
lynis / zentral / pareto-mac / lnav
Broomstick / Barsoom / Bartender2
RayCast / Quicksilver / Alfred
VLC / IINA
Bitwarden / KeePassX / 1Password
Beeper / (R)adium
Reeder / ReadKit / and NetNewsWire
Night shift
Rectangle / Magnet / yabai
iStats
Clippy / copyclip / maccy
CheatSheet
Karabiner
appcleaner / cleanmymac
forklift / qspace
onyx
poppler
oath-toolkit

Aircrack-ng: A comprehensive suite for assessing WiFi network security, primarily used for monitoring, attacking, testing, and cracking WEP and WPA/WPA2-PSK encryption keys. It supports packet capture, injection, deauthentication attacks, and password cracking using wordlists.

BFG: A tool for cleaning large Git repositories by removing large files, passwords, or other sensitive data, improving repository performance and security.

Binutils: A collection of binary utilities for handling object files, linking, and debugging, including tools like as (assembler), ld (linker), and objdump.

Binwalk: A tool for analyzing, reverse-engineering, and extracting firmware images from embedded devices, identifying file systems, headers, and embedded payloads.

Cifer: A command-line tool for encrypting and decrypting files using various ciphers, primarily designed for secure file storage and transfer.

Dex2jar: Converts Android's Dalvik bytecode (.dex) files into standard Java .jar files for analysis and reverse engineering of Android apps.

DNS2TCP: A tool that tunnels TCP traffic over DNS, enabling covert communication through firewalls that allow DNS traffic.

Fcrackzip: A fast tool for cracking ZIP file passwords using brute-force, dictionary, or hybrid attacks.

Foremost: A forensic tool for data carving, recovering deleted files from disk images based on file headers, footers, and internal structures.

Hashpump: A tool for hash extension attacks, allowing manipulation of HMAC-signed messages without knowing the secret key.

Hydra: A parallelized login cracker that tests passwords against various services (e.g., HTTP, SSH, FTP) using brute-force or dictionary attacks.

John: A powerful password cracker that supports multiple hashing algorithms and attack types (dictionary, brute-force, rule-based).

Knock: A port-knocking daemon that allows secure access to services by requiring a specific sequence of connection attempts to closed ports.

Netpbm: A toolkit for converting and manipulating image formats, including tools for resizing, converting, and processing raster images.

Pngcheck: A utility for validating and analyzing PNG files, checking for format correctness and potential corruption.

Socat: A versatile networking tool that creates bidirectional byte streams between two endpoints (e.g., TCP, UDP, SSL, files, pipes).

Sqlmap: An automated tool for detecting and exploiting SQL injection vulnerabilities in web applications.

Tcpflow: A packet analysis tool that reconstructs TCP streams from network captures and saves them to files for inspection.

TcpReplay: A tool for replaying captured network traffic to test network performance or simulate real-world conditions.

TcpTrace: A utility for capturing and displaying TCP packet data in a human-readable format, useful for debugging network issues.

Ucspi-tcp: A set of TCP server utilities for building secure, modular network services using the ucspi-tcp framework.

Xpdf: A suite of PDF utilities for viewing, converting, and extracting content from PDF files.

Xz: A command-line tool for compressing and decompressing files using the LZMA2 algorithm, offering high compression ratios.

Ack: A search tool for code, optimized for searching source code files, with support for regular expressions and intelligent file filtering.

Exiv2: A tool for reading, writing, and manipulating metadata in image files (EXIF, IPTC, XMP).

Gs: The Ghostscript interpreter for rendering PostScript and PDF files to various formats.

ImageMagick: A comprehensive suite for manipulating and converting images, including resizing, cropping, and applying filters.

P7zip: A command-line tool for compressing and extracting archives in various formats (7z, ZIP, TAR, etc.).

Pigz: A parallel implementation of gzip for faster compression and decompression of files.

Pv: A tool for monitoring the progress of data through a pipeline, displaying transfer rate, percentage, and time.

Rename: A utility for renaming multiple files using regular expressions or custom patterns.

Rlwrap: A wrapper for readline support, adding command-line editing and history to programs that lack it.

Ssh-copy-id: A script for copying SSH public keys to a remote server, enabling passwordless login.

Vbindiff: A binary diff tool for comparing two versions of a binary to identify differences in code and structure.

Zopfli: A high-compression tool for DEFLATE-based formats (e.g., PNG, gzip), producing smaller files than standard compression.


## GitHub

```
# "Export key to Github ..."
gpg_key='3E219504'
git_email='pathikritbhowmick@msn.com'
gpg --keyserver hkp://pgp.mit.edu --recv ${gpg_key}
ssh-keygen -t rsa -b 4096 -C ${git_email}
pbcopy < ~/.ssh/id_rsa.pub
open https://github.com/settings/ssh/new

# "Setting up git defaults ..."
git_configs=(
  "branch.autoSetupRebase always"
  "color.ui auto"
  "core.autocrlf input"
  "core.pager delta"
  "diff.algorithm histogram"
  "credential.helper osxkeychain"
  "help.autocorrect 10"
  "init.defaultBranch master"
  "merge.ff false"
  "merge.conflictstyle zdiff3"
  "pull.rebase true"
  "push.default simple"
  "rebase.autostash true"
  "rerere.autoUpdate true"
  "remote.origin.prune true"
  "rerere.enabled true"
  "user.name pathikrit"
  "user.email ${git_email}"
  "user.signingkey ${gpg_key}"
)
git config --global "${config}"

# Git Login
# git config --global user.name "$name"
# git config --global user.email "$email"
# git config --global color.ui true
```

<!--
## "Setting up bash aliases ..."
```
echo "
alias del='mv -t ~/.Trash/'
alias ls='exa -l'
alias cat=bat
" >> ~/.bash_profile
chsh -s /bin/bash
```
-->

<!--
## Manage dock
```
brew install dockutil
dockutil --add "$app" &>/dev/null
dockutil --remove "$app" &>/dev/null
```
-->

---

## Audit script

```
#!/usr/bin/env bash
set -euo pipefail

disable() {
  local svc="$1"
  launchctl disable "gui/$UID/$svc" 2>/dev/null || true
  launchctl bootout  "gui/$UID/$svc" 2>/dev/null || true
}

SERVICES=(
  com.apple.GameController.gamecontrollerd
  com.apple.gamed
  com.apple.Siri.agent
  ...
)

for s in "${SERVICES[@]}"; do
  echo "Disabling $s"
  disable "$s"
done

echo
echo "Disabled services:"
launchctl print gui/$UID | grep disabled || true
```
