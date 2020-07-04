# Usage

## Usage via build container

Usage of a docker container saves gives us a ready to run build environment.

`x cmd` is equivalent to `$WS/run.sh cmd` but it can be used from deeper in the tree,
finding the right `$WS/run.sh` for us.

```
ln -s $PWD/sources/docker/bin/x ~/bin/

x make -j16
x -r make rootfs
x -r make clean
cd build/...; x -r uname -a; x -r apt-get install vim
```

## Usage without build container

```
make -j16
sudo make rootfs
sudo make clean
sudo ./scripts/chroot.sh build/... uname -a
sudo ./scripts/chroot.sh build/... apt-get install vim
```

## Linux kernel

to build all kernels you just need to run `make kernel`, parallel builds are recommended.
`root` is not required nor recommended, and `kernel` is part of the _default_ `all` rule.

```
x make -j16 kernel
```

but you can also work with the kernel of a particular `BOARD`.

```
# compile, `make uImage`
x make -j16 kernel-BOARD
# adjust configuration , `make menuconfig`
x make kernel-BOARD-menuconfig
# backup current .config as defconfig `make savedefconfig`
x make kernel-BOARD-savedefconfig
# shortcut for a custom command like `make clean`
x make -j16 kernel-BOARD-cmd CMD=clean
```

# Dependencies

## cross-arch execution (chroot into rootfs)

We need `binfmt_misc` setup to use an emulator when working
with the target's root filesystem, and as this is kernel setup
we need it in the build server regardless if we use a docker-based
sandbox or not.

```
sudo apt-get install binfmt-support qemu-user-static
```

## Docker

```
sudo apt-get install docker.io
sudo usermod -G docker $USER
```
