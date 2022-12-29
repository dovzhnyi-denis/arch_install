#!/bin/bash

while [ -n "$1" ]; do
  case "$1" in 
    -p|--plasma) plasma=1; shift;;
    -c|--cinnamon) cinnamon=1; shift;;
  esac
done

pacman -Sy archlinux-keyring -y

loadkeys us
timedatectl set-ntp true
# Default set of packages.
pkgs="base linux-lts linux-firmware networkmanager dhcpcd iwd vim screen grub efibootmgr archlinux-keyring dhcpcd bind wget curl at man-pages man-db git";
# Packages for a desktop workstation.
if [[ -n "$plasma" ]]; then 
        pkgs+=" sddm xorg plasma-meta plasma-nm konsole dolphin networkmanager-l2tp libreoffice-still flatpak ansible celluloid cmus cronie discord dolphin easytag evolution firefox jq man-db man-pages pass nginx nload pass-otp pavucontrol python qalculate-qt rsync virt-manager qemu whois";
elif [[ -n "$cinnamon" ]]; then 
        pkgs+=" lightdm-gtk-greeter cinnamon xfce4-terminal networkmanager-l2tp libreoffice-still flatpak ansible celluloid cmus cronie discord dolphin easytag evolution firefox jq man-db man-pages pass nginx nload pass-otp pavucontrol python qalculate-qt rsync virt-manager qemu whois";
fi
pacstrap /mnt $pkgs
#grub_id=$(mount | grep "/mnt " | cut -d' ' -f1 | rev | cut -d/ -f1 | rev)
grub_id=Linux
genfstab -U /mnt >> /mnt/etc/fstab
cat << EOF > /chroot_template.sh
ln -sf /usr/share/zoneinfo/Europe/Kiev /etc/locatime
hwclock --systohc
sed -i -e "s/#en_US\.UTF-8 UTF-8/en_US\.UTF-8 UTF-8/" -e "s/#uk_UA\.UTF-8 UTF-8/uk_UA\.UTF-8 UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "LANGUAGE=en_US.UTF-8" >> /etc/locale.conf
echo "LC_TIME=uk_UA.UTF-8" >> /etc/locale.conf
echo "LC_ALL=en_US.UTF-8" >> /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
echo "makenewhostname" > /etc/hostname
echo -e "127.0.0.1\tlocalhost\n::1\tlocalhost" > /etc/hosts
sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS="base udev autodetect modconf block keyboard keymap consolefont encrypt filesystems fsck"/' /etc/mkinitcpio.conf
mkinitcpio -p linux-lts
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
sed -i 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=part_uuid:part_mapper:allow-discards root=\/dev\/mapper\/part_mapper\"/' /etc/default/grub
sed -i -e s/#GRUB_DISABLE_SUBMENU=y/GRUB_DISABLE_SUBMENU=y/ -e s/GRUB_DEFAULT=0s/GRUB_DEFAULT=saved/ -e s/#GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=true/ /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable dhcpcd
systemctl enable NetworkManager
useradd -m -p $(echo testing | openssl passwd -1 -stdin) user
EOF
if [[ -z "$(mount | grep "/mnt" | grep mapper)" ]]; then
  sed -i /mkinitcpio/d /chroot_template.sh
  sed -i /GRUB_CMDLINE_LINUX/d /chroot_template.sh
else
  pmapper="$(mount | grep "/mnt " | cut -d' ' -f1 | rev | cut -d/ -f1 | rev)"
  puid=$(blkid | grep $(cryptsetup status /dev/mapper/$pmapper | grep device | cut -d' ' -f5) | cut -d'"' -f2)
  sed -i -e "s/part_uuid/${puid}/" -e "s/part_mapper/${pmapper}/g" /chroot_template.sh
fi 
[[ ! -d /sys/firmware/efi/efivars ]] && sed -i "s:grub-install --target=x86_64-efi --efi-directory=\/boot\/efi:grub-install --target=i386-pc \$\(mount | grep \"on \/ \" | cut -d\' \' -f1 | tr -d [0-9] \):" /chroot_template.sh 
sed -i "s:--bootloader-id=GRUB:--bootloader-id=Arch-${grub_id}:" /chroot_template.sh

if [[ -n "$plasma" ]]; then 
        echo 'systemctl enable sddm' >> /chroot_template.sh
elif [[ -n "$cinnamon" ]]; then
        echo 'systemctl enable lightdm' >> /chroot_template.sh
fi

echo passwd >> /chroot_template.sh
mv -v /chroot_template.sh /mnt/chroot_part.sh
chmod 700 /mnt/chroot_part.sh
arch-chroot /mnt ./chroot_part.sh
#rm /mnt/chroot_part.sh
