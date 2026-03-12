# BoppOS Containerfile
#
# A high-performance, desktop-focused atomic image based on CachyOS.
# Derived from cachyos-deckify-bootc.

# Stage 1: Bootstrap a basic Arch Linux environment
FROM cgr.dev/chainguard/wolfi-base:latest AS rootfs

# Wolfi is rolling, so we don't need to pin this anymore
# ENV VERSION="2026.03.01"
# ENV SHASUM="eb52fd74f466658f039f2f7fe9bced015d29b23c569e72c5abb7015bdb6d5c7f"

RUN apk add gnutar zstd curl && \
    curl -fLOJ --retry 3 https://fastly.mirror.pkgbuild.com/iso/latest/archlinux-bootstrap-x86_64.tar.zst && \
    # echo "$SHASUM archlinux-bootstrap-x86_64.tar.zst" > sha256sum.txt && \
    # sha256sum -c sha256sum.txt || exit 1 && \
    tar -xf /archlinux-bootstrap-x86_64.tar.zst --numeric-owner && \
    rm -f /archlinux-bootstrap-x86_64.tar.zst && \
    apk del gnutar zstd curl && \
    apk cache clean

# Stage 2: Build the OS
FROM scratch AS system
COPY --from=rootfs /root.x86_64/ /

# Set default locale
ENV LANG=en_US.UTF-8

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
    sed -i -e "/= *\/var/ s/^#//" -e "s@= */var@= /usr/lib/sysimage@g" -e "/DownloadUser/d" -e "/^#IgnorePkg/a IgnorePkg = mesa-git lib32-mesa-git" /etc/pacman.conf

# assign user.component to every package
# script by hec
RUN mkdir -p /usr/libexec
COPY --chmod=0755 files/usr/libexec /usr/libexec
COPY files/usr/share /usr/share
COPY files/usr/lib /usr/lib
COPY files/etc /etc

# Initialize keyrings and transition to CachyOS base
RUN --mount=type=tmpfs,dst=/run \
    pacman-key --init && \
    pacman-key --populate && \
    pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com && \
    pacman-key --lsign-key F3B607488DB35A47 && \
    pacman -Sy --noconfirm --needed cachyos-keyring cachyos-mirrorlist cachyos-v3-mirrorlist cachyos-v4-mirrorlist cachyos-hooks chwd cachyos-rate-mirrors lsb-release && \
    cachyos-rate-mirrors && \
    pacman -Syu --noconfirm && pacman -Scc --noconfirm

# Generate en_US.UTF-8 locale
RUN sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen && \
    echo "LANG=en_US.UTF-8" > /etc/locale.conf

# add a repo for bootc by hec
RUN --mount=type=tmpfs,dst=/run \
    pacman-key --recv-key 5DE6BF3EBC86402E7A5C5D241FA48C960F9604CB --keyserver keyserver.ubuntu.com && \
    pacman-key --lsign-key 5DE6BF3EBC86402E7A5C5D241FA48C960F9604CB && \
    echo -e '[bootc]\nSigLevel = Required\nServer=https://github.com/hecknt/arch-bootc-pkgs/releases/download/$repo' >> /etc/pacman.conf

# Add Chaotic-AUR repository for additional pre-built AUR packages
RUN --mount=type=tmpfs,dst=/run \
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com && \
    pacman-key --lsign-key 3056513887B78AEB && \
    pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' && \
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" >> /etc/pacman.conf && \
    pacman -Syu --noconfirm && pacman -Scc --noconfirm

# dracut errors out on missing i18n_vars
# https://github.com/dracutdevs/dracut/issues/868
RUN mkdir -p /usr/lib/dracut/dracut.conf.d && \
    echo 'i18n_vars="/usr/share/kbd/consolefonts  /usr/share/kbd/keymaps"' >> /usr/lib/dracut/dracut.conf.d/boppos-cachyos.conf

# Set CPU-specific repository based on build argument
ARG TARGET_CPU_MARCH
RUN /usr/libexec/1-set-cpu-repo.sh "$TARGET_CPU_MARCH"

