#!/bin/sh
set -euo pipefail

CONFIG="./disk-layout.conf"
OUTPUT="./disk.scm"
MAPPER_DIR="/dev/mapper"
LOG_FILE="./disk-setup-$(date +%F-%H%M%S).log"

DRY_RUN=0
READ_UUID_MODE=0

show_help() {
  cat <<'EOF'
用法: ./disk-setup.sh [选项]

选项:
  --dry-run       模拟执行，不做实际分区/格式化/加密
  --read-uuid    从已存在的分区读取 UUID 并生成 disk.scm（不修改硬盘）
  --help         显示此帮助信息

配置文件 disk-layout.conf 格式:
  DISK=/dev/sdX   # 要操作的磁盘 (例如 /dev/sda, /dev/nvme0n1, /dev/mmcblk0)
  # 每行分区: 名称 挂载点 结束位置 文件系统类型 是否加密
  root / 50GiB ext4 yes
  boot /boot 60GiB ext4 no
  efi /boot/efi 61GiB vfat no
  swap none 65GiB swap no

注意: 分区结束位置可以用 MiB/GiB/TiB，例如 1GiB, 50GiB
EOF
}

if [[ "${1:-}" == "--help" ]]; then
  show_help
  exit 0
elif [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  echo "运行 DRY-RUN 模式（不修改硬盘）"
elif [[ "${1:-}" == "--read-uuid" ]]; then
  READ_UUID_MODE=1
  echo "运行 READ-UUID 模式（读取现有分区 UUID，不修改硬盘）"
fi

echo "日志保存到 $LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

DISK=$(grep ^DISK "$CONFIG" | cut -d= -f2 | tr -d ' ')
if [ -z "$DISK" ]; then
  echo "disk-layout.conf 中未指定 DISK"
  exit 1
fi

# 自动判断分区后缀
part_suffix() {
  local base="$DISK"
  if [[ "$base" =~ nvme|mmcblk ]]; then
    echo "p$1"
  else
    echo "$1"
  fi
}

if [ "$DRY_RUN" -eq 0 ] && [ "$READ_UUID_MODE" -eq 0 ]; then
  echo "警告: 这将清空 $DISK 上的所有数据"
  read -p "输入 YES 确认继续: " confirm
  [ "$confirm" != "YES" ] && { echo "已取消"; exit 1; }
else
  echo "跳过确认提示"
fi

# 读取分区布局
PARTS=()
while read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  PARTS+=("$line")
done < <(grep -v '^DISK=' "$CONFIG")

# 分区
if [ "$READ_UUID_MODE" -eq 0 ]; then
  if [ "$DRY_RUN" -eq 0 ]; then
    echo "创建 GPT 分区表..."
    parted --script "$DISK" mklabel gpt
  else
    echo "Dry-run: 会创建 GPT 分区表"
  fi

  start="1MiB"
  i=1
  for part in "${PARTS[@]}"; do
    size=$(echo "$part" | awk '{print $3}')
    if [ "$DRY_RUN" -eq 0 ]; then
      parted --script "$DISK" mkpart primary "$start" "$size"
      [[ "$i" == "1" ]] && parted --script "$DISK" set "$i" esp on
    else
      echo "Dry-run: 会创建分区 $i primary $start-$size"
    fi
    start="$size"
    ((i++))
  done
  sleep 1
fi

# 生成 Guix 配置变量
MAPPED_DEVICES=""
FILE_SYSTEMS_EFI=""
FILE_SYSTEMS_ROOT=""
FILE_SYSTEMS_OTHERS=""

i=1
for part in "${PARTS[@]}"; do
  name=$(echo "$part" | awk '{print $1}')
  mount=$(echo "$part" | awk '{print $2}')
  fs=$(echo "$part" | awk '{print $4}')
  crypt=$(echo "$part" | awk '{print $5}')
  device="${DISK}$(part_suffix "$i")"
  real_dev="$device"

  luks_uuid=""
  uuid=""

  if [[ "$crypt" == "yes" ]]; then
    if [ "$READ_UUID_MODE" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
      echo "加密 $device..."
      cryptsetup luksFormat "$device"
      cryptsetup open "$device" "crypt-${name}"
      real_dev="$MAPPER_DIR/crypt-${name}"
      luks_uuid=$(cryptsetup luksUUID "$device")
    else
      luks_uuid=$(cryptsetup luksUUID "$device" 2>/dev/null || echo "")
      real_dev="$MAPPER_DIR/crypt-${name}"
    fi
    MAPPED_DEVICES+="    (mapped-device (source (uuid \"$luks_uuid\")) (target \"crypt-${name}\") (type luks-device-mapping))\n"
  fi

  # 格式化（仅非 READ_UUID 模式）
  if [ "$READ_UUID_MODE" -eq 0 ]; then
    if [ "$DRY_RUN" -eq 0 ]; then
      case "$fs" in
        vfat) mkfs.vfat "$real_dev" ;;
        ext4) mkfs.ext4 "$real_dev" ;;
        swap) mkswap "$real_dev" ;;
        *) [ -n "$fs" ] && echo "未知文件系统类型: $fs" ;;
      esac
    else
      echo "Dry-run: 会格式化 $real_dev 为 $fs"
    fi
  fi

  # 获取 UUID
  if [[ "$crypt" == "yes" ]]; then
    if [ "$READ_UUID_MODE" -eq 1 ]; then
      uuid=$(blkid -s UUID -o value "$real_dev" 2>/dev/null || echo "")
    else
      uuid=$(blkid -s UUID -o value "$real_dev" 2>/dev/null || echo "")
    fi
  else
    uuid=$(blkid -s UUID -o value "$device" 2>/dev/null || echo "")
  fi

  # 构造文件系统配置
  if [[ "$mount" != "none" ]]; then
    if [[ "$mount" == "/boot/efi" && "$fs" == "vfat" ]]; then
      fs_type="'fat32"
    else
      fs_type="'$fs"
    fi
    fs_decl="    (file-system (mount-point \"$mount\") (device (uuid \"$uuid\" $fs_type)) (type \"$fs\")"
    [[ "$crypt" == "yes" ]] && fs_decl+=" (dependencies my-mapped-devices)"
    fs_decl+=")\n"

    case "$mount" in
      "/boot/efi") FILE_SYSTEMS_EFI+="$fs_decl" ;;
      "/") FILE_SYSTEMS_ROOT+="$fs_decl" ;;
      *) FILE_SYSTEMS_OTHERS+="$fs_decl" ;;
    esac
  fi

  ((i++))
done

# 写入 disk.scm
{
  echo "(define my-mapped-devices"
  echo "  (list"
  [ -n "$MAPPED_DEVICES" ] && echo -e "$MAPPED_DEVICES"
  echo "  ))"
  echo ""
  echo "(define my-file-systems"
  echo "  (cons*"
  echo -e "$FILE_SYSTEMS_EFI$FILE_SYSTEMS_ROOT$FILE_SYSTEMS_OTHERS"
  echo "    %base-file-systems))"
  echo ""
  echo "(define my-bootloader"
  echo "  (bootloader-configuration"
  echo "    (bootloader grub-efi-bootloader)"
  echo "    (targets (list \"/boot/efi\"))"
  echo "    (keyboard-layout (keyboard-layout \"us\"))))"
} > "$OUTPUT"

echo "disk.scm 已写入 $OUTPUT"
echo "日志已保存到 $LOG_FILE"
