#!/bin/sh -e

#####
# Crea una partición en un dispositivo y configura el punto de montaje. Si el dispositivo
# no existe, será ignorado.
#
# Este script está pensado para correrse en el ambiente de la instalación.
# Por ejemplo:
#   d-i preseed/late_command string \
#     mount --bind /dev /target/dev; \
#     mount --bind /dev/pts /target/dev/pts; \
#     mount --bind /proc /target/proc; \
#     mount --bind /sys /target/sys; \
#     /var/lib/undeb/plug-disk.sh /dev/sdb /var/lib/store ext4;

DEVICE="$1"
MOUNT_PATH="$2"
FS="${3-ext4}"

if [ "$#" -le 1 ]; then
  cat >&2 <<ERROR
Error: Faltan parámetros, usa:
  $0 <dispositivo> <destino> [<fs>]
Ejemplo:
  $0 /dev/sdb /var/lib/my-store ext4
ERROR
  exit 1
fi

if [ ! -b "$DEVICE" ]; then
 if [ -f "$DEVICE" ]; then
   cat >&2 <<ERROR
Error: El archivo $DEVICE existe, pero no es un dispositivo de bloque. No se puede continuar.
ERROR
   exit 1
 fi

 cat >&2 <<ERROR
Aviso: El dispositivo $DEVICE no existe. Ignorando particionado.
 Parámetros recibidos: $@
ERROR
 exit 0
fi

cat <<PART | chroot /target fdisk "$DEVICE"
o
n
p
1


w
PART

chroot /target mkfs.${FS} "${DEVICE}1"
chroot /target mkdir -p $MOUNT_PATH
UUID=$(chroot /target blkid -o value -s UUID "${DEVICE}1")
echo "UUID=$UUID "$MOUNT_PATH" $FS defaults 0 1" | \
  chroot /target tee -a /etc/fstab
