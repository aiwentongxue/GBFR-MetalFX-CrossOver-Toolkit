#!/bin/zsh

set -u
setopt NULL_GLOB

TOOL_VERSION="1.0.0"
SCRIPT_DIR="${0:A:h}"
PAYLOAD_DIR="$SCRIPT_DIR/payload"
BACKUP_ROOT="${GBFR_TOOL_BACKUP_ROOT:-$HOME/Library/Application Support/GBFR MetalFX Direct/Backups}"
EXPECTED_EXE_SHA256="4b3ace0fd03df5d3d08c6453e12df2279c6259abf7d2fb3622921fcbea775145"
EXPECTED_ADDON_SHA256="2bb5a2d3f44e74fff1c04a82f30928f1176bad6c5284310149f4230291098cad"

GAME_DIR=""
BOTTLE_DIR=""
ACTION=""
SCALE_PERCENT="50"
HUD_ENABLED="1"
ASSUME_YES="0"
TEST_MODE="${GBFR_TOOL_TEST_MODE:-0}"
LAST_BACKUP_DIR=""

print_header() {
  clear 2>/dev/null || true
  print "============================================================"
  print "  GBFR MetalFX Direct 配置工具 v${TOOL_VERSION}"
  print "  碧蓝幻想 Relink · CrossOver / DXMT"
  print "============================================================"
  print ""
  print "目标模式：SDR + MetalFX Temporal + Direct"
  print "注意：启用 Luma scRGB HDR 会让当前 DXMT 转为 Composited。"
  print ""
}

die() {
  print -u2 "错误：$*"
  exit 1
}

pause_if_interactive() {
  if [[ -z "$ACTION" ]]; then
    print ""
    read "REPLY?按回车键继续……"
  fi
}

strip_path_quotes() {
  local value="$1"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"
  print -r -- "$value"
}

find_crossover_wine() {
  local candidate
  for candidate in \
    "/Applications/CrossOver Preview.app/Contents/SharedSupport/CrossOver/bin/wine" \
    "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"; do
    if [[ -x "$candidate" ]]; then
      print -r -- "$candidate"
      return 0
    fi
  done
  return 1
}

game_is_running() {
  pgrep -if '[g]ranblue_fantasy_relink\.exe' >/dev/null 2>&1
}

validate_game_dir() {
  [[ -d "$GAME_DIR" ]] || die "游戏目录不存在：$GAME_DIR"
  [[ -f "$GAME_DIR/granblue_fantasy_relink.exe" ]] || die "所选目录中没有 granblue_fantasy_relink.exe"
}

validate_bottle_dir() {
  [[ -d "$BOTTLE_DIR" ]] || die "CrossOver 容器不存在：$BOTTLE_DIR"
  [[ -f "$BOTTLE_DIR/cxbottle.conf" ]] || die "所选目录缺少 cxbottle.conf"
  [[ -d "$BOTTLE_DIR/drive_c" ]] || die "所选目录缺少 drive_c，不是有效容器"
}