# Remove base Arch kernel if it exists
RUN --mount=type=tmpfs,dst=/run \
    pacman -Rns --noconfirm linux || echo "Base linux kernel not found, skipping."

# Remove handheld-specific packages if they exist
RUN --mount=type=tmpfs,dst=/run \
    pacman -Rns --noconfirm linux-cachyos-deckify linux-cachyos-deckify-headers cachyos-handheld plasma-login-manager || echo "Handheld packages not found, skipping."

# Install the standard desktop kernel and core bootc components
RUN --mount=type=tmpfs,dst=/run \
    pacman -Sy --noconfirm --needed \
        linux-cachyos linux-cachyos-headers \
        systemd systemd-sysvcompat \
        dbus dbus-broker-units dbus-glib glib2 polkit shadow \
        dracut ostree bootc skopeo \
        amd-ucode intel-ucode \
        linux-firmware sof-firmware && pacman -Scc --noconfirm

# Install Graphics & Drivers
RUN --mount=type=tmpfs,dst=/run \
    pacman -Sy --noconfirm --needed \
        mesa lib32-mesa mesa-utils vulkan-icd-loader \
        vulkan-radeon lib32-vulkan-radeon vulkan-tools && pacman -Scc --noconfirm

# Install Desktop Environment, Fonts & Power Management
RUN --mount=type=tmpfs,dst=/run \
    pacman -Sy --noconfirm --needed \
        ttf-ms-fonts ttf-dejavu ttf-bitstream-vera noto-fonts noto-fonts-emoji \
        cachyos-settings cachyos-kde-settings cachyos-micro-settings cachyos-wallpapers \
        power-profiles-daemon cpupower upower accountsservice rtkit xdg-user-dirs && pacman -Scc --noconfirm

# Install Gaming Core (Launchers & Compatibility)
RUN --mount=type=tmpfs,dst=/run \
    pacman -Sy --noconfirm --needed \
        steam lutris heroic-games-launcher-bin gamescope xdotool yad \
        cachyos-gaming-applications faugus-launcher umu-launcher \
        proton-cachyos wine-cachyos winboat && pacman -Scc --noconfirm

# Install Gaming Utilities
RUN --mount=type=tmpfs,dst=/run \
    pacman -Sy --noconfirm --needed \
        sunshine lact coolercontrol openrgb openrgb-plugin-effects-git wireplumber nvtop \
        mangohud goverlay pipewire-pulse libdvdcss gst-libav mpv-git ffmpeg pavucontrol \
        inputplumber lsfg-vk game-devices-udev udev-joystick-blacklist-git && pacman -Scc --noconfirm

# Install Development Base & CLI Tools
RUN --mount=type=tmpfs,dst=/run \
    pacman -Sy --noconfirm --needed \
        base-devel meld base-devel procps-ng curl file git \
        git byobu openssh openssl curl wget paru \
        nano micro vi unrar unzip xz nfs-utils \
        btop konsave && pacman -Scc --noconfirm

# Install Development Languages
RUN --mount=type=tmpfs,dst=/run \
    pacman -Sy --noconfirm --needed \
        nodejs npm rust python-pip python-pipx \
        cargo-binstall cargo-update && pacman -Scc --noconfirm

# Install Heavy Development Tools
RUN --mount=type=tmpfs,dst=/run \
    pacman -Sy --noconfirm --needed \
        visual-studio-code-bin && pacman -Scc --noconfirm

# Install Shell Environment
RUN --mount=type=tmpfs,dst=/run \
    pacman -Sy --noconfirm --needed \
        bash-completion zsh-completions starship zoxide eza && pacman -Scc --noconfirm

# Install Networking & VPNs
RUN --mount=type=tmpfs,dst=/run \
    pacman -Sy --noconfirm --needed \
        networkmanager networkmanager-openvpn wpa_supplicant iwd ethtool dnsutils \
        modemmanager usb_modeswitch nss-mdns bluez bluez-utils bluez-libs \
        openvpn wireguard-tools pptpclient helium-browser-bin \
        mullvad-vpn mullvad-vpn-daemon cloudflare-warp-bin tailscale && pacman -Scc --noconfirm

