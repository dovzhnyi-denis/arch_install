#!/bin/bash

loadkeys us
timedatectl set-ntp true
pacstrap /mnt base linux linux-firmware dhcpcd iwd vim screen grub
genfstab -U /mnt >> /mnt/etc/fstab
cat << EOF > /mnt/chroot_part.sh
ln -sf /usr/share/zoneinfo/Europe/Kiev /etc/locatime
hwclock --systohc
sed -i -e "s/#en_US\.UTF-8 UTF-8/en_US\.UTF-8 UTF-8/" -e "s/#uk_UA\.UTF-8 UTF-8/uk_UA\.UTF-8 UTF-8/" /etc/locale.gen
echo "KEYMAP=us" > /etc/vconsole.conf
echo "testing" > /etc/hostname
grub-install --target=i386-pc $(df | grep -P "\/$" | cut -d' ' -f1)
grub-mkconfig -o /boot/grub/grub.cfg
passwd
EOF
chmod 700 /mnt/chroot_part.sh
arch-chroot /mnt ./chroot_part.sh
