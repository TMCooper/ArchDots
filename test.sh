#!/bin/bash
# Arch Linux Dotfiles & Packages Manager
# Script amélioré pour sauvegarder et restaurer les configurations et packages

# Variables
DOTFILES_DIR="$HOME/ArchDots"
BACKUP_DIR="$DOTFILES_DIR/backups"
CONFIG_DIR="$DOTFILES_DIR/current"
PACKAGES_DIR="$DOTFILES_DIR/packages"
LOG_DIR="$DOTFILES_DIR/logs"
LOG_FILE="$LOG_DIR/backup-$(date +%Y%m%d-%H%M%S).log"
GIT_REPO_URL="https://github.com/TMCooper/ArchDots"

# Créer les répertoires nécessaires
mkdir -p "$BACKUP_DIR" "$CONFIG_DIR" "$PACKAGES_DIR" "$LOG_DIR"

# Couleurs pour le terminal
OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"

# Liste des dotfiles par défaut à sauvegarder
DOTFILES=(
    # Configurations graphiques et environnement
    ".config/hypr"
    ".config/waybar"
    ".config/swaync"
    ".config/rofi"
    ".config/kitty"
    ".config/cava"
    ".config/fastfetch"
    ".config/swappy"
    ".config/dunst"
    ".config/wlogout"
    ".config/wofi"
    
    # Thèmes et styles
    ".config/gtk-3.0"
    ".config/gtk-4.0"
    ".config/Kvantum"
    ".config/qt5ct"
    ".config/qt6ct"
    
    # Multimédia
    ".config/mpv"
    
    # Fichiers utilisateur importants
    ".zshrc"
    ".bashrc"
    ".xinitrc"
    ".Xresources"
)

# Vérifier si le script est exécuté en tant que root
if [[ $EUID -eq 0 ]]; then
    echo "${ERROR} Ce script ne doit PAS être exécuté en tant que root! Sortie..." | tee -a "$LOG_FILE"
    exit 1
fi

# Installer les dépendances de base
install_dependencies() {
    echo "${INFO} Vérification des dépendances..." | tee -a "$LOG_FILE"
    
    local packages=("git" "rsync" "curl" "wget" "whiptail")
    for pkg in "${packages[@]}"; do
        if ! pacman -Q "$pkg" &> /dev/null; then
            echo "${NOTE} Installation de $pkg..." | tee -a "$LOG_FILE"
            sudo pacman -S --noconfirm "$pkg"
        else
            echo "${OK} $pkg est déjà installé." | tee -a "$LOG_FILE"
        fi
    done
}

