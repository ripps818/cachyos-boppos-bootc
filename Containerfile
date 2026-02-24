FROM cgr.dev/chainguard/wolfi-base:latest AS rootfs

ENV VERSION="2026.02.01"
ENV SHASUM="5debe75527010999719815ca964b6f630eac525167c6ad00ba1f7aa510ba657a"

RUN apk add gnutar zstd curl && \
    curl -fLOJ --retry 3 https://fastly.mirror.pkgbuild.com/iso/$VERSION/archlinux-bootstrap-x86_64.tar.zst && \
    echo "$SHASUM archlinux-bootstrap-x86_64.tar.zst" > sha256sum.txt && \
    sha256sum -c sha256sum.txt || exit 1 && \
    tar -xf /archlinux-bootstrap-x86_64.tar.zst --numeric-owner && \
    rm -f /archlinux-bootstrap-x86_64.tar.zst && \
    apk del gnutar zstd curl && \
    apk cache clean

FROM scratch AS system
COPY --from=rootfs /root.x86_64/ /

COPY --from=ghcr.io/ublue-os/brew:latest /system_files /

# put homebrew to its own layer
RUN setfattr -n user.component -v "homebrew" "/usr/share/homebrew.tar.zst"

RUN sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist

# replacing with cachyos' pacman config and mirrorlists
RUN rm -f /etc/pacman.conf && \
    curl --retry 3 https://raw.githubusercontent.com/CachyOS/docker/refs/heads/master/pacman.conf -o /etc/pacman.conf && \
    curl --retry 3 https://raw.githubusercontent.com/CachyOS/CachyOS-PKGBUILDS/master/cachyos-mirrorlist/cachyos-mirrorlist -o /etc/pacman.d/cachyos-mirrorlist

RUN touch /var/log/pacman.log
# Move everything from `/var` to `/usr/lib/sysimage` so behavior around pacman remains the same on `bootc usroverlay`'d systems
RUN grep "= */var" /etc/pacman.conf | sed "/= *\/var/s/.*=// ; s/ //" | xargs -n1 sh -c 'mkdir -p "/usr/lib/sysimage/$(dirname $(echo $1 | sed "s@/var/@@"))" && mv -v "$1" "/usr/lib/sysimage/$(echo "$1" | sed "s@/var/@@")"' '' && \
    sed -i -e "/= *\/var/ s/^#//" -e "s@= */var@= /usr/lib/sysimage@g" -e "/DownloadUser/d" /etc/pacman.conf

# assign user.component to every package
# script by hec
RUN mkdir -p /usr/libexec
COPY files/usr/libexec /usr/libexec
COPY files/usr/share /usr/share

# populate arch linux keyring first
RUN pacman-key --init && \
    pacman-key --populate

# transitioning to cachyos >:D
RUN pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com && \
    pacman-key --lsign-key F3B607488DB35A47 && \
    pacman -Sy && \
    pacman -S --needed --noconfirm cachyos-keyring cachyos-mirrorlist cachyos-v3-mirrorlist cachyos-v4-mirrorlist cachyos-hooks chwd && \
    pacman -Syu --noconfirm && pacman -S --clean --noconfirm

# add a repo for bootc by hec
RUN pacman-key --recv-key 5DE6BF3EBC86402E7A5C5D241FA48C960F9604CB --keyserver keyserver.ubuntu.com && \
    pacman-key --lsign-key 5DE6BF3EBC86402E7A5C5D241FA48C960F9604CB && \
    echo -e '[bootc]\nSigLevel = Required\nServer=https://github.com/hecknt/arch-bootc-pkgs/releases/download/$repo' >> /etc/pacman.conf

# dracut errors out on missing i18n_vars
# https://github.com/dracutdevs/dracut/issues/868
RUN mkdir -p /usr/lib/dracut/dracut.conf.d && \
    echo 'i18n_vars="/usr/share/kbd/consolefonts  /usr/share/kbd/keymaps"' >> /usr/lib/dracut/dracut.conf.d/lumaeris-cachyos-deckify.conf

RUN pacman -Sy --needed --noconfirm linux-cachyos-deckify linux-cachyos-deckify-headers dracut cpio ostree btrfs-progs e2fsprogs xfsprogs dosfstools skopeo dbus dbus-glib glib2 ostree shadow bootc && pacman -S --clean --noconfirm

RUN pacman -Sy --noconfirm cachyos-settings cachyos-micro-settings cachyos-wallpapers && pacman -S --clean --noconfirm

