sudo pacman -Syu
exit
loadkeys fr
sudo loadkeys fr
nmcli
nmcli dev statu
nmcli dev status
nmcli dev status list
nmcli dev status
nmcli radio wifi on
nmcli dev wifi list
systemctl status NetworkManager
nmcli devis
nmcli device
rfkill unblock wifi
nmcli device
sudo systemctl restart wpa-supplicant
nmcli dev wifi rescan
lspci -k | grep -A 3 -i network
lspci | grep -i network
dmesg | grep -i wifi
sudo dmesg | grep -i wifi
rfkill lis
sudo dmesg | grep -i network
ip link show
lspci | grep -i network
sudo pacman -S b43-fwcutter
lsdisk
lsblk
mount /dev/sdb1 /mnt
sudo mount /dev/sdb1 /mnt
mount /dev/sdb1 /mnt
lsblk
ls /mnt/b43
sudo pacman -U /mnt/b43/b43-fwcutter-019-6-x86_64.pkg.tar.zst 
sudo modprobe -r b43
sudo modprobe b43
ip link show
dmesg | grep -i b43
sudo dmesg | grep -i b43
sudo modprobe -r wl
sudo modprobe -r wl
sudo modprobe -r b43
sudo modprobe b43
sudo | grep -i b43
sudo dmesg| grep -i b43
sudo modprobe wl
lo
ls /lib/firmware/brcm
lsmod | grep b43
sudo modprobe b
sudo modprobe b43
lspci | grep -i network
lsmod | grep b43
clear
lsmod | grep b43
ip link show
sudo ip link set wlan0 up
rfkill list
sudo rfkill unblock wifi
iwconfig
ifconfig
iw dev
sudo nano /etc/wpa_supplicant/wpa_supplicant.conf
sudo nano /etc/wpa_supplicant/wpa_supplicant.conf
sudo systemctl status wpa_supplicant
sudo systemctl enable wpa_supplicant
sudo systemctl start wpa_supplicant
sudo systemctl status wpa_supplicant
ip link show
nmcli dev list
nmcli dev wifi list
sudo systemctl disable wpa_supplicant
sudo systemctl kill wpa_supplicant
sudo systemctl status wpa_supplicant
clear
sudo modprobe brcmsmac
sudo modprobe wl
lsblk
sudo umount /dev/sdb1
lsblk
lsblk
mount /dev/sdb1
sudo mount /dev/sdb1
clear
sudo mount /dev/sdb1 
sudo mount /dev/sdb1 /mnt/
sudo pacman -U /mnt/broadcom/broadcom-wl-6.30.223.271-605-x86_64.pkg.tar.zst 
sudo modprobe wl
ip link
iw dev
dmesg | grep -i wl
sudo dmesg | grep -i wl
ip link
sudo systemctl restart NetworkManager
sudo modprobe -r 
sudo modprobe -r b4
sudo modprobe -r b43
sudo modprobe wl
sudo nmcli radio wifi on
ip link
sudo reboot
nano /home/tmcooper/.config/hypr/hyprland.conf 
sudo pacman -Sy os-prober
clear
sudo nano /etc/default/grub 
sudo grub-mkconfig -o /boot/grub/grub.cfg
firefox
sudo nano /etc/grub.d/40_custom
sudo nano /etc/grub.d/40_custom
sudo fdisk -l
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo reboot
firefox
sudo os-prober
sudo fdisk -l
ls /sys/firmware/efi
sudo nano /etc/grub.d/40_custom
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo mount /dev/sda1 /mnt
ls /mnt/EFI/Microsoft/Boot/bootmgfw.efi
sudo nano /etc/grub.d/40_custom
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo reboot
firefox
git clone --depth=1 https://github.com/JaKooLit/Arch-Hyprland.git ~/Arch-Hyprland
cd ~/Arch-Hyprland
chmod +x install.sh
clear
./install.sh
./install.sh