# Fonction pour configurer l'authentification Git
setup_git_auth() {
    echo "${INFO} Configuration de l'authentification Git..." | tee -a "$LOG_FILE"
    
    # Créer une config git locale
    if [ ! -d "$DOTFILES_DIR/.git" ]; then
        cd "$DOTFILES_DIR"
        git init
        git config --local user.name "$(whoami)"
        git config --local user.email "$(whoami)@$(hostname)"
        echo "# Mes dotfiles ArchDots" > README.md
        git add README.md
        git commit -m "Initial commit"
    fi
    
    # Configurer le token d'accès ou la clé SSH
    whiptail --title "Authentification Git" --menu \
        "Choisissez une méthode d'authentification:" 15 60 3 \
        "1" "Token d'accès GitHub (recommandé)" \
        "2" "SSH (nécessite une clé configurée)" \
        "3" "HTTPS (voulez-vous utiliser une URL publique?)" \
        3>&1 1>&2 2>&3
    
    case $? in
        0) # Token GitHub
            username=$(whiptail --title "GitHub Username" --inputbox "Entrez votre nom d'utilisateur GitHub:" 8 60 3>&1 1>&2 2>&3)
            token=$(whiptail --title "GitHub Token" --passwordbox "Entrez votre token d'accès GitHub:" 8 60 3>&1 1>&2 2>&3)
            
            if [ -n "$username" ] && [ -n "$token" ]; then
                # Formate l'URL avec le token
                repo_base=$(echo "$GIT_REPO_URL" | sed 's/https:\/\///')
                GIT_REPO_URL="https://${username}:${token}@${repo_base}"
                
                # Configure git pour stocker les credentials
                git config --global credential.helper store
                
                # Met à jour le remote
                cd "$DOTFILES_DIR"
                if git remote | grep -q "origin"; then
                    git remote set-url origin "$GIT_REPO_URL"
                else
                    git remote add origin "$GIT_REPO_URL"
                fi
                
                echo "${OK} Authentification configurée avec succès." | tee -a "$LOG_FILE"
            else
                echo "${ERROR} Informations d'authentification incomplètes." | tee -a "$LOG_FILE"
            fi
            ;;
        1) # SSH
            # Vérifie si une clé SSH existe
            if [ ! -f "$HOME/.ssh/id_ed25519" ] && [ ! -f "$HOME/.ssh/id_rsa" ]; then
                if whiptail --title "Clé SSH" --yesno "Aucune clé SSH détectée. Voulez-vous en générer une?" 8 60; then
                    ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)"
                    echo "${OK} Clé SSH générée." | tee -a "$LOG_FILE"
                    echo "${NOTE} Assurez-vous d'ajouter cette clé à votre compte GitHub:" | tee -a "$LOG_FILE"
                    cat "$HOME/.ssh/id_ed25519.pub"
                    
                    whiptail --title "Clé SSH" --msgbox "Après avoir ajouté votre clé SSH à GitHub, appuyez sur OK pour continuer." 8 60
                fi
            fi
            
            # Mettre à jour l'URL en format SSH
            ssh_url=$(echo "$GIT_REPO_URL" | sed 's|https://github.com/|git@github.com:|')
            GIT_REPO_URL="$ssh_url"
            
            # Met à jour le remote
            cd "$DOTFILES_DIR"
            if git remote | grep -q "origin"; then
                git remote set-url origin "$GIT_REPO_URL"
            else
                git remote add origin "$GIT_REPO_URL"
            fi
            
            echo "${OK} URL du dépôt mise à jour pour utiliser SSH." | tee -a "$LOG_FILE"
            ;;
        2) # HTTPS public
            # Vérifier si le dépôt est public
            if whiptail --title "Dépôt Public" --yesno "Assurez-vous que votre dépôt GitHub est bien public.\n\nEst-ce le cas?" 8 60; then
                # Mettre à jour le remote avec l'URL standard
                cd "$DOTFILES_DIR"
                if git remote | grep -q "origin"; then
                    git remote set-url origin "$GIT_REPO_URL"
                else
                    git remote add origin "$GIT_REPO_URL"
                fi
                
                echo "${OK} URL du dépôt configurée en mode public." | tee -a "$LOG_FILE"
            else
                whiptail --title "Dépôt Privé" --msgbox "Vous devez rendre votre dépôt public ou utiliser l'authentification par token/SSH." 8 60
            fi
            ;;
    esac
}

# Fonction pour sauvegarder les dotfiles
backup_dotfiles() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local current_backup_dir="$BACKUP_DIR/$timestamp"
    
    echo "${INFO} Sauvegarde des dotfiles en cours..." | tee -a "$LOG_FILE"
    mkdir -p "$current_backup_dir"
    
    # Sauvegarde chaque dotfile dans la liste
    for dotfile in "${DOTFILES[@]}"; do
        src_path="$HOME/$dotfile"
        
        if [ -e "$src_path" ]; then
            # Sauvegarder dans le backup avec timestamp
            dest_dir="$current_backup_dir/$(dirname "$dotfile")"
            mkdir -p "$dest_dir"
            cp -r "$src_path" "$dest_dir/"
            
            # Copier également dans le répertoire "current"
            dest_path="$CONFIG_DIR/$dotfile"
            mkdir -p "$(dirname "$dest_path")"
            cp -r "$src_path" "$(dirname "$dest_path")/"
            
            echo "${OK} Sauvegardé: $dotfile" | tee -a "$LOG_FILE"
        else
            echo "${NOTE} Ignoré (n'existe pas): $dotfile" | tee -a "$LOG_FILE"
        fi
    done
    
    echo "${OK} Sauvegarde des dotfiles terminée!" | tee -a "$LOG_FILE"
    return 0
}

