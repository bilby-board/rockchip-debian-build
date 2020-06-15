# Usage

## Usage via build container

Usage of a docker container saves gives us a ready to run build environment.

`x cmd` is equivalent to `$WS/run.sh cmd` but it can be used from deeper in the tree,
finding the right `$WS/run.sh` for us.

```
ln -s $PWD/sources/docker/bin/x ~/bin/

x make
x -r ./mkrootfs.sh
x -r make clean
```

## Usage without build container

```
make
sudo ./mkrootfs.sh
sudo make clean
```

# Dependencies

## cross-arch execution (chroot into rootfs)

```
sudo apt-get install binfmt-support qemu-user-static
```

## Docker

```
sudo apt-get install docker.io
sudo usermod -G docker $USER
```