choose_game_dir() {
  if [[ -n "$GAME_DIR" ]]; then
    GAME_DIR="$(strip_path_quotes "$GAME_DIR")"
    validate_game_dir
    return
  fi

  local -a candidates
  local root found i choice entered
  candidates=()
  for root in "$HOME/Windows Games" "$HOME/Library/Application Support/CrossOver/Bottles"; do
    [[ -d "$root" ]] || continue
    while IFS= read -r found; do
      candidates+=("${found:h}")
    done < <(find "$root" -maxdepth 9 -type f -name 'granblue_fantasy_relink.exe' 2>/dev/null)
  done

  if (( ${#candidates[@]} > 0 )); then
    print "检测到以下游戏目录："
    i=1
    for found in "${candidates[@]}"; do
      print "  $i) $found"
      (( i++ ))
    done
    print "  $i) 手动输入路径"
    read "choice?请选择："
    if [[ "$choice" == <-> ]] && (( choice >= 1 && choice <= ${#candidates[@]} )); then
      GAME_DIR="${candidates[$choice]}"
    fi
  fi

  if [[ -z "$GAME_DIR" ]]; then
    print "请输入或拖入 Granblue Fantasy Relink 游戏文件夹："
    read entered
    GAME_DIR="$(strip_path_quotes "$entered")"
  fi
  validate_game_dir
}

choose_bottle_dir() {
  if [[ -n "$BOTTLE_DIR" ]]; then
    BOTTLE_DIR="$(strip_path_quotes "$BOTTLE_DIR")"
    validate_bottle_dir
    return
  fi

  local bottle_root="$HOME/Library/Application Support/CrossOver/Bottles"
  local -a candidates
  local dir i choice entered
  candidates=()
  for dir in "$bottle_root"/*(N/); do
    if [[ -f "$dir/cxbottle.conf" && -d "$dir/drive_c" ]]; then
      candidates+=("$dir")
    fi
  done
  (( ${#candidates[@]} > 0 )) || die "未找到 CrossOver 容器"

  print ""
  print "CrossOver 容器："
  i=1
  for dir in "${candidates[@]}"; do
    print "  $i) ${dir:t}"
    (( i++ ))
  done
  print "  $i) 手动输入路径"
  read "choice?请选择："
  if [[ "$choice" == <-> ]] && (( choice >= 1 && choice <= ${#candidates[@]} )); then
    BOTTLE_DIR="${candidates[$choice]}"
  else
    print "请输入或拖入 CrossOver 容器文件夹："
    read entered
    BOTTLE_DIR="$(strip_path_quotes "$entered")"
  fi
  validate_bottle_dir
}

choose_scale() {
  if [[ -n "${SCALE_FROM_ARGS:-}" ]]; then
    validate_scale
    return
  fi
  if [[ -n "$ACTION" ]]; then
    validate_scale
    return
  fi
  print ""
  print "MetalFX 渲染比例："
  print "  1) 50%  性能（推荐，像素量 25%）"
  print "  2) 60%  均衡（像素量 36%）"
  print "  3) 65%  质量（像素量约 42%）"
  print "  4) 75%  超高质量（像素量约 56%）"
  print "  5) 85%  接近原生（像素量约 72%）"
  print "  6) 100% 原生输入（基本没有超分性能收益）"
  print "  7) 自定义 50–100"
  local choice custom
  read "choice?请选择："
  case "$choice" in
    1) SCALE_PERCENT=50 ;;
    2) SCALE_PERCENT=60 ;;
    3) SCALE_PERCENT=65 ;;
    4) SCALE_PERCENT=75 ;;
    5) SCALE_PERCENT=85 ;;
    6) SCALE_PERCENT=100 ;;
    7)
      read "custom?请输入整数百分比（50–100）："
      SCALE_PERCENT="$custom"
      ;;
    *) die "无效选择" ;;
  esac
  validate_scale
}

validate_scale() {
  [[ "$SCALE_PERCENT" == <-> ]] || die "渲染比例必须是整数"
  (( SCALE_PERCENT >= 50 && SCALE_PERCENT <= 100 )) || die "渲染比例必须在 50–100 之间"
}

scale_fraction() {
  if (( SCALE_PERCENT == 100 )); then
    print "1.0"
  else
    printf '0.%02d\n' "$SCALE_PERCENT"
  fi
}

set_ini_value() {
  local file="$1" section="$2" key="$3" value="$4"
  local temp
  temp="$(mktemp "${TMPDIR:-/tmp}/gbfr-metalfx-ini.XXXXXX")" || return 1
  awk -v target_section="$section" -v target_key="$key" -v target_value="$value" '
    BEGIN { in_section = 0; found_section = 0; wrote = 0 }
    $0 == "[" target_section "]" {
      in_section = 1
      found_section = 1
      print
      next
    }
    in_section && /^\[/ {
      if (!wrote) {
        print target_key "=" target_value
        wrote = 1
      }
      in_section = 0
    }
    in_section && index($0, target_key "=") == 1 {
      if (!wrote) {
        print target_key "=" target_value
        wrote = 1
      }
      next
    }
    { print }
    END {
      if (!found_section) {
        print ""
        print "[" target_section "]"
        print target_key "=" target_value
      } else if (in_section && !wrote) {
        print target_key "=" target_value
      }
    }
  ' "$file" > "$temp" || { /bin/rm -f "$temp"; return 1; }
  mv "$temp" "$file"
}

set_bottle_env() {
  local file="$1" key="$2" value="$3"
  local temp
  temp="$(mktemp "${TMPDIR:-/tmp}/gbfr-metalfx-bottle.XXXXXX")" || return 1
  awk -v target_key="$key" -v target_value="$value" '
    BEGIN { in_section = 0; found_section = 0; wrote = 0 }
    $0 == "[EnvironmentVariables]" {
      in_section = 1
      found_section = 1
      print
      next
    }
    in_section && /^\[/ {
      if (!wrote) {
        print "\"" target_key "\" = \"" target_value "\""
        wrote = 1
      }
      in_section = 0
    }
    in_section && $0 ~ ("^\"" target_key "\"[[:space:]]*=") {
      if (!wrote) {
        print "\"" target_key "\" = \"" target_value "\""
        wrote = 1
      }
      next
    }
    { print }
    END {
      if (!found_section) {
        print ""
        print "[EnvironmentVariables]"
        print "\"" target_key "\" = \"" target_value "\""
      } else if (in_section && !wrote) {
        print "\"" target_key "\" = \"" target_value "\""
      }
    }
  ' "$file" > "$temp" || { /bin/rm -f "$temp"; return 1; }
  mv "$temp" "$file"
}

payload_is_valid() {
  [[ -f "$PAYLOAD_DIR/Luma-Granblue Fantasy Relink.addon" ]] || die "缺少 Luma 插件载荷"
  [[ -f "$PAYLOAD_DIR/dxgi.dll" ]] || die "缺少 ReShade dxgi.dll"
  [[ -d "$PAYLOAD_DIR/Luma" ]] || die "缺少 Luma shader 文件夹"
  local actual
  actual="$(shasum -a 256 "$PAYLOAD_DIR/Luma-Granblue Fantasy Relink.addon" | awk '{print $1}')"
  [[ "$actual" == "$EXPECTED_ADDON_SHA256" ]] || die "插件校验失败，压缩包可能损坏"
}

check_game_version() {
  local actual
  actual="$(shasum -a 256 "$GAME_DIR/granblue_fantasy_relink.exe" | awk '{print $1}')"
  if [[ "$actual" == "$EXPECTED_EXE_SHA256" ]]; then
    print "✓ 游戏版本校验通过（Steam Build ID 24955526）"
    return 0
  fi
  print ""
  print "警告：此游戏 EXE 未经过本工具验证。"
  print "当前 SHA-256：$actual"
  print "已验证 SHA-256：$EXPECTED_EXE_SHA256"
  if [[ "$TEST_MODE" == "1" || "$ASSUME_YES" == "1" ]]; then
    print "继续执行（自动确认模式）。"
    return 0
  fi
  local reply
  read "reply?仍要继续吗？输入 YES："
  [[ "$reply" == "YES" ]] || die "已取消"
}

create_backup() {
  local stamp item
  stamp="$(date '+%Y%m%d-%H%M%S')-$$"
  LAST_BACKUP_DIR="$BACKUP_ROOT/$stamp"
  mkdir -p "$LAST_BACKUP_DIR/game" "$LAST_BACKUP_DIR/bottle" "$LAST_BACKUP_DIR/absent"
  print -r -- "GAME_DIR=$GAME_DIR" > "$LAST_BACKUP_DIR/metadata.txt"
  print -r -- "BOTTLE_DIR=$BOTTLE_DIR" >> "$LAST_BACKUP_DIR/metadata.txt"
  print -r -- "CREATED_AT=$(date '+%Y-%m-%d %H:%M:%S %z')" >> "$LAST_BACKUP_DIR/metadata.txt"

  for item in "dxgi.dll" "Luma-Granblue Fantasy Relink.addon" "ReShade.ini"; do
    if [[ -e "$GAME_DIR/$item" ]]; then
      ditto "$GAME_DIR/$item" "$LAST_BACKUP_DIR/game/$item"
    else
      : > "$LAST_BACKUP_DIR/absent/game-${item//\//_}"
    fi
  done
  if [[ -d "$GAME_DIR/Luma" ]]; then
    ditto "$GAME_DIR/Luma" "$LAST_BACKUP_DIR/game/Luma"
  else
    : > "$LAST_BACKUP_DIR/absent/game-Luma"
  fi
  ditto "$BOTTLE_DIR/cxbottle.conf" "$LAST_BACKUP_DIR/bottle/cxbottle.conf"
  if [[ -f "$BOTTLE_DIR/user.reg" ]]; then
    ditto "$BOTTLE_DIR/user.reg" "$LAST_BACKUP_DIR/bottle/user.reg.reference-only"
  fi
  print "✓ 已创建备份：$LAST_BACKUP_DIR"
}

configure_registry() {
  [[ "$TEST_MODE" == "1" ]] && { print "✓ 测试模式：跳过 Wine 注册表写入"; return 0; }
  local wine bottle_name key
  wine="$(find_crossover_wine)" || die "未找到 CrossOver 或 CrossOver Preview"
  bottle_name="${BOTTLE_DIR:t}"
  key='HKCU\Software\Wine\AppDefaults\granblue_fantasy_relink.exe\DllOverrides'

  "$wine" --bottle "$bottle_name" reg add "$key" /v dxgi /t REG_SZ /d native,builtin /f >/dev/null || die "写入 dxgi 覆盖失败"
  "$wine" --bottle "$bottle_name" reg add "$key" /v nvapi64 /t REG_SZ /d '' /f >/dev/null || die "写入 nvapi64 覆盖失败"
  "$wine" --bottle "$bottle_name" reg add "$key" /v nvngx /t REG_SZ /d builtin /f >/dev/null || die "写入 nvngx 覆盖失败"
  print "✓ 已设置游戏专用 DLL 覆盖（不会影响容器内其他程序）"
}

configure_bottle() {
  local conf="$BOTTLE_DIR/cxbottle.conf"
  set_bottle_env "$conf" "D3DM_ENABLE_METALFX" "1"
  set_bottle_env "$conf" "DXMT_ENABLE_NVEXT" "1"
  set_bottle_env "$conf" "CX_GRAPHICS_BACKEND" "dxmt"
  set_bottle_env "$conf" "WINEMSYNC" "1"
  set_bottle_env "$conf" "MTL_HUD_ENABLED" "$HUD_ENABLED"
  print "✓ 已配置 DXMT、MetalFX、MSync 与 Metal HUD"
}

configure_reshade() {
  local ini="$GAME_DIR/ReShade.ini"
  if [[ ! -f "$ini" ]]; then
    ditto "$PAYLOAD_DIR/ReShade.ini.template" "$ini"
  fi
  set_ini_value "$ini" "Luma" "DisplayMode" "0"
  set_ini_value "$ini" "Luma" "RenderScale" "$(scale_fraction)"
  set_ini_value "$ini" "Luma" "SRUserType" "2"
  set_ini_value "$ini" "OVERLAY" "TutorialProgress" "4"
  print "✓ MetalFX 渲染比例已设为 ${SCALE_PERCENT}%"
}

install_payload() {
  payload_is_valid
  choose_game_dir
  choose_bottle_dir
  choose_scale
  [[ "$HUD_ENABLED" == "0" || "$HUD_ENABLED" == "1" ]] || die "HUD 参数只能是 on 或 off"
  if game_is_running && [[ "$TEST_MODE" != "1" ]]; then
    die "请先完全退出游戏后再安装"
  fi
  check_game_version
  create_backup
  ditto "$PAYLOAD_DIR/dxgi.dll" "$GAME_DIR/dxgi.dll"
  ditto "$PAYLOAD_DIR/Luma-Granblue Fantasy Relink.addon" "$GAME_DIR/Luma-Granblue Fantasy Relink.addon"
  ditto "$PAYLOAD_DIR/Luma" "$GAME_DIR/Luma"
  configure_reshade
  configure_bottle
  configure_registry
  print ""
  print "安装完成。请在 CrossOver 中为该容器启用高分辨率模式，然后重新启动游戏。"
  print "Metal HUD 应显示 Direct，以及 MetalFX Temporal 的 Input/Target Resolution。"
}

change_scale() {
  choose_game_dir
  choose_bottle_dir
  choose_scale
  if game_is_running && [[ "$TEST_MODE" != "1" ]]; then
    die "请先完全退出游戏后再调整档位"
  fi
  create_backup
  configure_reshade
  print "✓ 档位修改完成，重新启动游戏后生效"
}

toggle_hud() {
  choose_game_dir
  choose_bottle_dir
  if [[ -z "${HUD_FROM_ARGS:-}" ]]; then
    local choice
    print "1) 开启 Metal HUD"
    print "2) 关闭 Metal HUD"
    read "choice?请选择："
    case "$choice" in
      1) HUD_ENABLED=1 ;;
      2) HUD_ENABLED=0 ;;
      *) die "无效选择" ;;
    esac
  fi
  if game_is_running && [[ "$TEST_MODE" != "1" ]]; then
    die "请先完全退出游戏后再切换 HUD"
  fi
  create_backup
  set_bottle_env "$BOTTLE_DIR/cxbottle.conf" "MTL_HUD_ENABLED" "$HUD_ENABLED"
  print "✓ Metal HUD 已$([[ "$HUD_ENABLED" == "1" ]] && print '开启' || print '关闭')，重新启动游戏后生效"
}

diagnose() {
  choose_game_dir
  choose_bottle_dir
  local addon_hash="missing" exe_hash="missing"
  [[ -f "$GAME_DIR/Luma-Granblue Fantasy Relink.addon" ]] && addon_hash="$(shasum -a 256 "$GAME_DIR/Luma-Granblue Fantasy Relink.addon" | awk '{print $1}')"
  [[ -f "$GAME_DIR/granblue_fantasy_relink.exe" ]] && exe_hash="$(shasum -a 256 "$GAME_DIR/granblue_fantasy_relink.exe" | awk '{print $1}')"
  print ""
  print "诊断结果"
  print "  游戏目录：$GAME_DIR"
  print "  容器：${BOTTLE_DIR:t}"
  print "  游戏 EXE：$exe_hash"
  print "  Direct 版插件：$addon_hash"
  [[ "$addon_hash" == "$EXPECTED_ADDON_SHA256" ]] && print "  插件校验：通过" || print "  插件校验：不匹配"
  print ""
  print "ReShade.ini："
  grep -nE '^(DisplayMode|RenderScale|SRUserType|TutorialProgress)=' "$GAME_DIR/ReShade.ini" 2>/dev/null || print "  未找到相关设置"
  print ""
  print "容器环境："
  grep -nE 'D3DM_ENABLE_METALFX|DXMT_ENABLE_NVEXT|CX_GRAPHICS_BACKEND|WINEMSYNC|MTL_HUD_ENABLED' "$BOTTLE_DIR/cxbottle.conf" 2>/dev/null || print "  未找到相关设置"
}

restore_latest() {
  choose_game_dir
  choose_bottle_dir
  local -a backups
  local backup item outgoing candidate
  backups=("$BACKUP_ROOT"/20*(N/))
  backups=( ${(O)backups} )
  (( ${#backups[@]} > 0 )) || die "没有可用备份"
  backup=""
  for candidate in "${backups[@]}"; do
    [[ -f "$candidate/metadata.txt" ]] || continue
    if grep -Fqx "GAME_DIR=$GAME_DIR" "$candidate/metadata.txt" \
      && grep -Fqx "BOTTLE_DIR=$BOTTLE_DIR" "$candidate/metadata.txt"; then
      backup="$candidate"
      break
    fi
  done
  [[ -n "$backup" ]] || die "没有找到与当前游戏目录和容器匹配的备份"
  if game_is_running && [[ "$TEST_MODE" != "1" ]]; then
    die "请先完全退出游戏后再恢复"
  fi
  outgoing="$BACKUP_ROOT/restore-outgoing-$(date '+%Y%m%d-%H%M%S')-$$"
  mkdir -p "$outgoing/game" "$outgoing/bottle"
  for item in "dxgi.dll" "Luma-Granblue Fantasy Relink.addon" "ReShade.ini"; do
    [[ -e "$GAME_DIR/$item" ]] && mv "$GAME_DIR/$item" "$outgoing/game/$item"
    [[ -e "$backup/game/$item" ]] && ditto "$backup/game/$item" "$GAME_DIR/$item"
  done
  if [[ -d "$GAME_DIR/Luma" ]]; then
    mv "$GAME_DIR/Luma" "$outgoing/game/Luma"
  fi
  [[ -d "$backup/game/Luma" ]] && ditto "$backup/game/Luma" "$GAME_DIR/Luma"
  ditto "$BOTTLE_DIR/cxbottle.conf" "$outgoing/bottle/cxbottle.conf"
  ditto "$backup/bottle/cxbottle.conf" "$BOTTLE_DIR/cxbottle.conf"
  print "✓ 已恢复最近备份：$backup"
  print "  恢复前文件保存在：$outgoing"
  print "  游戏专用注册表覆盖仍保留；重新安装可安全复用。"
}

show_tutorial() {
  open "$SCRIPT_DIR/MetalFX 档位调节教程.md"
}

interactive_menu() {
  print_header
  print "1) 安装 / 修复 Direct + MetalFX"
  print "2) 调整 MetalFX 档位"
  print "3) 开启 / 关闭 Metal HUD"
  print "4) 运行诊断"
  print "5) 恢复最近备份"
  print "6) 打开档位调节教程"
  print "7) 退出"
  local choice
  read "choice?请选择："
  case "$choice" in
    1) install_payload ;;
    2) change_scale ;;
    3) toggle_hud ;;
    4) diagnose ;;
    5) restore_latest ;;
    6) show_tutorial ;;
    7) exit 0 ;;
    *) die "无效选择" ;;
  esac
  pause_if_interactive
}

while (( $# > 0 )); do
  case "$1" in
    --install) ACTION="install" ;;
    --scale) ACTION="scale"; shift; SCALE_PERCENT="${1:-}"; SCALE_FROM_ARGS=1 ;;
    --hud) ACTION="hud"; shift; [[ "${1:-}" == "on" ]] && HUD_ENABLED=1 || HUD_ENABLED=0; HUD_FROM_ARGS=1 ;;
    --diagnose) ACTION="diagnose" ;;
    --restore-latest) ACTION="restore" ;;
    --game) shift; GAME_DIR="${1:-}" ;;
    --bottle) shift; BOTTLE_DIR="${1:-}" ;;
    --yes) ASSUME_YES=1 ;;
    --help)
      print "用法：$0 [--install|--scale N|--hud on|off|--diagnose|--restore-latest] --game PATH --bottle PATH [--yes]"
      exit 0
      ;;
    *) die "未知参数：$1" ;;
  esac
  shift
done

case "$ACTION" in
  install) print_header; install_payload ;;
  scale) print_header; change_scale ;;
  hud) print_header; toggle_hud ;;
  diagnose) print_header; diagnose ;;
  restore) print_header; restore_latest ;;
  *) interactive_menu ;;
esac