# Fonction pour sauvegarder les packages installés
backup_packages() {
    echo "${INFO} Sauvegarde des packages installés..." | tee -a "$LOG_FILE"
    mkdir -p "$PACKAGES_DIR"
    
    # Packages explicitement installés
    pacman -Qe > "$PACKAGES_DIR/pacman-explicit.txt"
    echo "${OK} Packages explicitement installés sauvegardés" | tee -a "$LOG_FILE"
    
    # Tous les packages (y compris les dépendances)
    pacman -Q > "$PACKAGES_DIR/pacman-all.txt"
    echo "${OK} Liste complète des packages sauvegardée" | tee -a "$LOG_FILE"
    
    # Packages AUR (si yay ou paru est installé)
    if command -v yay &>/dev/null; then
        yay -Qm > "$PACKAGES_DIR/aur-packages.txt"
        echo "${OK} Packages AUR sauvegardés (yay)" | tee -a "$LOG_FILE"
    elif command -v paru &>/dev/null; then
        paru -Qm > "$PACKAGES_DIR/aur-packages.txt"
        echo "${OK} Packages AUR sauvegardés (paru)" | tee -a "$LOG_FILE"
    else
        echo "${NOTE} Aucun helper AUR trouvé (yay ou paru)" | tee -a "$LOG_FILE"
    fi
    
    echo "${OK} Sauvegarde des packages terminée!" | tee -a "$LOG_FILE"
    return 0
}

# Fonction pour commit et push des changements
commit_and_push() {
    cd "$DOTFILES_DIR"
    
    # Vérifier s'il y a des changements à commit
    if ! git status --porcelain | grep -q .; then
        echo "${NOTE} Aucun changement détecté, pas besoin de commit" | tee -a "$LOG_FILE"
        return 0
    fi
    
    # Ajouter tous les changements
    git add .
    
    # Créer un commit
    local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    git commit -m "Sauvegarde automatique: $timestamp"
    echo "${OK} Changements commités localement" | tee -a "$LOG_FILE"
    
    # Tenter de push vers le dépôt distant
    echo "${INFO} Envoi des modifications vers le dépôt distant..." | tee -a "$LOG_FILE"
    
    if git push -u origin master 2>&1 | tee -a "$LOG_FILE" || git push -u origin main 2>&1 | tee -a "$LOG_FILE"; then
        echo "${OK} Changements poussés avec succès vers le dépôt distant" | tee -a "$LOG_FILE"
        return 0
    else
        echo "${ERROR} Échec du push vers le dépôt distant" | tee -a "$LOG_FILE"
        echo "${INFO} Vérification de l'authentification Git..." | tee -a "$LOG_FILE"
        
        if whiptail --title "Problème de Push" --yesno "Échec du push vers le dépôt distant. Voulez-vous configurer l'authentification Git?" 8 70; then
            setup_git_auth
            
            # Réessayer après configuration
            echo "${INFO} Tentative de push après configuration..." | tee -a "$LOG_FILE"
            if git push -u origin master 2>&1 | tee -a "$LOG_FILE" || git push -u origin main 2>&1 | tee -a "$LOG_FILE"; then
                echo "${OK} Changements poussés avec succès après reconfiguration" | tee -a "$LOG_FILE"
                return 0
            else
                echo "${ERROR} Échec persistant du push. Vérifiez manuellement votre configuration Git." | tee -a "$LOG_FILE"
                return 1
            fi
        else
            echo "${NOTE} Configuration d'authentification ignorée par l'utilisateur" | tee -a "$LOG_FILE"
            return 1
        fi
    fi
}

