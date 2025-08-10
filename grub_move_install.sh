#!/bin/sh

guix shell grub-efi -- sudo GRUB_ENABLE_CRYPTODISK=y grub-install --target=x86_64-efi --efi-directory=/mnt/boot/efi --boot-directory=/mnt/boot --removable