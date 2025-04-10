#!/bin/bash
# Script de sauvegarde et restauration de dotfiles personnels
# Inspiré par le script d'installation de JaKooLit
# Version améliorée avec sauvegarde complète

clear

# Couleurs pour les messages
OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
CAT="$(tput setaf 6)[ACTION]$(tput sgr0)"
MAGENTA="$(tput setaf 5)"
ORANGE="$(tput setaf 214)"
WARNING="$(tput setaf 1)"
YELLOW="$(tput setaf 3)"
GREEN="$(tput setaf 2)"
BLUE="$(tput setaf 4)"
SKY_BLUE="$(tput setaf 6)"
RESET="$(tput sgr0)"

# Variables
DOTFILES_DIR="$HOME/ArchDots"
BACKUP_DIR="$DOTFILES_DIR/backups"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
CONFIG_FILE="$DOTFILES_DIR/config.conf"
LOG_DIR="$DOTFILES_DIR/logs"
LOG="$LOG_DIR/backup-$(date +%Y%m%d-%H%M%S).log"

# URL du dépôt GitHub (ton dépôt spécifié)
GIT_REPO_URL="https://github.com/TMCooper/ArchDots"

# Création des répertoires nécessaires
mkdir -p "$BACKUP_DIR" "$SCRIPTS_DIR" "$LOG_DIR"

# Vérification si en root
if [[ $EUID -eq 0 ]]; then
    echo "${ERROR} Ce script ne doit PAS être exécuté en tant que root! Sortie..." | tee -a "$LOG"
    exit 1
fi

# Installer whiptail si nécessaire
if ! command -v whiptail >/dev/null; then
    echo "${NOTE} - whiptail n'est pas installé. Installation en cours..." | tee -a "$LOG"
    sudo pacman -S --noconfirm libnewt
fi

clear

echo -e "\e[35m
	╔═══════════════════════════════════════════╗
	║  ██████╗ ██████╗  ██████╗██╗  ██╗██████╗  ██████╗ ████████╗███████╗  ║
	║  ██╔══██╗██╔══██╗██╔════╝██║  ██║██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝  ║
	║  ██████╔╝██████╔╝██║     ███████║██║  ██║██║   ██║   ██║   ███████╗  ║
	║  ██╔═══╝ ██╔══██╗██║     ██╔══██║██║  ██║██║   ██║   ██║   ╚════██║  ║
	║  ██║     ██║  ██║╚██████╗██║  ██║██████╔╝╚██████╔╝   ██║   ███████║  ║
	║  ╚═╝     ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═════╝  ╚═════╝    ╚═╝   ╚══════╝  ║
	╚═══════════════════════════════════════════╝
