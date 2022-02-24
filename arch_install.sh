#!/bin/bash

while [ -n "$1" ]; do
  case "$1" in 
    -P|--plasma-desktop) plasma_desktop=1; shift 1;;
  esac
done

loadkeys us
timedatectl set-ntp true
pacstrap /mnt base linux-lts linux-firmware dhcpcd iwd vim screen grub efibootmgr archlinux-keyring dhcpcd
[[ -n "$plasma_desktop" ]] && pacstrap /mnt xorg plasma-meta plasma-nm konsole dolphin networkmanager networkmanager-l2tp
grub_id=$(mount | grep /mnt | cut -d' ' -f1 | rev | cut -d/ -f1 | rev | cut -d'-' -f1)
genfstab -U /mnt >> /mnt/etc/fstab
cat << EOF > /chroot_template.sh
ln -sf /usr/share/zoneinfo/Europe/Kiev /etc/locatime
hwclock --systohc
sed -i -e "s/#en_US\.UTF-8 UTF-8/en_US\.UTF-8 UTF-8/" -e "s/#uk_UA\.UTF-8 UTF-8/uk_UA\.UTF-8 UTF-8/" /etc/locale.gen
echo "KEYMAP=us" > /etc/vconsole.conf
echo "make_new_hostname" > /etc/hostname
sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS="base udev autodetect modconf block keyboard keymap consolefont encrypt filesystems fsck" /etc/mkinitcpio.conf
mkinitcpio -p linux
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cryptdevice=UUID=part_uuid:part_mapper:allow-discards root=/dev/mapper/part_mapper/' /etc/default/grub
sed -i -e s/#GRUB_DISABLE_SUBMENU=y/GRUB_DISABLE_SUBMENU=y/ -e s/GRUB_DEFAULT=0s/GRUB_DEFAULT=saved/ -e s/#GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=true/ /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable dhcpcd
EOF
if [[ -z "$(mount | grep /mnt | grep mapper)" ]]; then
  sed -i /mkinitcpio/d /chroot_template.sh
  sed -i /GRUB_CMDLINE_LINUX/d /chroot_template.sh
else
  puid=$(blkid | grep -v mapper | grep -oE "UUID=\"[a-z0-9A-Z\-]+\" TYPE\=\"crypto_LUKS\"" | cut -d' ' -f1 | sed -e s/UUID=// -e s/\"//g)
  pmapper=${grub_id}-root
  sed -i "s/part_uuid:part_mapper:allow-discards root=\/dev\/mapper\/part_mapper/${puid}:${pmapper}:allow-discards root=\/dev\/mapper\/${pmapper}/" /chroot_template.sh
fi 
[[ ! -d /sys/firmware/efi/efivars ]] && sed -i "s:grub-install --target=x86_64-efi --efi-directory=\/efi:grub-install --target=i386-pc \$\(mount | grep \"on \/ \" | cut -d\' \' -f1\):" /chroot_template.sh 
sed -i "s:--bootloader-id=GRUB:--bootloader-id=Arch-${grub_id}:" /chroot_template.sh

[[ -n "$plasma_desktop" ]] && echo 'systemctl enable sddb && systemctl enable NetworkManager' >> /chroot_template.sh

echo passwd >> /chroot_template.sh
mv -v /chroot_template.sh /mnt/chroot_part.sh
chmod 700 /mnt/chroot_part.sh
arch-chroot /mnt ./chroot_part.sh
