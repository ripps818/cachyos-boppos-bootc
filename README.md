# BoppOS CachyOS 🚀

**A high-performance, desktop-focused atomic (bootc) Linux image based on CachyOS.**

BoppOS CachyOS is a custom-built OS designed for high-end desktop gaming and development. It's a fork of `cachyos-deckify-bootc`, transformed from a handheld-oriented system into a powerful, desktop-first experience.

---

## Key Features

- **High-Performance Base**: Built on [CachyOS](https://cachyos.org/), an Arch-based distribution with performance-tuned kernels and repositories.
- **Atomic & Immutable**: Uses [bootc](https://bootc-dev.github.io/) for an atomic, image-based system that offers incredible stability and easy rollbacks.
- **Desktop Optimized**: Stripped of all handheld UI elements and optimized for a traditional desktop experience with KDE Plasma.
- **Modern Hardware Support**: Includes build-time support for `znver4` CPU optimizations for AMD Ryzen 7000 series processors.
- **Gaming Ready**: Comes with a suite of pre-installed gaming software and utilities:
  - `cachyos-gaming-applications`, `proton-cachyos`, `wine-cachyos`
  - `sunshine`, `mangohud`, `goverlay`, `lact`
  - `faugus-launcher`, `umu-launcher`, `winboat`
- **Developer Focused**: Includes essential development tools out of the box:
  - `docker` & `docker-compose`
  - `nodejs`, `npm`, `rust`, `python-pip`, `python-pipx`
  - `visual-studio-code-bin`
- **Enhanced Shell**: A pre-configured shell environment with `starship`, `zoxide`, and `eza` for a modern terminal experience.

## Build Instructions

You can build the BoppOS image using any container tool like `podman` or `docker`.

### Standard Build (v3 Generic)

This build is compatible with most modern x86-64 hardware and is suitable for sharing or for use in CI/CD environments.

```bash
podman build -t boppos-cachyos:latest .
```

### v4 Build (x86-64-v4)

This enables optimizations for a wide range of modern CPUs (e.g., Intel Haswell and newer, AMD Excavator and newer) that support the x86-64-v4 microarchitecture level.

```bash
podman build --build-arg TARGET_CPU_MARCH=v4 -t boppos-cachyos-v4:latest .
```

### Optimized Build (znver4)

If you are building on and for a system with an AMD Ryzen 7000 series CPU (or newer), you can enable native `znver4` optimizations for maximum performance.

```bash
podman build --build-arg TARGET_CPU_MARCH=znver4 -t boppos-cachyos-znver4:latest .
```

## Installation & Switching

This image is designed to be managed by `bootc`. You can either perform a fresh installation on a new system or switch an existing `bootc`-based OS to BoppOS without losing your data.

### Fresh Installation

After building the container image, you can:

1.  Push it to a container registry (like `ghcr.io`, `quay.io`, or a local registry).
2.  Use `bootc install` from a live environment to install BoppOS to a target disk.

For detailed installation instructions, refer to the [official bootc documentation](https://bootc-dev.github.io/book/installation.html).

A typical installation command would look like this:

```bash
# Example:
bootc install to-disk --image your-registry/boppos-cachyos:latest /dev/sdX
```

### Switching from an Existing bootc OS (e.g., Bazzite)

If you are already running a `bootc`-based system, you can switch to BoppOS directly without needing to reformat or reinstall. This is one of the major advantages of `bootc`.

To switch, run the following command, pointing to the BoppOS image in your registry:

```bash
sudo bootc switch your-registry/boppos-cachyos:latest
```

Your system will download the new image and stage it for the next boot.

**Note on Signature Verification**: For a secure transition, you may need to configure your system to trust the signature of the new image. The `Containerfile` includes a `cosign.pub` key and `policy.json`, which you may need to adapt for your registry and signing setup.


## Acknowledgements

This project was made possible by the excellent work of the CachyOS team and the creators of the original [cachyos-deckify-bootc](https://github.com/lumaeris/cachyos-deckify-bootc) repository from which this was forked. It also stands on the shoulders of the [Bootcrew](https://github.com/bootcrew) and [bootc](https://github.com/containers/bootc) projects.
