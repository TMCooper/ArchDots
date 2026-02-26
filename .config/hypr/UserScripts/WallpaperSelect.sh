#!/usr/bin/env bash
# /* ---- 💫 Adapté pour Debug Terminal 💫 ---- */

# Couleurs pour le terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Pas de couleur

# WALLPAPERS PATH
terminal=kitty
PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallDIR="$PICTURES_DIR/wallpapers"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
wallpaper_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"

# swww transition config
FPS=60
TYPE="any"
DURATION=2
BEZIER=".43,1.19,1,.4"
SWWW_PARAMS="--transition-fps $FPS --transition-type $TYPE --transition-duration $DURATION --transition-bezier $BEZIER"

echo -e "${BLUE}--- Démarrage du script de wallpaper ---${NC}"

# Check if package bc exists
if ! command -v bc &>/dev/null; then
  echo -e "${RED}[ERREUR] Le paquet 'bc' est manquant. Installez-le avec : sudo pacman -S bc${NC}"
  exit 1
fi

# Variables
rofi_theme="$HOME/.config/rofi/config-wallpaper.rasi"
focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')

# Ensure focused_monitor is detected
if [[ -z "$focused_monitor" ]]; then
  echo -e "${RED}[ERREUR] Impossible de détecter le moniteur actif via hyprctl.${NC}"
  exit 1
fi
echo -e "${YELLOW}[INFO] Moniteur détecté : $focused_monitor${NC}"

# Monitor details
scale_factor=$(hyprctl monitors -j | jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .scale')
monitor_height=$(hyprctl monitors -j | jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .height')

icon_size=$(echo "scale=1; ($monitor_height * 3) / ($scale_factor * 150)" | bc)
adjusted_icon_size=$(echo "$icon_size" | awk '{if ($1 < 15) $1 = 20; if ($1 > 25) $1 = 25; print $1}')
rofi_override="element-icon{size:${adjusted_icon_size}%;}"

# Kill existing wallpaper daemons
kill_wallpaper_for_video() {
  swww kill 2>/dev/null
  pkill mpvpaper 2>/dev/null
  pkill swaybg 2>/dev/null
  pkill hyprpaper 2>/dev/null
}

kill_wallpaper_for_image() {
  pkill mpvpaper 2>/dev/null
  pkill swaybg 2>/dev/null
  pkill hyprpaper 2>/dev/null
}

# Retrieve wallpapers
mapfile -d '' PICS < <(find -L "${wallDIR}" -type f \( \
  -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o \
  -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.webp" -o \
  -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.webm" \) -print0)

RANDOM_PIC="${PICS[$((RANDOM % ${#PICS[@]}))]}"
RANDOM_PIC_NAME=". random"

# Rofi command
rofi_command="rofi -i -show -dmenu -config $rofi_theme -theme-str $rofi_override"

menu() {
  IFS=$'\n' sorted_options=($(sort <<<"${PICS[*]}"))
  printf "%s\x00icon\x1f%s\n" "$RANDOM_PIC_NAME" "$RANDOM_PIC"
  for pic_path in "${sorted_options[@]}"; do
    pic_name=$(basename "$pic_path")
    # Gestion des previews (simplifiée pour le terminal)
    printf "%s\x00icon\x1f%s\n" "$pic_name" "$pic_path"
  done
}

modify_startup_config() {
  local selected_file="$1"
  local startup_config="$HOME/.config/hypr/UserConfigs/Startup_Apps.conf"
  if [[ "$selected_file" =~ \.(mp4|mkv|mov|webm)$ ]]; then
    sed -i '/^\s*exec-once\s*=\s*swww-daemon\s*--format\s*xrgb\s*$/s/^/\#/' "$startup_config"
    sed -i '/^\s*#\s*exec-once\s*=\s*mpvpaper\s*.*$/s/^#\s*//;' "$startup_config"
    selected_file="${selected_file/#$HOME/\$HOME}"
    sed -i "s|^\$livewallpaper=.*|\$livewallpaper=\"$selected_file\"|" "$startup_config"
    echo -e "${YELLOW}[CONFIG] Startup_Apps.conf configuré pour VIDÉO.${NC}"
  else
    sed -i '/^\s*#\s*exec-once\s*=\s*swww-daemon\s*--format\s*xrgb\s*$/s/^\s*#\s*//;' "$startup_config"
    sed -i '/^\s*exec-once\s*=\s*mpvpaper\s*.*$/s/^/\#/' "$startup_config"
    echo -e "${YELLOW}[CONFIG] Startup_Apps.conf configuré pour IMAGE.${NC}"
  fi
}

apply_image_wallpaper() {
  local image_path="$1"
  kill_wallpaper_for_image
  if ! pgrep -x "swww-daemon" >/dev/null; then
    echo -e "${YELLOW}[INFO] Lancement de swww-daemon...${NC}"
    swww-daemon --format xrgb &
    sleep 1
  fi
  echo -e "${GREEN}[OK] Application de l'image : $(basename "$image_path")${NC}"
  swww img -o "$focused_monitor" "$image_path" $SWWW_PARAMS
  
  echo -e "${BLUE}[INFO] Lancement de Wallust et Refresh...${NC}"
  "$SCRIPTSDIR/WallustSwww.sh" "$image_path"
  sleep 2
  "$SCRIPTSDIR/Refresh.sh"
}

apply_video_wallpaper() {
  local video_path="$1"
  if ! command -v mpvpaper &>/dev/null; then
    echo -e "${RED}[ERREUR] mpvpaper n'est pas installé.${NC}"
    return 1
  fi
  kill_wallpaper_for_video
  echo -e "${GREEN}[OK] Application de la vidéo : $(basename "$video_path")${NC}"
  mpvpaper '*' -o "load-scripts=no no-audio --loop" "$video_path" &
}

main() {
  choice=$(menu | $rofi_command)
  choice=$(echo "$choice" | xargs)
  if [[ -z "$choice" ]]; then
    echo -e "${YELLOW}[INFO] Aucune sélection. Sortie.${NC}"
    exit 0
  fi

  if [[ "$choice" == "$RANDOM_PIC_NAME" ]]; then
    choice=$(basename "$RANDOM_PIC")
  fi

  choice_basename=$(basename "$choice" | sed 's/\(.*\)\.[^.]*$/\1/')
  selected_file=$(find "$wallDIR" -iname "$choice_basename.*" -print -quit)

  if [[ -z "$selected_file" ]]; then
    echo -e "${RED}[ERREUR] Fichier introuvable : $choice${NC}"
    exit 1
  fi

  modify_startup_config "$selected_file"

  if [[ "$selected_file" =~ \.(mp4|mkv|mov|webm|MP4|MKV|MOV|WEBM)$ ]]; then
    apply_video_wallpaper "$selected_file"
  else
    apply_image_wallpaper "$selected_file"
  fi

  echo -e "${GREEN}--- CHANGEMENT TERMINÉ AVEC SUCCÈS ---${NC}"
}

# Check if rofi is already running
if pidof rofi >/dev/null; then
  pkill rofi
fi

main