# Install Virtualization & Containers
RUN --mount=type=tmpfs,dst=/run \
    pacman -Sy --noconfirm --needed \
        podman podman-compose docker docker-compose distrobox flatpak fwupd && pacman -Scc --noconfirm

# Install sched-ext packages
RUN --mount=type=tmpfs,dst=/run \
    pacman -Sy --noconfirm --needed scx-scheds-git scx-tools-git scx-manager \
    ananicy-cpp cachyos-ananicy-rules gamescope-session-cachyos && pacman -Scc --noconfirm

# Install Desktop Environment & Display Manager
RUN --mount=type=tmpfs,dst=/run \
    pacman -Sy --noconfirm --needed \
        plasma-desktop plasma-workspace xorg-xwayland \
        qt5-wayland qt6-wayland cachyos-emerald-kde-theme-git cachyos-plymouth-theme \
        dolphin konsole sddm sddm-kcm cachyos-themes-sddm \
        powerdevil kscreen breeze-gtk ark ffmpegthumbnailer \
        polkit polkit-kde-agent udisks2 ptyxis \
        xdg-desktop-portal xdg-desktop-portal-kde && pacman -Scc --noconfirm

# Install AUR packages
RUN /usr/libexec/2-install-aur.sh

# Install and configure Waydroid for Android app support
RUN --mount=type=tmpfs,dst=/run \
    pacman -Sy --noconfirm --needed waydroid && pacman -Scc --noconfirm

# Configure Flatpak by adding the Flathub remote
RUN flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Configure shell environment
RUN /usr/libexec/3-shell-config.sh

# Correctly generate the initramfs for the newly installed kernel
#RUN /usr/local/bin/4-dracut-fix.sh
COPY files/usr/bin /usr/bin

# Ensure system users are created (fixes polkit user issues)
RUN systemd-sysusers

# Force creation of critical system users if sysusers failed and fix NetworkManager DNS
# RUN getent group polkitd >/dev/null || groupadd -g 102 polkitd && \
#     getent passwd polkitd >/dev/null || useradd -u 102 -g polkitd -d / -s /usr/bin/nologin polkitd && \
#     getent group dbus >/dev/null || groupadd -g 81 dbus && \
#     getent passwd dbus >/dev/null || useradd -u 81 -g dbus -d / -s /usr/bin/nologin dbus && \
#     getent group systemd-resolve >/dev/null || groupadd -r systemd-resolve && \
#     getent passwd systemd-resolve >/dev/null || useradd -r -g systemd-resolve -d / -s /usr/bin/nologin systemd-resolve && \
#     mkdir -p /etc/NetworkManager/conf.d && \
#     printf '[main]\ndns=systemd-resolved\n' > /etc/NetworkManager/conf.d/dns.conf

# Fix permissions for polkit helper
RUN chmod 4755 /usr/lib/polkit-1/polkit-agent-helper-1 && \
    chmod 4755 /usr/bin/newuidmap && \
    chmod 4755 /usr/bin/newgidmap && \
    chmod 4755 /usr/bin/pkexec && \
    chmod 0750 /etc/polkit-1/rules.d && \
    chown root:polkitd /etc/polkit-1/rules.d

# Disable SELinux labeling in Podman to prevent mount errors on non-SELinux kernels
RUN mkdir -p /etc/containers/containers.conf.d && \
    printf '[containers]\nlabel = false\n' > /etc/containers/containers.conf.d/01-no-selinux.conf

# Enable required systemd services
# Sunshine is NOT enabled by default for security. User must configure and enable it manually.
RUN systemctl enable NetworkManager.service && \
    systemctl enable systemd-resolved.service && \
    systemctl enable dbus-broker.service && \
    systemctl enable bluetooth.service && \
    systemctl enable ModemManager.service && \
    systemctl enable ananicy-cpp.service && \
    systemctl enable scx_loader.service && \
    systemctl enable brew-setup.service &&\
    systemctl enable docker.service && \
    systemctl enable sddm.service && \
    systemctl --global enable install-flatpaks.service