\e[0m"

# Message de bienvenue
whiptail --title "Gestionnaire de dotfiles pour ArchDots" \
    --msgbox "Bienvenue dans votre gestionnaire de dotfiles personnel!\n\n\
Ce script vous aidera à sauvegarder et restaurer vos fichiers de configuration et applications.\n\n\
Dépôt configuré: ${GIT_REPO_URL}" \
    15 70

# Définition des dotfiles par défaut à sauvegarder
DEFAULT_DOTFILES=(
    ".config/hypr"
    ".config/waybar"
    ".config/kitty"
    ".config/rofi"
    ".config/swappy"
    ".config/dunst"
    ".config/fastfetch"
    ".config/wlogout"
    ".config/nwg-look"
    ".config/wofi"
    ".config/gtk-3.0"
    ".config/gtk-4.0"
    ".zshrc"
    ".bashrc"
    ".xinitrc"
    ".Xresources"
    ".bash_history"
    ".bash_logout"
    ".bash_profile"
    ".gitconfig"
    ".gnupg"
    ".icons"
    ".local/share/fonts"
    ".local/share/icons"
    ".local/share/themes"
    ".mozilla/firefox/profiles.ini"
    ".oh-my-zsh"
    ".ssh"
    ".themes"
    ".zprofile"
    ".zsh_history"
)

# Création ou chargement du fichier de configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    # Stocker la liste des dotfiles dans le fichier de configuration
    echo "# Configuration du gestionnaire de dotfiles" > "$CONFIG_FILE"
    echo "# URL du dépôt Git" >> "$CONFIG_FILE"
    echo "GIT_REPO_URL=\"$GIT_REPO_URL\"" >> "$CONFIG_FILE"
    echo "# Liste des dotfiles à sauvegarder" >> "$CONFIG_FILE"
    echo "DOTFILES=(" >> "$CONFIG_FILE"
    for dotfile in "${DEFAULT_DOTFILES[@]}"; do
        echo "    \"$dotfile\"" >> "$CONFIG_FILE"
    done
    echo ")" >> "$CONFIG_FILE"
    
    # Charger la configuration nouvellement créée
    source "$CONFIG_FILE"
fi

# Fonction pour sauvegarder la liste des paquets installés
backup_packages() {
    echo "${INFO} Sauvegarde de la liste des paquets installés..." | tee -a "$LOG"
    
    # Créer le répertoire pour les listes de paquets
    mkdir -p "$DOTFILES_DIR/packages"
    
    # Sauvegarder tous les paquets explicitement installés
    pacman -Qe > "$DOTFILES_DIR/packages/pacman-explicit.txt"
    echo "${OK} Liste des paquets explicitement installés sauvegardée" | tee -a "$LOG"
    
    # Sauvegarder tous les paquets (y compris les dépendances)
    pacman -Q > "$DOTFILES_DIR/packages/pacman-all.txt"
    echo "${OK} Liste complète des paquets sauvegardée" | tee -a "$LOG"
    
    # Sauvegarder les paquets AUR si yay est installé
    if command -v yay &>/dev/null; then
        yay -Qm > "$DOTFILES_DIR/packages/aur-packages.txt"
        echo "${OK} Liste des paquets AUR sauvegardée" | tee -a "$LOG"
    elif command -v paru &>/dev/null; then
        paru -Qm > "$DOTFILES_DIR/packages/aur-packages.txt"
        echo "${OK} Liste des paquets AUR sauvegardée" | tee -a "$LOG"
    fi
    
    echo "${OK} Sauvegarde des paquets terminée" | tee -a "$LOG"
}

# Fonction pour restaurer les paquets
restore_packages() {
    if [ -f "$DOTFILES_DIR/packages/pacman-explicit.txt" ]; then
        echo "${INFO} Réinstallation des paquets..." | tee -a "$LOG"
        
        if whiptail --title "Restauration des paquets" --yesno "Voulez-vous réinstaller tous les paquets listés?" 10 60; then
            # Installation des paquets avec pacman
            cat "$DOTFILES_DIR/packages/pacman-explicit.txt" | grep -v "$(pacman -Qmq)" | awk '{print $1}' | while read pkg; do
                if ! pacman -Q "$pkg" &>/dev/null; then
                    echo "${INFO} Installation de $pkg..." | tee -a "$LOG"
                    sudo pacman -S --noconfirm --needed "$pkg" | tee -a "$LOG"
                fi
            done
            
            # Installation des paquets AUR si disponible
            if [ -f "$DOTFILES_DIR/packages/aur-packages.txt" ]; then
                if command -v yay &>/dev/null; then
                    cat "$DOTFILES_DIR/packages/aur-packages.txt" | awk '{print $1}' | while read pkg; do
                        if ! pacman -Q "$pkg" &>/dev/null; then
                            echo "${INFO} Installation du paquet AUR: $pkg..." | tee -a "$LOG"
                            yay -S --noconfirm --needed "$pkg" | tee -a "$LOG"
                        fi
                    done
                elif command -v paru &>/dev/null; then
                    cat "$DOTFILES_DIR/packages/aur-packages.txt" | awk '{print $1}' | while read pkg; do
                        if ! pacman -Q "$pkg" &>/dev/null; then
                            echo "${INFO} Installation du paquet AUR: $pkg..." | tee -a "$LOG"
                            paru -S --noconfirm --needed "$pkg" | tee -a "$LOG"
                        fi
                    done
                else
                    echo "${NOTE} Aucun helper AUR trouvé (yay ou paru). Installation des paquets AUR ignorée." | tee -a "$LOG"
                    echo "${NOTE} Vous devrez installer manuellement les paquets AUR listés dans: $DOTFILES_DIR/packages/aur-packages.txt" | tee -a "$LOG"
                fi
            fi
            
            echo "${OK} Restauration des paquets terminée!" | tee -a "$LOG"
        fi
    else
        echo "${NOTE} Aucune liste de paquets trouvée." | tee -a "$LOG"
    fi
}

# Fonction pour configurer l'authentification Git
setup_git_auth() {
    echo "${INFO} Configuration de l'authentification Git..." | tee -a "$LOG"
    
    auth_method=$(whiptail --title "Authentification Git" --menu \
        "Choisissez une méthode d'authentification pour les dépôts privés:" 15 60 4 \
        "1" "Identifiants dans l'URL (https://user:token@github.com)" \
        "2" "SSH (git@github.com)" \
        "3" "Credential Manager (stockage des identifiants)" \
        "4" "Rendre le dépôt public (recommandé)" \
        3>&1 1>&2 2>&3)
    
    case $auth_method in
        1)
            username=$(whiptail --title "Nom d'utilisateur GitHub" --inputbox "Entrez votre nom d'utilisateur GitHub:" 8 60 3>&1 1>&2 2>&3)
            token=$(whiptail --title "Token GitHub" --passwordbox "Entrez votre token d'accès personnel GitHub:" 8 60 3>&1 1>&2 2>&3)
            
            # Mettre à jour l'URL avec les identifiants
            repo_base_url=$(echo "$GIT_REPO_URL" | sed 's/https:\/\///')
            GIT_REPO_URL="https://${username}:${token}@${repo_base_url}"
            
            # Mettre à jour le fichier de configuration
            sed -i "s|GIT_REPO_URL=.*|GIT_REPO_URL=\"$GIT_REPO_URL\"|" "$CONFIG_FILE"
            
            echo "${OK} URL du dépôt mise à jour avec identifiants." | tee -a "$LOG"
            echo "${NOTE} Attention: vos identifiants sont stockés en clair dans le fichier config." | tee -a "$LOG"
            ;;
        2)
            # Convertir l'URL HTTPS en URL SSH
            ssh_url=$(echo "$GIT_REPO_URL" | sed 's|https://github.com/|git@github.com:|')
            GIT_REPO_URL="$ssh_url"
            
            # Mettre à jour le fichier de configuration
            sed -i "s|GIT_REPO_URL=.*|GIT_REPO_URL=\"$GIT_REPO_URL\"|" "$CONFIG_FILE"
            
            echo "${INFO} Vérification de la présence d'une clé SSH..." | tee -a "$LOG"
            if [ ! -f "$HOME/.ssh/id_ed25519" ] && [ ! -f "$HOME/.ssh/id_rsa" ]; then
                whiptail --title "Clé SSH" --yesno "Aucune clé SSH détectée. Voulez-vous en générer une maintenant?" 8 60
                if [ $? -eq 0 ]; then
                    ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)"
                    echo "${OK} Clé SSH générée." | tee -a "$LOG"
                    echo "${NOTE} N'oubliez pas d'ajouter cette clé à votre compte GitHub:" | tee -a "$LOG"
                    cat "$HOME/.ssh/id_ed25519.pub" | tee -a "$LOG"
                fi
            else
                echo "${OK} Clé SSH trouvée." | tee -a "$LOG"
            fi
            ;;
        3)
            # Configurer Git pour stocker les identifiants
            git config --global credential.helper store
            echo "${OK} Git configuré pour stocker les identifiants." | tee -a "$LOG"
            echo "${NOTE} Vous serez invité à entrer vos identifiants lors du premier push." | tee -a "$LOG"
            ;;
        4)
            whiptail --title "Dépôt public" --msgbox "Pour rendre votre dépôt public:\n\n1. Connectez-vous à votre compte GitHub\n2. Accédez à votre dépôt\n3. Allez dans 'Settings' (Paramètres)\n4. Descendez jusqu'à 'Danger Zone'\n5. Cliquez sur 'Change visibility'\n6. Sélectionnez 'Public'" 15 60
            ;;
    esac
}