# Fonction pour cloner le dépôt distant
clone_repository() {
    echo "${INFO} Tentative de clonage du dépôt distant..." | tee -a "$LOG_FILE"
    
    # Vérifier si le répertoire existe déjà
    if [ -d "$DOTFILES_DIR" ]; then
        if [ -d "$DOTFILES_DIR/.git" ]; then
            echo "${NOTE} Le dépôt existe déjà localement. Mise à jour..." | tee -a "$LOG_FILE"
            cd "$DOTFILES_DIR"
            
            # Essayer de récupérer les mises à jour
            if ! git pull 2>&1 | tee -a "$LOG_FILE"; then
                echo "${ERROR} Échec du pull. Configuration de l'authentification..." | tee -a "$LOG_FILE"
                setup_git_auth
                git pull 2>&1 | tee -a "$LOG_FILE"
            fi
        else
            echo "${WARN} Le répertoire existe mais n'est pas un dépôt Git. Sauvegarde..." | tee -a "$LOG_FILE"
            mv "$DOTFILES_DIR" "${DOTFILES_DIR}.bak-$(date +%Y%m%d-%H%M%S)"
            
            # Cloner le dépôt
            if ! git clone "$GIT_REPO_URL" "$DOTFILES_DIR" 2>&1 | tee -a "$LOG_FILE"; then
                echo "${ERROR} Échec du clonage. Configuration de l'authentification..." | tee -a "$LOG_FILE"
                mkdir -p "$DOTFILES_DIR"
                setup_git_auth
                rm -rf "$DOTFILES_DIR"
                git clone "$GIT_REPO_URL" "$DOTFILES_DIR" 2>&1 | tee -a "$LOG_FILE"
            fi
        fi
    else
        # Cloner le dépôt
        if ! git clone "$GIT_REPO_URL" "$DOTFILES_DIR" 2>&1 | tee -a "$LOG_FILE"; then
            echo "${ERROR} Échec du clonage. Configuration de l'authentification..." | tee -a "$LOG_FILE"
            mkdir -p "$DOTFILES_DIR"
            setup_git_auth
            rm -rf "$DOTFILES_DIR"
            git clone "$GIT_REPO_URL" "$DOTFILES_DIR" 2>&1 | tee -a "$LOG_FILE"
        fi
    fi
    
    # Créer les répertoires nécessaires s'ils n'existent pas
    mkdir -p "$BACKUP_DIR" "$CONFIG_DIR" "$PACKAGES_DIR" "$LOG_DIR"
    
    echo "${OK} Dépôt configuré avec succès" | tee -a "$LOG_FILE"
    return 0
}

# Fonction pour restaurer les dotfiles
restore_dotfiles() {
    echo "${INFO} Restauration des dotfiles..." | tee -a "$LOG_FILE"
    
    # Vérifier si le répertoire "current" existe
    if [ ! -d "$CONFIG_DIR" ]; then
        echo "${ERROR} Répertoire de configuration non trouvé!" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Restaurer chaque dotfile
    for dotfile in "${DOTFILES[@]}"; do
        src_path="$CONFIG_DIR/$dotfile"
        dest_path="$HOME/$dotfile"
        
        if [ -e "$src_path" ]; then
            # Créer une sauvegarde du fichier existant si nécessaire
            if [ -e "$dest_path" ]; then
                backup_path="$dest_path.bak-$(date +%Y%m%d-%H%M%S)"
                mv "$dest_path" "$backup_path"
                echo "${NOTE} Fichier existant sauvegardé: $backup_path" | tee -a "$LOG_FILE"
            fi
            
            # Créer le répertoire parent si nécessaire
            mkdir -p "$(dirname "$dest_path")"
            
            # Copier les fichiers
            cp -r "$src_path" "$(dirname "$dest_path")/"
            echo "${OK} Restauré: $dotfile" | tee -a "$LOG_FILE"
        else
            echo "${NOTE} Ignoré (n'existe pas dans la sauvegarde): $dotfile" | tee -a "$LOG_FILE"
        fi
    done
    
    echo "${OK} Restauration des dotfiles terminée!" | tee -a "$LOG_FILE"
    return 0
}

