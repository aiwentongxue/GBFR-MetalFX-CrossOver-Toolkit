#!/bin/zsh

set -u
setopt NULL_GLOB

TOOL_VERSION="1.1.0"
SCRIPT_DIR="${0:A:h}"
PAYLOAD_DIR="$SCRIPT_DIR/payload"
BACKUP_ROOT="${GBFR_TOOL_BACKUP_ROOT:-$HOME/Library/Application Support/GBFR MetalFX Direct/Backups}"
EXPECTED_EXE_SHA256="4b3ace0fd03df5d3d08c6453e12df2279c6259abf7d2fb3622921fcbea775145"
EXPECTED_ADDON_SHA256="2bb5a2d3f44e74fff1c04a82f30928f1176bad6c5284310149f4230291098cad"
EXPECTED_WINMM_SHA256="6203c5a0ba1f8c5c77c7c12c33be178a5057063ef1da265eb0a546495c6e6a4e"
EXPECTED_ULTRAWIDE_ASI_SHA256="fc3a36fb599baaa823dd90d90c58ed98e217f495105feacbc823b8df4ffad7f4"

GAME_DIR=""
BOTTLE_DIR=""
ACTION=""
SCALE_PERCENT="50"
HUD_ENABLED="1"
OUTPUT_WIDTH=""
OUTPUT_HEIGHT=""
RESOLUTION_MODE="preserve"
ASSUME_YES="0"
TEST_MODE="${GBFR_TOOL_TEST_MODE:-0}"
LAST_BACKUP_DIR=""

print_header() {
  clear 2>/dev/null || true
  print "============================================================"
  print "  GBFR MetalFX + 宽屏一键工具 v${TOOL_VERSION}"
  print "  碧蓝幻想 Relink · CrossOver / DXMT"
  print "============================================================"
  print ""
  print "目标模式：SDR + MetalFX Temporal + Direct"
  print "包含：GBFRelinkFix v1.1.5 + 游戏专用 winmm 覆盖"
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

validate_resolution() {
  [[ "$OUTPUT_WIDTH" == <-> && "$OUTPUT_HEIGHT" == <-> ]] || die "分辨率必须是整数"
  if (( OUTPUT_WIDTH == 0 && OUTPUT_HEIGHT == 0 )); then
    return 0
  fi
  (( OUTPUT_WIDTH >= 640 && OUTPUT_HEIGHT >= 360 )) || die "自定义分辨率过低"
}

choose_resolution() {
  if [[ -n "${RESOLUTION_FROM_ARGS:-}" ]]; then
    validate_resolution
    RESOLUTION_MODE="set"
    return
  fi
  if [[ -n "$ACTION" && "$RESOLUTION_MODE" != "ask" ]]; then
    return
  fi

  print ""
  print "宽屏补丁输出分辨率："
  print "  1) 保留现有设置（推荐；首次安装时自动跟随桌面）"
  print "  2) 自动跟随当前桌面（0 × 0）"
  print "  3) 3456 × 2234（16 英寸 MacBook Pro 内建屏）"
  print "  4) 自定义"
  local choice width height
  read "choice?请选择："
  case "$choice" in
    1) RESOLUTION_MODE="preserve" ;;
    2) RESOLUTION_MODE="set"; OUTPUT_WIDTH=0; OUTPUT_HEIGHT=0 ;;
    3) RESOLUTION_MODE="set"; OUTPUT_WIDTH=3456; OUTPUT_HEIGHT=2234 ;;
    4)
      read "width?请输入宽度："
      read "height?请输入高度："
      OUTPUT_WIDTH="$width"
      OUTPUT_HEIGHT="$height"
      RESOLUTION_MODE="set"
      validate_resolution
      ;;
    *) die "无效选择" ;;
  esac
}