# Fonction pour sauvegarder les dotfiles
backup_dotfiles() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local current_backup_dir="$BACKUP_DIR/$timestamp"
    
    echo "${INFO} Sauvegarde des dotfiles en cours..." | tee -a "$LOG"
    mkdir -p "$current_backup_dir"
    
    # Sauvegarder chaque dotfile dans la liste
    for dotfile in "${DOTFILES[@]}"; do
        src_path="$HOME/$dotfile"
        dest_dir="$current_backup_dir/$(dirname "$dotfile")"
        
        if [ -e "$src_path" ]; then
            mkdir -p "$dest_dir"
            cp -r "$src_path" "$dest_dir/"
            echo "${OK} Sauvegardé: $dotfile" | tee -a "$LOG"
        else
            echo "${NOTE} Ignoré (n'existe pas): $dotfile" | tee -a "$LOG"
        fi
    done
    
    # Copier dans le dépôt principal
    for dotfile in "${DOTFILES[@]}"; do
        src_path="$HOME/$dotfile"
        dest_path="$DOTFILES_DIR/current/$dotfile"
        
        if [ -e "$src_path" ]; then
            mkdir -p "$(dirname "$dest_path")"
            cp -r "$src_path" "$(dirname "$dest_path")/"
        fi
    done
    
    # Sauvegarder la liste des paquets installés
    backup_packages
    
    echo "${OK} Sauvegarde terminée dans: $current_backup_dir" | tee -a "$LOG"
    
    # Gérer Git si souhaité
    if whiptail --title "Git" --yesno "Voulez-vous effectuer un commit Git des changements?" 8 60; then
        setup_git_repo
        cd "$DOTFILES_DIR"
        git add .
        git commit -m "Sauvegarde des dotfiles et paquets - $timestamp"
        echo "${OK} Changements commités dans le dépôt local Git" | tee -a "$LOG"
        
        if whiptail --title "Git Push" --yesno "Voulez-vous pousser les changements vers le dépôt distant?" 8 60; then
            if git remote -v | grep origin > /dev/null; then
                # Essayer de pousser vers le dépôt distant
                if git push origin master 2>&1 | tee -a "$LOG"; then
                    echo "${OK} Changements poussés vers le dépôt distant" | tee -a "$LOG"
                else
                    echo "${ERROR} Échec du push vers le dépôt distant." | tee -a "$LOG"
                    whiptail --title "Problème d'accès" --yesno "Problème d'accès au dépôt distant. Voulez-vous configurer l'authentification?" 8 60
                    if [ $? -eq 0 ]; then
                        setup_git_auth
                        # Réessayer après configuration
                        if git push origin master 2>&1 | tee -a "$LOG"; then
                            echo "${OK} Changements poussés avec succès après configuration d'authentification" | tee -a "$LOG"
                        else
                            echo "${ERROR} Échec persistant. Vérifiez vos paramètres d'authentification." | tee -a "$LOG"
                        fi
                    fi
                fi
            else
                git remote add origin "$GIT_REPO_URL"
                # Essayer de pousser vers le dépôt distant
                if git push -u origin master 2>&1 | tee -a "$LOG"; then
                    echo "${OK} Changements poussés vers le dépôt distant" | tee -a "$LOG"
                else
                    echo "${ERROR} Échec du push vers le dépôt distant." | tee -a "$LOG"
                    whiptail --title "Problème d'accès" --yesno "Problème d'accès au dépôt distant. Voulez-vous configurer l'authentification?" 8 60
                    if [ $? -eq 0 ]; then
                        setup_git_auth
                        # Réessayer après configuration
                        if git push -u origin master 2>&1 | tee -a "$LOG"; then
                            echo "${OK} Changements poussés avec succès après configuration d'authentification" | tee -a "$LOG"
                        else
                            echo "${ERROR} Échec persistant. Vérifiez vos paramètres d'authentification." | tee -a "$LOG"
                        fi
                    fi
                fi
            fi
        fi
    fi
}