# Ensure /etc/resolv.conf links to systemd-resolved
# RUN mkdir -p /usr/lib/tmpfiles.d && \
#     echo "L+ /etc/resolv.conf - - - - /run/systemd/resolve/stub-resolv.conf" > /usr/lib/tmpfiles.d/boppos-resolv.conf

# https://github.com/bootc-dev/bootc/issues/1801
RUN --mount=type=tmpfs,dst=/run \
    printf "systemdsystemconfdir=/etc/systemd/system\nsystemdsystemunitdir=/usr/lib/systemd/system\n" | tee /usr/lib/dracut/dracut.conf.d/30-bootcrew-fix-bootc-module.conf && \
    printf 'reproducible=yes\nhostonly=no\ncompress=zstd\nadd_dracutmodules+=" ostree bootc "' | tee "/usr/lib/dracut/dracut.conf.d/30-bootcrew-bootc-container-build.conf" && \
    dracut --force "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E '\.img$' | tail -n 1)/initramfs.img"

# Preserve /opt contents by moving to /usr/lib/opt and creating tmpfiles to link them back
RUN mkdir -p /usr/lib/opt && \
    if [ -d /opt ] && [ "$(ls -A /opt)" ]; then \
        cp -a /opt/. /usr/lib/opt/ && \
        mkdir -p /usr/lib/tmpfiles.d && \
        for path in /opt/*; do \
            echo "L+ /var/opt/$(basename "$path") - - - - /usr/lib/opt/$(basename "$path")" >> /usr/lib/tmpfiles.d/boppos-opt.conf; \
        done \
    fi

# Make SDDM themes mutable by redirecting to /var/sddm_themes
RUN mkdir -p /usr/lib/tmpfiles.d && \
    mv /usr/share/sddm/themes /usr/share/sddm/themes.ro && \
    ln -s /var/sddm_themes /usr/share/sddm/themes && \
    printf "d /var/sddm_themes 0755 root root -\n" > /usr/lib/tmpfiles.d/boppos-sddm-themes.conf && \
    printf "C /var/sddm_themes - - - - /usr/share/sddm/themes.ro\n" >> /usr/lib/tmpfiles.d/boppos-sddm-themes.conf

# Final system setup and cleanup, adopted from upstream
RUN sed -i 's|^HOME=.*|HOME=/var/home|' "/etc/default/useradd" && \
    rm -rf /mnt /opt /boot /home /root /usr/local /srv /var /usr/lib/sysimage/log /usr/lib/sysimage/cache/pacman/pkg && \
    mkdir -p /sysroot /boot /usr/lib/ostree /var /run /tmp && \
    ln -s sysroot/ostree /ostree && ln -s var/roothome /root && ln -s var/srv /srv && ln -s var/opt /opt && ln -s var/mnt /mnt && ln -s var/home /home && ln -s ../var/usrlocal /usr/local && \
    echo "$(for dir in opt home srv mnt usrlocal ; do echo "d /var/$dir 0755 root root -" ; done)" | tee -a "/usr/lib/tmpfiles.d/bootc-base-dirs.conf" && \
    printf "d /var/roothome 0700 root root -\nd /run/media 0755 root root -" | tee -a "/usr/lib/tmpfiles.d/bootc-base-dirs.conf" && \
    printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' | tee "/usr/lib/ostree/prepare-root.conf"

    # Link /etc/os-release to its equivalent in /usr/lib/os-release
RUN ln -sf ../usr/lib/os-release /etc/os-release
RUN ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime

# Add repository security keys
RUN mkdir -p /etc/pki/containers
COPY cosign.pub /etc/pki/containers/boppos.pub

# remove leftover file created by cachyos' vapor theme package
RUN rm -f /README.md

# Set bootc label for compatibility
LABEL containers.bootc=1

# Clean pacman cache
RUN pacman -Scc --noconfirm