set_ini_value() {
  local file="$1" section="$2" key="$3" value="$4"
  local temp
  temp="$(mktemp "${TMPDIR:-/tmp}/gbfr-metalfx-ini.XXXXXX")" || return 1
  awk -v target_section="$section" -v target_key="$key" -v target_value="$value" '
    BEGIN { in_section = 0; found_section = 0; wrote = 0 }
    { sub(/\r$/, "", $0) }
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
    in_section && $0 ~ ("^[[:space:]]*" target_key "[[:space:]]*=") {
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

ultrawide_payload_is_valid() {
  local winmm="$PAYLOAD_DIR/Ultrawide/winmm.dll"
  local asi="$PAYLOAD_DIR/Ultrawide/scripts/GBFRelinkFix.asi"
  local ini="$PAYLOAD_DIR/Ultrawide/scripts/GBFRelinkFix.ini"
  [[ -f "$winmm" && -f "$asi" && -f "$ini" ]] || die "缺少 GBFRelinkFix 宽屏补丁载荷"
  [[ "$(shasum -a 256 "$winmm" | awk '{print $1}')" == "$EXPECTED_WINMM_SHA256" ]] \
    || die "winmm.dll 校验失败，压缩包可能损坏"
  [[ "$(shasum -a 256 "$asi" | awk '{print $1}')" == "$EXPECTED_ULTRAWIDE_ASI_SHA256" ]] \
    || die "GBFRelinkFix.asi 校验失败，压缩包可能损坏"
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

  for item in \
    "dxgi.dll" \
    "Luma-Granblue Fantasy Relink.addon" \
    "ReShade.ini" \
    "winmm.dll" \
    "scripts/GBFRelinkFix.asi" \
    "scripts/GBFRelinkFix.ini"; do
    if [[ -e "$GAME_DIR/$item" ]]; then
      mkdir -p "$LAST_BACKUP_DIR/game/${item:h}"
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
  "$wine" --bottle "$bottle_name" reg add "$key" /v winmm /t REG_SZ /d native,builtin /f >/dev/null || die "写入 winmm 覆盖失败"

  local query
  query="$("$wine" --bottle "$bottle_name" reg query "$key" 2>/dev/null | tr -d '\r')" \
    || die "DLL 覆盖写入后无法读回验证"
  print -r -- "$query" | grep -Eq 'dxgi[[:space:]]+REG_SZ[[:space:]]+native,builtin' || die "dxgi 覆盖验证失败"
  print -r -- "$query" | grep -Eq 'nvngx[[:space:]]+REG_SZ[[:space:]]+builtin' || die "nvngx 覆盖验证失败"
  print -r -- "$query" | grep -Eq 'winmm[[:space:]]+REG_SZ[[:space:]]+native,builtin' || die "winmm 覆盖验证失败"
  print -r -- "$query" | grep -Eq 'nvapi64[[:space:]]+REG_SZ([[:space:]]*)$' || die "nvapi64 禁用项验证失败"
  print "✓ 已设置并验证游戏专用 DLL 覆盖：dxgi、nvapi64、nvngx、winmm"
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

prepare_install() {
  choose_game_dir
  choose_bottle_dir
  if game_is_running && [[ "$TEST_MODE" != "1" ]]; then
    die "请先完全退出游戏后再安装"
  fi
  check_game_version
  create_backup
}

install_metalfx_files() {
  payload_is_valid
  ditto "$PAYLOAD_DIR/dxgi.dll" "$GAME_DIR/dxgi.dll"
  ditto "$PAYLOAD_DIR/Luma-Granblue Fantasy Relink.addon" "$GAME_DIR/Luma-Granblue Fantasy Relink.addon"
  ditto "$PAYLOAD_DIR/Luma" "$GAME_DIR/Luma"
  configure_reshade
}

install_ultrawide_files() {
  ultrawide_payload_is_valid
  local new_ini="0"
  mkdir -p "$GAME_DIR/scripts"
  ditto "$PAYLOAD_DIR/Ultrawide/winmm.dll" "$GAME_DIR/winmm.dll"
  ditto "$PAYLOAD_DIR/Ultrawide/scripts/GBFRelinkFix.asi" "$GAME_DIR/scripts/GBFRelinkFix.asi"
  if [[ ! -f "$GAME_DIR/scripts/GBFRelinkFix.ini" ]]; then
    ditto "$PAYLOAD_DIR/Ultrawide/scripts/GBFRelinkFix.ini" "$GAME_DIR/scripts/GBFRelinkFix.ini"
    new_ini="1"
  fi

  if [[ "$RESOLUTION_MODE" == "set" ]]; then
    set_ini_value "$GAME_DIR/scripts/GBFRelinkFix.ini" "Custom Resolution" "Enabled" "true"
    set_ini_value "$GAME_DIR/scripts/GBFRelinkFix.ini" "Custom Resolution" "Width" "$OUTPUT_WIDTH"
    set_ini_value "$GAME_DIR/scripts/GBFRelinkFix.ini" "Custom Resolution" "Height" "$OUTPUT_HEIGHT"
    print "✓ 宽屏补丁输出分辨率已设为 ${OUTPUT_WIDTH}×${OUTPUT_HEIGHT}"
  elif [[ "$new_ini" == "1" ]]; then
    set_ini_value "$GAME_DIR/scripts/GBFRelinkFix.ini" "Custom Resolution" "Enabled" "true"
    set_ini_value "$GAME_DIR/scripts/GBFRelinkFix.ini" "Custom Resolution" "Width" "0"
    set_ini_value "$GAME_DIR/scripts/GBFRelinkFix.ini" "Custom Resolution" "Height" "0"
    print "✓ 首次安装：宽屏补丁将自动跟随桌面分辨率"
  else
    print "✓ 已保留现有 GBFRelinkFix.ini 设置"
  fi
  print "✓ 已安装 GBFRelinkFix v1.1.5"
}

install_full() {
  local custom="${1:-0}"
  if [[ "$custom" == "1" ]]; then
    choose_scale
    RESOLUTION_MODE="ask"
    choose_resolution
  else
    SCALE_PERCENT="50"
    RESOLUTION_MODE="preserve"
  fi
  [[ "$HUD_ENABLED" == "0" || "$HUD_ENABLED" == "1" ]] || die "HUD 参数只能是 on 或 off"
  prepare_install
  install_metalfx_files
  install_ultrawide_files
  configure_bottle
  configure_registry
  print ""
  print "完整安装完成。请在 CrossOver 中为该容器启用高分辨率模式，然后重新启动游戏。"
  print "Metal HUD 应显示 Direct，以及 MetalFX Temporal 的 Input/Target Resolution。"
}

install_metalfx_only() {
  choose_scale
  prepare_install
  install_metalfx_files
  configure_bottle
  configure_registry
  print "✓ MetalFX Direct 已安装 / 修复"
}

install_ultrawide_only() {
  if [[ -z "$ACTION" ]]; then
    RESOLUTION_MODE="ask"
  else
    RESOLUTION_MODE="preserve"
  fi
  choose_resolution
  prepare_install
  install_ultrawide_files
  configure_registry
  print "✓ 宽屏补丁与 winmm 游戏专用覆盖已安装 / 修复"
}

change_resolution() {
  choose_game_dir
  choose_bottle_dir
  RESOLUTION_MODE="ask"
  choose_resolution
  [[ "$RESOLUTION_MODE" == "set" ]] || { print "未更改现有分辨率。"; return 0; }
  if game_is_running && [[ "$TEST_MODE" != "1" ]]; then
    die "请先完全退出游戏后再调整分辨率"
  fi
  create_backup
  install_ultrawide_files
  configure_registry
  print "✓ 输出分辨率修改完成，重新启动游戏后生效"
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
  local addon_hash="missing" exe_hash="missing" winmm_hash="missing" asi_hash="missing"
  [[ -f "$GAME_DIR/Luma-Granblue Fantasy Relink.addon" ]] && addon_hash="$(shasum -a 256 "$GAME_DIR/Luma-Granblue Fantasy Relink.addon" | awk '{print $1}')"
  [[ -f "$GAME_DIR/granblue_fantasy_relink.exe" ]] && exe_hash="$(shasum -a 256 "$GAME_DIR/granblue_fantasy_relink.exe" | awk '{print $1}')"
  [[ -f "$GAME_DIR/winmm.dll" ]] && winmm_hash="$(shasum -a 256 "$GAME_DIR/winmm.dll" | awk '{print $1}')"
  [[ -f "$GAME_DIR/scripts/GBFRelinkFix.asi" ]] && asi_hash="$(shasum -a 256 "$GAME_DIR/scripts/GBFRelinkFix.asi" | awk '{print $1}')"
  print ""
  print "诊断结果"
  print "  游戏目录：$GAME_DIR"
  print "  容器：${BOTTLE_DIR:t}"
  print "  游戏 EXE：$exe_hash"
  print "  Direct 版插件：$addon_hash"
  [[ "$addon_hash" == "$EXPECTED_ADDON_SHA256" ]] && print "  插件校验：通过" || print "  插件校验：不匹配"
  print "  winmm.dll：$winmm_hash"
  print "  GBFRelinkFix.asi：$asi_hash"
  [[ "$winmm_hash" == "$EXPECTED_WINMM_SHA256" && "$asi_hash" == "$EXPECTED_ULTRAWIDE_ASI_SHA256" ]] \
    && print "  宽屏补丁校验：通过（v1.1.5）" \
    || print "  宽屏补丁校验：不匹配或缺失"
  print ""
  print "ReShade.ini："
  grep -nE '^(DisplayMode|RenderScale|SRUserType|TutorialProgress)=' "$GAME_DIR/ReShade.ini" 2>/dev/null || print "  未找到相关设置"
  print ""
  print "容器环境："
  grep -nE 'D3DM_ENABLE_METALFX|DXMT_ENABLE_NVEXT|CX_GRAPHICS_BACKEND|WINEMSYNC|MTL_HUD_ENABLED' "$BOTTLE_DIR/cxbottle.conf" 2>/dev/null || print "  未找到相关设置"
  print ""
  print "GBFRelinkFix.ini："
  awk '
    /^\[Custom Resolution\]$/ { in_section=1; print; next }
    in_section && /^\[/ { exit }
    in_section && /^(Enabled|Width|Height)[[:space:]]*=/ { print }
  ' "$GAME_DIR/scripts/GBFRelinkFix.ini" 2>/dev/null || print "  未找到宽屏补丁设置"
  print ""
  print "游戏专用 DLL 覆盖："
  if [[ "$TEST_MODE" != "1" ]]; then
    local wine key registry_output
    key='HKCU\Software\Wine\AppDefaults\granblue_fantasy_relink.exe\DllOverrides'
    if wine="$(find_crossover_wine)"; then
      registry_output="$("$wine" --bottle "${BOTTLE_DIR:t}" reg query "$key" 2>/dev/null | tr -d '\r')"
      print -r -- "$registry_output" | grep -E '(^|[[:space:]])(dxgi|nvapi64|nvngx|winmm)[[:space:]]+REG_SZ' || print "  未找到完整覆盖"
      if print -r -- "$registry_output" | grep -Eq 'dxgi[[:space:]]+REG_SZ[[:space:]]+native,builtin' \
        && print -r -- "$registry_output" | grep -Eq 'nvapi64[[:space:]]+REG_SZ([[:space:]]*)$' \
        && print -r -- "$registry_output" | grep -Eq 'nvngx[[:space:]]+REG_SZ[[:space:]]+builtin' \
        && print -r -- "$registry_output" | grep -Eq 'winmm[[:space:]]+REG_SZ[[:space:]]+native,builtin'; then
        print "  校验：通过"
      else
        print "  校验：未通过，请执行‘一键推荐安装 / 修复’"
      fi
    else
      print "  未找到 CrossOver Wine，无法读取"
    fi
  else
    print "  测试模式：跳过 Wine 注册表读取"
  fi
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
  for item in \
    "dxgi.dll" \
    "Luma-Granblue Fantasy Relink.addon" \
    "ReShade.ini" \
    "winmm.dll" \
    "scripts/GBFRelinkFix.asi" \
    "scripts/GBFRelinkFix.ini"; do
    mkdir -p "$outgoing/game/${item:h}" "$GAME_DIR/${item:h}"
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
  print "1) 一键推荐安装 / 修复（MetalFX 50% + 宽屏）"
  print "2) 自定义完整安装（可选 MetalFX 档位和分辨率）"
  print "3) 仅安装 / 修复 MetalFX Direct"
  print "4) 仅安装 / 修复宽屏补丁"
  print "5) 调整 MetalFX 档位"
  print "6) 调整宽屏输出分辨率"
  print "7) 开启 / 关闭 Metal HUD"
  print "8) 运行诊断"
  print "9) 恢复最近备份"
  print "10) 打开 MetalFX 档位调节教程"
  print "11) 退出"
  local choice
  read "choice?请选择："
  case "$choice" in
    1) install_full 0 ;;
    2) install_full 1 ;;
    3) install_metalfx_only ;;
    4) install_ultrawide_only ;;
    5) change_scale ;;
    6) change_resolution ;;
    7) toggle_hud ;;
    8) diagnose ;;
    9) restore_latest ;;
    10) show_tutorial ;;
    11) exit 0 ;;
    *) die "无效选择" ;;
  esac
  pause_if_interactive
}