# Fonction pour cloner le dépôt distant
clone_remote_repo() {
    echo "${INFO} Tentative de clonage du dépôt distant..." | tee -a "$LOG"
    
    # Vérifier si le répertoire de destination existe déjà
    if [ -d "$DOTFILES_DIR" ]; then
        if [ -d "$DOTFILES_DIR/.git" ]; then
            echo "${NOTE} Le dépôt existe déjà localement. Mise à jour..." | tee -a "$LOG"
            cd "$DOTFILES_DIR"
            
            # Essayer de mettre à jour
            if ! git pull 2>&1 | tee -a "$LOG"; then
                whiptail --title "Problème d'accès" --yesno "Problème d'accès au dépôt distant. Voulez-vous configurer l'authentification?" 8 60
                if [ $? -eq 0 ]; then
                    setup_git_auth
                    # Réessayer après configuration
                    git pull 2>&1 | tee -a "$LOG"
                fi
            fi
        else
            echo "${WARN} Le répertoire existe mais n'est pas un dépôt Git. Sauvegarde..." | tee -a "$LOG"
            mv "$DOTFILES_DIR" "${DOTFILES_DIR}.bak-$(date +%Y%m%d-%H%M%S)"
            
            # Essayer de cloner
            if ! git clone "$GIT_REPO_URL" "$DOTFILES_DIR" 2>&1 | tee -a "$LOG"; then
                whiptail --title "Problème d'accès" --yesno "Problème d'accès au dépôt distant. Voulez-vous configurer l'authentification?" 8 60
                if [ $? -eq 0 ]; then
                    setup_git_auth
                    # Réessayer après configuration
                    git clone "$GIT_REPO_URL" "$DOTFILES_DIR" 2>&1 | tee -a "$LOG"
                fi
            fi
        fi
    else
        # Essayer de cloner
        if ! git clone "$GIT_REPO_URL" "$DOTFILES_DIR" 2>&1 | tee -a "$LOG"; then
            whiptail --title "Problème d'accès" --yesno "Problème d'accès au dépôt distant. Voulez-vous configurer l'authentification?" 8 60
            if [ $? -eq 0 ]; then
                setup_git_auth
                # Réessayer après configuration
                git clone "$GIT_REPO_URL" "$DOTFILES_DIR" 2>&1 | tee -a "$LOG"
            fi
        fi
    fi
    
    # Recharger la configuration si elle existe dans le dépôt cloné
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo "${OK} Configuration chargée depuis le dépôt." | tee -a "$LOG"
    fi
}