# Fonction pour restaurer les packages
restore_packages() {
    echo "${INFO} Restauration des packages..." | tee -a "$LOG_FILE"
    
    # Vérifier si les fichiers de packages existent
    if [ ! -f "$PACKAGES_DIR/pacman-explicit.txt" ]; then
        echo "${ERROR} Liste de packages non trouvée!" | tee -a "$LOG_FILE"
        return 1
    fi
    
    if whiptail --title "Restauration des packages" --yesno "Voulez-vous réinstaller tous les packages explicitement installés?" 8 70; then
        # Installation des packages avec pacman
        cat "$PACKAGES_DIR/pacman-explicit.txt" | grep -v "$(pacman -Qmq 2>/dev/null || echo "")" | awk '{print $1}' | while read pkg; do
            if ! pacman -Q "$pkg" &>/dev/null; then
                echo "${INFO} Installation de $pkg..." | tee -a "$LOG_FILE"
                sudo pacman -S --noconfirm --needed "$pkg" | tee -a "$LOG_FILE"
            fi
        done
        
        # Installation des packages AUR si disponible
        if [ -f "$PACKAGES_DIR/aur-packages.txt" ]; then
            if whiptail --title "Packages AUR" --yesno "Voulez-vous également réinstaller les packages AUR?" 8 60; then
                if command -v yay &>/dev/null; then
                    cat "$PACKAGES_DIR/aur-packages.txt" | awk '{print $1}' | while read pkg; do
                        if ! pacman -Q "$pkg" &>/dev/null; then
                            echo "${INFO} Installation du package AUR: $pkg..." | tee -a "$LOG_FILE"
                            yay -S --noconfirm --needed "$pkg" | tee -a "$LOG_FILE"
                        fi
                    done
                elif command -v paru &>/dev/null; then
                    cat "$PACKAGES_DIR/aur-packages.txt" | awk '{print $1}' | while read pkg; do
                        if ! pacman -Q "$pkg" &>/dev/null; then
                            echo "${INFO} Installation du package AUR: $pkg..." | tee -a "$LOG_FILE"
                            paru -S --noconfirm --needed "$pkg" | tee -a "$LOG_FILE"
                        fi
                    done
                else
                    echo "${NOTE} Aucun helper AUR trouvé (yay ou paru)" | tee -a "$LOG_FILE"
                    
                    if whiptail --title "Installation de yay" --yesno "Voulez-vous installer yay pour gérer les packages AUR?" 8 60; then
                        echo "${INFO} Installation de yay..." | tee -a "$LOG_FILE"
                        sudo pacman -S --needed git base-devel
                        git clone https://aur.archlinux.org/yay.git /tmp/yay
                        cd /tmp/yay
                        makepkg -si --noconfirm
                        cd - > /dev/null
                        
                        # Installer les packages AUR avec yay
                        cat "$PACKAGES_DIR/aur-packages.txt" | awk '{print $1}' | while read pkg; do
                            if ! pacman -Q "$pkg" &>/dev/null; then
                                echo "${INFO} Installation du package AUR: $pkg..." | tee -a "$LOG_FILE"
                                yay -S --noconfirm --needed "$pkg" | tee -a "$LOG_FILE"
                            fi
                        done
                    fi
                fi
            fi
        fi
        
        echo "${OK} Restauration des packages terminée!" | tee -a "$LOG_FILE"
    else
        echo "${NOTE} Restauration des packages annulée par l'utilisateur" | tee -a "$LOG_FILE"
    fi
    
    return 0
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
    
    # Lire la nouvelle liste
    DOTFILES=()
    while IFS= read -r line; do
        [ -n "$line" ] && DOTFILES+=("$line")
    done < "$temp_file"
    
    rm "$temp_file"
    
    echo "${OK} Liste des dotfiles mise à jour:" | tee -a "$LOG_FILE"
    for dotfile in "${DOTFILES[@]}"; do
        echo "  - $dotfile" | tee -a "$LOG_FILE"
    done
    
    return 0
}