while (( $# > 0 )); do
  case "$1" in
    --install|--full-install) ACTION="install" ;;
    --metalfx-install) ACTION="metalfx-install" ;;
    --ultrawide-install) ACTION="ultrawide-install" ;;
    --scale) ACTION="scale"; shift; SCALE_PERCENT="${1:-}"; SCALE_FROM_ARGS=1 ;;
    --resolution)
      ACTION="resolution"
      shift
      if [[ "${1:-}" == *x* ]]; then
        OUTPUT_WIDTH="${1%%x*}"
        OUTPUT_HEIGHT="${1#*x}"
      else
        die "分辨率格式应为 WIDTHxHEIGHT，例如 3456x2234"
      fi
      RESOLUTION_FROM_ARGS=1
      ;;
    --hud) ACTION="hud"; shift; [[ "${1:-}" == "on" ]] && HUD_ENABLED=1 || HUD_ENABLED=0; HUD_FROM_ARGS=1 ;;
    --diagnose) ACTION="diagnose" ;;
    --restore-latest) ACTION="restore" ;;
    --game) shift; GAME_DIR="${1:-}" ;;
    --bottle) shift; BOTTLE_DIR="${1:-}" ;;
    --yes) ASSUME_YES=1 ;;
    --help)
      print "用法：$0 [--install|--metalfx-install|--ultrawide-install|--scale N|--resolution WIDTHxHEIGHT|--hud on|off|--diagnose|--restore-latest] --game PATH --bottle PATH [--yes]"
      exit 0
      ;;
    *) die "未知参数：$1" ;;
  esac
  shift
done

case "$ACTION" in
  install) print_header; install_full 0 ;;
  metalfx-install) print_header; install_metalfx_only ;;
  ultrawide-install) print_header; install_ultrawide_only ;;
  scale) print_header; change_scale ;;
  resolution) print_header; change_resolution ;;
  hud) print_header; toggle_hud ;;
  diagnose) print_header; diagnose ;;
  restore) print_header; restore_latest ;;
  *) interactive_menu ;;
esac