# Fonction pour restaurer des dotfiles
restore_dotfiles() {
    local backup_list=()
    local i=1
    
    # Liste toutes les sauvegardes disponibles
    for backup in "$BACKUP_DIR"/*; do
        if [ -d "$backup" ]; then
            backup_name=$(basename "$backup")
            backup_list+=("$backup_name" "Sauvegarde du $(date -d "${backup_name:0:8}" +"%d/%m/%Y à %H:%M:%S")" "$i")
            ((i++))
        fi
    done
    
    # Ajouter l'option pour utiliser la configuration actuelle
    if [ -d "$DOTFILES_DIR/current" ]; then
        backup_list=("current" "Configuration actuelle (dernière sauvegarde)" "0" "${backup_list[@]}")
    fi
    
    # Si aucune sauvegarde n'existe
    if [ ${#backup_list[@]} -eq 0 ]; then
        whiptail --title "Restauration" --msgbox "Aucune sauvegarde trouvée. Veuillez faire une sauvegarde d'abord ou cloner le dépôt distant." 8 60
        
        # Proposer de cloner le dépôt distant
        if whiptail --title "Clonage" --yesno "Voulez-vous essayer de cloner le dépôt distant?" 8 60; then
            clone_remote_repo
            return
        else
            return
        fi
    fi
    
    # Demander à l'utilisateur de choisir une sauvegarde
    selected_backup=$(whiptail --title "Restauration" --menu "Choisissez une sauvegarde à restaurer:" 20 70 10 "${backup_list[@]}" 3>&1 1>&2 2>&3)
    
    if [ $? -ne 0 ]; then
        echo "${NOTE} Restauration annulée." | tee -a "$LOG"
        return
    fi
    
    # Restaurer la sauvegarde sélectionnée
    local src_dir
    if [ "$selected_backup" = "current" ]; then
        src_dir="$DOTFILES_DIR/current"
    else
        src_dir="$BACKUP_DIR/$selected_backup"
    fi
    
    echo "${INFO} Restauration de la sauvegarde: $selected_backup" | tee -a "$LOG"
    whiptail --title "Attention" --yesno "Cette opération va remplacer vos fichiers de configuration actuels. Continuer?" 8 70
    
    if [ $? -ne 0 ]; then
        echo "${NOTE} Restauration annulée par l'utilisateur." | tee -a "$LOG"
        return
    fi
    
    # Restaurer chaque dotfile
    for dotfile in "${DOTFILES[@]}"; do
        src_path="$src_dir/$dotfile"
        dest_path="$HOME/$dotfile"
        
        if [ -e "$src_path" ]; then
            # Créer une sauvegarde de sécurité avant de remplacer
            if [ -e "$dest_path" ]; then
                backup_path="$dest_path.bak-$(date +%Y%m%d-%H%M%S)"
                mv "$dest_path" "$backup_path"
                echo "${NOTE} Sauvegarde de sécurité créée: $backup_path" | tee -a "$LOG"
            fi
            
            mkdir -p "$(dirname "$dest_path")"
            cp -r "$src_path" "$(dirname "$dest_path")/"
            echo "${OK} Restauré: $dotfile" | tee -a "$LOG"
        else
            echo "${NOTE} Ignoré (n'existe pas dans la sauvegarde): $dotfile" | tee -a "$LOG"
        fi
    done
    
    # Demander si l'utilisateur souhaite restaurer les paquets
    if [ -f "$DOTFILES_DIR/packages/pacman-explicit.txt" ]; then
        whiptail --title "Restauration des paquets" --yesno "Voulez-vous également restaurer les paquets installés?" 8 60
        if [ $? -eq 0 ]; then
            restore_packages
        fi
    fi
    
    echo "${OK} Restauration terminée!" | tee -a "$LOG"
}

# Fonction pour éditer la liste des dotfiles
edit_dotfiles_list() {
    local temp_file=$(mktemp)
    
    # Écrire la liste actuelle dans un fichier temporaire
    for dotfile in "${DOTFILES[@]}"; do
        echo "$dotfile" >> "$temp_file"
    done
    
    # Demander à l'utilisateur d'éditer la liste
    if ! command -v nano &> /dev/null; then
        sudo pacman -S --noconfirm nano
    fi
    
    nano "$temp_file"
    
    # Lire la nouvelle liste et mettre à jour la configuration
    readarray -t new_dotfiles < "$temp_file"
    
    echo "# Configuration du gestionnaire de dotfiles" > "$CONFIG_FILE"
    echo "# URL du dépôt Git" >> "$CONFIG_FILE"
    echo "GIT_REPO_URL=\"$GIT_REPO_URL\"" >> "$CONFIG_FILE"
    echo "# Liste des dotfiles à sauvegarder" >> "$CONFIG_FILE"
    echo "DOTFILES=(" >> "$CONFIG_FILE"
    for dotfile in "${new_dotfiles[@]}"; do
        if [ -n "$dotfile" ]; then
            echo "    \"$dotfile\"" >> "$CONFIG_FILE"
        fi
    done
    echo ")" >> "$CONFIG_FILE"
    
    # Recharger la configuration
    source "$CONFIG_FILE"
    
    # Supprimer le fichier temporaire
    rm "$temp_file"
    
    echo "${OK} Liste des dotfiles mise à jour." | tee -a "$LOG"
}

# Fonction pour configurer un dépôt Git
setup_git_repo() {
    if [ ! -d "$DOTFILES_DIR/.git" ]; then
        cd "$DOTFILES_DIR"
        git init
        git config --local user.name "$(whoami)"
        git config --local user.email "$(whoami)@$(hostname)"
        echo "# Mes dotfiles ArchDots" > README.md
        git add README.md
        git commit -m "Initial commit"
        
        # Configurer le dépôt distant
        git remote add origin "$GIT_REPO_URL"
        
        echo "${OK} Dépôt Git initialisé dans $DOTFILES_DIR" | tee -a "$LOG"
    fi
}

# Fonction pour installer les packages de base
install_base_packages() {
    # Liste des packages essentiels pour la gestion des dotfiles
    local packages=("git" "base-devel" "rsync" "curl" "wget")
    
    echo "${INFO} Vérification et installation des packages nécessaires..." | tee -a "$LOG"
    
    for pkg in "${packages[@]}"; do
        if ! pacman -Q "$pkg" &> /dev/null; then
            echo "${NOTE} Installation de $pkg..." | tee -a "$LOG"
            sudo pacman -S --noconfirm "$pkg"
        else
            echo "${OK} $pkg est déjà installé." | tee -a "$LOG"
        fi
    done
}

# Fonction pour installer depuis zéro
install_from_scratch() {
    whiptail --title "Installation depuis zéro" --msgbox "Cette option va cloner votre dépôt distant et installer vos dotfiles et paquets.\n\nAssurez-vous que votre dépôt GitHub contient déjà vos dotfiles ou que vous avez correctement configuré l'accès." 10 70
    
    # Cloner le dépôt distant
    clone_remote_repo
    
    # Installer les paquets de base nécessaires
    install_base_packages
    
    # Installer les paquets sauvegardés si disponibles
    if [ -f "$DOTFILES_DIR/packages/pacman-explicit.txt" ]; then
        whiptail --title "Restauration des paquets" --yesno "Voulez-vous installer les paquets sauvegardés?" 8 60
        if [ $? -eq 0 ]; then
            restore_packages
        fi
    fi
    
    # Restaurer les dotfiles
    if [ -d "$DOTFILES_DIR/current" ]; then
        whiptail --title "Restauration des dotfiles" --yesno "Voulez-vous restaurer les dotfiles sauvegardés?" 8 60
        if [ $? -eq 0 ]; then
            restore_dotfiles
        fi
    fi
    
    echo "${OK} Installation depuis zéro terminée!" | tee -a "$LOG"
}

# Menu principal
while true; do
    CHOICE=$(whiptail --title "Gestionnaire de dotfiles ArchDots" --menu "Choisissez une option:" 18 70 10 \
        "1" "Sauvegarder vos dotfiles" \
        "2" "Restaurer des dotfiles" \
        "3" "Éditer la liste des dotfiles à sauvegarder" \
        "4" "Configurer l'accès au dépôt Git" \
        "5" "Installation depuis zéro (nouvelle machine)" \
        "6" "Voir les logs" \
        "7" "Quitter" \
        3>&1 1>&2 2>&3)
    
    exit_status=$?
    if [ $exit_status -ne 0 ]; then
        echo "${NOTE} Sortie du programme." | tee -a "$LOG"
        exit 0
    fi
    
    case $CHOICE in
        1)
            backup_dotfiles
            ;;
        2)
            restore_dotfiles
            ;;
        3)
            edit_dotfiles_list
            ;;
        4)
            setup_git_auth
            ;;
        5)
            install_from_scratch
            ;;
        6)
            if [ -d "$LOG_DIR" ]; then
                LOG_FILES=()
                for log in "$LOG_DIR"/*.log; do
                    if [ -f "$log" ]; then
                        log_name=$(basename "$log")
                        LOG_FILES+=("$log_name" "$(date -r "$log" '+%Y-%m-%d %H:%M:%S')")
                    fi
                done
                
                if [ ${#LOG_FILES[@]} -eq 0 ]; then
                    whiptail --title "Logs" --msgbox "Aucun fichier de log trouvé." 8 50
                else
                    SELECTED_LOG=$(whiptail --title "Logs" --menu "Choisissez un fichier de log à afficher:" 20 70 10 "${LOG_FILES[@]}" 3>&1 1>&2 2>&3)
                    if [ $? -eq 0 ]; then
                        if ! command -v less &> /dev/null; then
                            sudo pacman -S --noconfirm less
                        fi
                        less "$LOG_DIR/$SELECTED_LOG"
                    fi
                fi
            else
                whiptail --title "Logs" --msgbox "Répertoire de logs non trouvé." 8 50
            fi
            ;;
        7)
            echo "${NOTE} Au revoir!" | tee -a "$LOG"
            exit 0
            ;;
    esac
done
