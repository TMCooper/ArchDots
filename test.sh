#!/bin/bash
# arch-backup-restore.sh
# Script combiné pour sauvegarder et restaurer la configuration d'Arch Linux

# Définir le répertoire du dépôt Git (le répertoire courant si le script est exécuté depuis le dépôt)
REPO_DIR="$(pwd)"

# Fonction de sauvegarde
backup_system() {
  echo "===== SAUVEGARDE DU SYSTÈME ====="
  
  # On suppose que le script est déjà dans un dépôt Git cloné
  # Vérifier qu'on est bien dans un dépôt Git
  if [ ! -d "$REPO_DIR/.git" ]; then
    echo "ERREUR: Ce répertoire ne semble pas être un dépôt Git."
    echo "Assurez-vous d'exécuter ce script depuis le dépôt Git ArchDots cloné."
    exit 1
  fi

  # Sauvegarder la liste des paquets installés
  echo "Sauvegarde de la liste des paquets installés..."
  pacman -Qqe > "$REPO_DIR/packages.txt"
  pacman -Qqem > "$REPO_DIR/aur_packages.txt"

  # Créer un répertoire pour les fichiers de configuration
  mkdir -p "$REPO_DIR/config"

  # Sauvegarde des configurations importantes
  echo "Sauvegarde des fichiers de configuration..."
  cp -r "$HOME/.config" "$REPO_DIR/config/"

  # Ajout d'autres fichiers de configuration importants
  cp "$HOME/.bashrc" "$REPO_DIR/" 2>/dev/null
  cp "$HOME/.zshrc" "$REPO_DIR/" 2>/dev/null
  cp "$HOME/.xinitrc" "$REPO_DIR/" 2>/dev/null
  sudo cp "/etc/fstab" "$REPO_DIR/" 2>/dev/null

  # Commit et push des changements
  echo "Commit et push des changements..."
  git add .
  git commit -m "Sauvegarde automatique $(date +'%Y-%m-%d %H:%M:%S')"
  git push origin master

  echo "Sauvegarde terminée avec succès!"
}

# Fonction de restauration
restore_system() {
  echo "===== RESTAURATION DU SYSTÈME ====="
  
  # On suppose que le script est déjà dans un dépôt Git cloné
  # Vérifier qu'on est bien dans un dépôt Git
  if [ ! -d "$REPO_DIR/.git" ]; then
    echo "ERREUR: Ce répertoire ne semble pas être un dépôt Git."
    echo "Assurez-vous d'exécuter ce script depuis le dépôt Git ArchDots cloné."
    exit 1
  fi

  # Mettre à jour le dépôt local
  echo "Mise à jour du dépôt..."
  git pull origin master

  # Installer les paquets officiels
  echo "Installation des paquets officiels..."
  if [ -f "$REPO_DIR/packages.txt" ]; then
    sudo pacman -S --needed - < "$REPO_DIR/packages.txt"
  else
    echo "Fichier packages.txt non trouvé!"
  fi

  # Installer yay si nécessaire pour les paquets AUR
  if [ -f "$REPO_DIR/aur_packages.txt" ] && [ "$(wc -l < "$REPO_DIR/aur_packages.txt")" -gt 0 ]; then
    if ! command -v yay &> /dev/null; then
      echo "Installation de yay..."
      git clone https://aur.archlinux.org/yay.git /tmp/yay
      cd /tmp/yay
      makepkg -si --noconfirm
      cd "$REPO_DIR"
    fi

    # Installer les paquets AUR
    echo "Installation des paquets AUR..."
    yay -S --needed - < "$REPO_DIR/aur_packages.txt"
  fi

  # Restaurer les fichiers de configuration
  echo "Restauration des fichiers de configuration..."
  if [ -d "$REPO_DIR/config/.config" ]; then
    mkdir -p "$HOME/.config"
    cp -r "$REPO_DIR/config/.config/"* "$HOME/.config/"
  else
    echo "Dossier de configuration non trouvé!"
  fi

  # Restaurer les autres fichiers de configuration
  [ -f "$REPO_DIR/.bashrc" ] && cp "$REPO_DIR/.bashrc" "$HOME/"
  [ -f "$REPO_DIR/.zshrc" ] && cp "$REPO_DIR/.zshrc" "$HOME/"
  [ -f "$REPO_DIR/.xinitrc" ] && cp "$REPO_DIR/.xinitrc" "$HOME/"
  
  # Optionnel: restaurer fstab (nécessite des privilèges root)
  if [ -f "$REPO_DIR/fstab" ]; then
    echo "Voulez-vous restaurer le fichier fstab? (ATTENTION: Cela peut affecter le démarrage du système) [o/N]"
    read -r response
    if [[ "$response" =~ ^([oO])$ ]]; then
      sudo cp "$REPO_DIR/fstab" /etc/fstab
      echo "fstab restauré."
    fi
  fi

  echo "Restauration terminée avec succès!"
}

# Afficher le menu
show_menu() {
  clear
  echo "============================================"
  echo " Utilitaire de sauvegarde/restauration Arch "
  echo "============================================"
  echo "1. Sauvegarder la configuration"
  echo "2. Restaurer la configuration"
  echo "3. Quitter"
  echo
  echo -n "Choisissez une option [1-3]: "
  read -r choice
  
  case $choice in
    1) backup_system ;;
    2) restore_system ;;
    3) exit 0 ;;
    *) echo "Option invalide. Appuyez sur Entrée pour continuer..."
       read -r
       show_menu ;;
  esac
}

# Gérer les arguments en ligne de commande
if [ "$#" -eq 0 ]; then
  show_menu
else
  case "$1" in
    backup|save) backup_system ;;
    restore) restore_system ;;
    *) echo "Usage: $0 [backup|restore]"
       echo "Ou exécutez sans arguments pour afficher le menu"
       exit 1 ;;
  esac
fi