# base-devel + common packages
RUN pacman -Sy --needed --noconfirm libwnck3 mesa-utils xf86-input-libinput xorg-xdpyinfo xorg-server xorg-xinit xorg-xinput xorg-xkill xorg-xrandr dhclient dnsmasq dnsutils ethtool iwd modemmanager networkmanager networkmanager-openvpn nss-mdns usb_modeswitch wpa_supplicant wireless-regdb xl2tpd bluez bluez-hid2hci bluez-libs bluez-utils pacman-contrib pkgfile rebuild-detector reflector paru accountsservice bash-completion ffmpegthumbnailer gst-libav gst-plugin-pipewire gst-plugins-bad gst-plugins-ugly libdvdcss libgsf libopenraw mlocate poppler-glib xdg-user-dirs xdg-utils efitools haveged nfs-utils nilfs-utils ntp smartmontools unrar unzip xz adobe-source-han-sans-cn-fonts adobe-source-han-sans-jp-fonts adobe-source-han-sans-kr-fonts awesome-terminal-fonts noto-fonts-emoji noto-color-emoji-fontconfig cantarell-fonts freetype2 noto-fonts opendesktop-fonts ttf-bitstream-vera ttf-dejavu ttf-liberation ttf-opensans ttf-meslo-nerd noto-fonts-cjk alsa-firmware alsa-plugins alsa-utils pavucontrol pipewire-pulse wireplumber pipewire-alsa rtkit dmidecode dmraid hdparm hwdetect lsscsi mtools sg3_utils sof-firmware linux-firmware cpupower power-profiles-daemon upower alacritty btop duf findutils fsarchiver git glances hwinfo inxi meld nano-syntax-highlighting fastfetch pv python-defusedxml python-packaging rsync sed vi wget ripgrep micro nano vim openssh && pacman -S --clean --noconfirm

# kde plasma (for handhelds!) and some necessary packages of cachyos handheld edition
# it pulls big steam bootstrap automatically so I don't need to worry about it at all
RUN pacman -Sy --needed --noconfirm cachyos-nord-kde-theme-git cachyos-iridescent-kde cachyos-emerald-kde-theme-git cachyos-themes-sddm cachyos-handheld v4l-utils plasma-keyboard ark bluedevil breeze-gtk char-white dolphin egl-wayland gwenview konsole kate kdeconnect kde-gtk-config kdegraphics-thumbnailers kdeplasma-addons ffmpegthumbs kinfocenter kscreen kwallet-pam kwalletmanager plasma-desktop libplasma plasma-nm plasma-pa plasma-workspace plasma-integration plasma-firewall plasma-browser-integration plasma-systemmonitor plasma-thunderbolt powerdevil spectacle sddm sddm-kcm qt6-wayland xsettingsd xdg-desktop-portal xdg-desktop-portal-kde phonon-qt6-vlc && pacman -S --clean --noconfirm

# cpu firmware and accessibility tools
RUN pacman -Sy --needed --noconfirm amd-ucode intel-ucode espeak-ng mousetweaks orca && pacman -S --clean --noconfirm

# missing in cachyos' selection of packages
RUN pacman -Sy --needed --noconfirm sudo flatpak discover fwupd distrobox podman && pacman -S --clean --noconfirm

# replace system updater for gaming mode
COPY files/usr/bin /usr/bin

# Allow people in group wheel to run all commands
RUN mkdir -p /etc/sudoers.d && \
    echo "%wheel ALL=(ALL) ALL" | \
    tee "/etc/sudoers.d/wheel"

# enable some necessary services
RUN systemctl enable NetworkManager.service && \
    systemctl enable brew-setup.service &&\
    systemctl --global enable cachyos-gamescope-autologin.service

# https://github.com/bootc-dev/bootc/issues/1801
RUN printf "systemdsystemconfdir=/etc/systemd/system\nsystemdsystemunitdir=/usr/lib/systemd/system\n" | tee /usr/lib/dracut/dracut.conf.d/30-bootcrew-fix-bootc-module.conf && \
    printf 'reproducible=yes\nhostonly=no\ncompress=zstd\nadd_dracutmodules+=" ostree bootc "' | tee "/usr/lib/dracut/dracut.conf.d/30-bootcrew-bootc-container-build.conf" && \
    dracut --force "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)/initramfs.img"

# Necessary for general behavior expected by image-based systems
RUN sed -i 's|^HOME=.*|HOME=/var/home|' "/etc/default/useradd" && \
    rm -rf /mnt /opt /boot /home /root /usr/local /srv /var /usr/lib/sysimage/log /usr/lib/sysimage/cache/pacman/pkg && \
    mkdir -p /sysroot /boot /usr/lib/ostree /var /run /tmp && \
    ln -s sysroot/ostree /ostree && ln -s var/roothome /root && ln -s var/srv /srv && ln -s var/opt /opt && ln -s var/mnt /mnt && ln -s var/home /home && \
    echo "$(for dir in opt home srv mnt usrlocal ; do echo "d /var/$dir 0755 root root -" ; done)" | tee -a "/usr/lib/tmpfiles.d/bootc-base-dirs.conf" && \
    printf "d /var/roothome 0700 root root -\nd /run/media 0755 root root -" | tee -a "/usr/lib/tmpfiles.d/bootc-base-dirs.conf" && \
    printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' | tee "/usr/lib/ostree/prepare-root.conf"

# remove leftover file created by cachyos' vapor theme package
RUN rm -f /README.md

# Link /etc/os-release to its equivalent in /usr/lib/os-release
RUN ln -sf ../usr/lib/os-release /etc/os-release

RUN ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime

RUN mkdir -p /etc/pki/containers
COPY files/etc /etc
COPY cosign.pub /etc/pki/containers/lumaeris.pub

# Setup a temporary root passwd (changeme) for dev purposes
# RUN pacman -S whois --noconfirm && pacman -S --clean --noconfirm
# RUN usermod -p "$(echo "changeme" | mkpasswd -s)" root

# https://bootc-dev.github.io/bootc/bootc-images.html#standard-metadata-for-bootc-compatible-images
LABEL containers.bootc 1

RUN bootc container lint
