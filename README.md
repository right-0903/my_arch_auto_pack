# my_arch_auto_pack

This project is still in its early and experimental stages. As I am not well-versed in shell scripting, most of this project has been developed using online tutorials and assistance from AI. It is intended for my personal use only. If you choose to use it, you do so at your own risk.

## About

This repository is designed to build and release pre-built binary packages automatically. However, each package requires an existing and maintained package repository that includes a `PKGBUILD`. As an Arch Linux user, these packages typically come from the AUR repository or from GitLab repositories (such as Manjaro's official packages).

The idea for the release process was inspired by [ironrobin](https://github.com/ironrobin/x13s-alarm/releases/tag/packages).

## Binary Repository

To use the pre-built packages, add the following section to the end of your `/etc/pacman.conf` file:

```conf
[nuvole-arch]
Server = https://github.com/right-0903/my_arch_auto_pack/releases/download/packages
```

You will also need to trust my public key to verify the package signatures:

```bash
sudo pacman-key --add CA909D46CD1890BE.asc
sudo pacman-key --lsign-key CA909D46CD1890BE
```


