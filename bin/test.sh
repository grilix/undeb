#!/bin/bash -e

if [ "$#" == "0" ]; then
  cat >&2 <<ERROR
Error: Faltan parámetros.
Usa:
   $0 <imagen>
 Ejemplo:
   $0 build/debian-12.2.0-vm-amd64.iso
ERROR

  exit 1
fi

if [ ! -f build/drive-1.img ]; then
  qemu-img create -f qcow2 build/drive-1.img 3G
fi

if [ ! -f build/drive-2.img ]; then
  qemu-img create -f qcow2 build/drive-2.img 200M
fi

qemu-system-x86_64 \
  -cpu max \
  -m 2G \
  -enable-kvm \
  -boot d \
  -device virtio-scsi-pci,id=scsi0 \
  -drive file=build/drive-1.img,if=none,format=qcow2,discard=unmap,aio=native,cache=none,index=1,id=drive1 \
  -device scsi-hd,drive=drive1,bus=scsi0.0 \
  -device virtio-scsi-pci,id=scsi1 \
  -drive file=build/drive-2.img,if=none,format=qcow2,discard=unmap,aio=native,cache=none,id=drive2 \
  -device scsi-hd,drive=drive2,bus=scsi1.0 \
  -drive file=$1,index=2,media=cdrom,readonly=on