# Fonction pour l'installation complète (clone + restore)
full_install() {
    whiptail --title "Installation complète" --msgbox "Cette option va cloner votre dépôt distant et restaurer vos dotfiles et packages." 8 70
    
    # Cloner le dépôt
    clone_repository
    
    # Restaurer les dotfiles
    restore_dotfiles
    
    # Restaurer les packages
    restore_packages
    
    echo "${OK} Installation complète terminée!" | tee -a "$LOG_FILE"
    return 0
}

# Affichage du menu principal
show_menu() {
    while true; do
        choice=$(whiptail --title "Gestionnaire de dotfiles Arch Linux" --menu "Choisissez une action:" 20 78 12 \
            "1" "Sauvegarder mes dotfiles et packages" \
            "2" "Restaurer mes dotfiles et packages" \
            "3" "Éditer la liste des dotfiles à sauvegarder" \
            "4" "Configurer l'authentification Git" \
            "5" "Installation complète (clone + restore)" \
            "6" "Quitter" \
            3>&1 1>&2 2>&3)
        
        if [ $? -ne 0 ]; then
            echo "${NOTE} Programme fermé." | tee -a "$LOG_FILE"
            exit 0
        fi
        
        case $choice in
            1)
                # Sauvegarder
                install_dependencies
                backup_dotfiles
                backup_packages
                commit_and_push
                echo "${OK} Sauvegarde complète terminée!" | tee -a "$LOG_FILE"
                ;;
            2)
                # Restaurer
                install_dependencies
                clone_repository
                restore_dotfiles
                restore_packages
                echo "${OK} Restauration complète terminée!" | tee -a "$LOG_FILE"
                ;;
            3)
                # Éditer la liste
                edit_dotfiles_list
                ;;
            4)
                # Configurer Git
                setup_git_auth
                ;;
            5)
                # Installation complète
                install_dependencies
                full_install
                ;;
            6)
                # Quitter
                echo "${NOTE} Au revoir!" | tee -a "$LOG_FILE"
                exit 0
                ;;
        esac
        
        # Pause pour lire les messages
        echo
        read -p "Appuyez sur Entrée pour continuer..."
        clear
    done
}

# Fonction pour simplifier l'utilisation en ligne de commande
if [ $# -gt 0 ]; then
    case "$1" in
        "backup")
            install_dependencies
            backup_dotfiles
            backup_packages
            commit_and_push
            exit $?
            ;;
        "restore")
            install_dependencies
            clone_repository
            restore_dotfiles
            restore_packages
            exit $?
            ;;
        "setup-git")
            setup_git_auth
            exit $?
            ;;
        *)
            echo "Usage: $0 [backup|restore|setup-git]"
            echo "Sans arguments, le menu interactif sera affiché."
            exit 1
            ;;
    esac
fi

# Exécution du programme principal
clear
echo -e "\e[35m
  █████╗ ██████╗  ██████╗██╗  ██╗██████╗  ██████╗ ████████╗███████╗
 ██╔══██╗██╔══██╗██╔════╝██║  ██║██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝
 ██████╔╝██████╔╝██║     ███████║██║  ██║██║   ██║   ██║   ███████╗
 ██╔═══╝ ██╔══██╗██║     ██╔══██║██║  ██║██║   ██║   ██║   ╚════██║
 ██║     ██║  ██║╚██████╗██║  ██║██████╔╝╚██████╔╝   ██║   ███████║
 ╚═╝     ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═════╝  ╚═════╝    ╚═╝   ╚══════╝
\e[0m"

show_menu