#!/bin/bash
# Script simple de sauvegarde et restauration de dotfiles et packages pour Arch Linux

# Variables
REPO_DIR="$HOME/dotfiles-backup"
REMOTE_URL="https://github.com/TMCooper/ArchDots.git"
CONFIG_DIRS=(
    # Configurations graphiques et environnement
    ".config/hypr"
    ".config/waybar"
    ".config/swaync"
    ".config/ags"
    ".config/wlogout"
    ".config/rofi"
    ".config/kitty"
    ".config/cava"
    ".config/fastfetch"
    ".config/swappy"
    ".config/wallust"
    
    # Thèmes et styles
    ".config/gtk-3.0"
    ".config/Kvantum"
    ".config/qt5ct"
    ".config/qt6ct"
    
    # Multimédia
    ".config/mpv"
    ".config/spotify"
    
    # Gestionnaires de fichiers
    ".config/Thunar"
    ".config/xarchiver"
    
    # Fichiers de session et configuration utilisateur
    ".config/autostart"
    ".config/user-dirs.dirs"
    ".config/user-dirs.locale"
    ".config/mimeapps.list"
    
    # Fichiers utilisateur importants
    ".zshrc"
    ".bashrc"
    ".xinitrc"
    ".Xresources"
)

# Couleurs pour le terminal
GREEN="\e[32m"
BLUE="\e[34m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

# Fonction pour afficher les messages
print_msg() {
    case $1 in
        "info")
            echo -e "${BLUE}[INFO]${RESET} $2"
            ;;
        "success")
            echo -e "${GREEN}[SUCCESS]${RESET} $2"
            ;;
        "error")
            echo -e "${RED}[ERROR]${RESET} $2"
            ;;
        "warning")
            echo -e "${YELLOW}[WARNING]${RESET} $2"
            ;;
    esac
}

# Vérifier si git est installé
check_dependencies() {
    if ! command -v git &> /dev/null; then
        print_msg "info" "Git n'est pas installé. Installation..."
        sudo pacman -S --noconfirm git
    fi
}

# Configuration Git globale nécessaire
setup_git_config() {
    # Vérifier si le nom d'utilisateur git est configuré
    if ! git config --global user.name >/dev/null; then
        print_msg "info" "Configuration Git nécessaire pour continuer"
        read -p "Entrez votre nom pour Git: " git_name
        git config --global user.name "$git_name"
    fi
    
    # Vérifier si l'email git est configuré
    if ! git config --global user.email >/dev/null; then
        read -p "Entrez votre email pour Git: " git_email
        git config --global user.email "$git_email"
    fi
}

# Initialiser le dépôt git
setup_repo() {
    # S'assurer que la configuration Git est correcte
    setup_git_config
    
    if [ ! -d "$REPO_DIR" ]; then
        print_msg "info" "Création du répertoire de sauvegarde..."
        mkdir -p "$REPO_DIR"
        
        # Vérifier si le dépôt distant existe déjà
        if git ls-remote "$REMOTE_URL" &>/dev/null; then
            print_msg "info" "Clonage du dépôt distant existant..."
            git clone "$REMOTE_URL" "$REPO_DIR"
        else
            # Créer un nouveau dépôt local
            cd "$REPO_DIR"
            git init -b main
            echo "# Dotfiles Backup pour Arch Linux" > README.md
            git add README.md
            git commit -m "Initial commit"
            git remote add origin "$REMOTE_URL"
            print_msg "success" "Dépôt initialisé avec succès"
        fi
    else
        print_msg "info" "Le répertoire existe déjà"
        cd "$REPO_DIR"
        # Vérifier si origin existe, sinon l'ajouter
        if ! git remote | grep -q "origin"; then
            git remote add origin "$REMOTE_URL"
            print_msg "info" "Dépôt distant ajouté"
        fi
    fi
}

# Sauvegarder les fichiers de configuration
backup_dotfiles() {
    print_msg "info" "Sauvegarde des dotfiles..."
    
    # Créer la structure de répertoires
    mkdir -p "$REPO_DIR/dotfiles"
    
    # Copier chaque répertoire/fichier de configuration
    for config in "${CONFIG_DIRS[@]}"; do
        src="$HOME/$config"
        dest="$REPO_DIR/dotfiles/$config"
        
        if [ -e "$src" ]; then
            # Créer le répertoire parent si nécessaire
            mkdir -p "$(dirname "$dest")"
            # Copier les fichiers
            cp -r "$src" "$(dirname "$dest")/"
            print_msg "success" "Sauvegardé: $config"
        else
            print_msg "info" "Ignoré (n'existe pas): $config"
        fi
    done
}

# Permettre à l'utilisateur d'ajouter un dossier personnalisé
add_custom_folder() {
    print_msg "info" "Ajout d'un dossier personnalisé"
    read -p "Entrez le chemin relatif depuis $HOME (ex: .config/mon_dossier): " custom_folder
    
    if [ -z "$custom_folder" ]; then
        print_msg "error" "Chemin vide, opération annulée"
        return
    fi
    
    src="$HOME/$custom_folder"
    dest="$REPO_DIR/dotfiles/$custom_folder"
    
    if [ -e "$src" ]; then
        # Créer le répertoire parent si nécessaire
        mkdir -p "$(dirname "$dest")"
        # Copier les fichiers
        cp -r "$src" "$(dirname "$dest")/"
        print_msg "success" "Sauvegardé: $custom_folder"
    else
        print_msg "error" "Le dossier $custom_folder n'existe pas"
    fi
}

# Sauvegarder la liste des packages
backup_packages() {
    print_msg "info" "Sauvegarde des packages installés..."
    mkdir -p "$REPO_DIR/packages"
    
    # Packages explicitement installés
    pacman -Qe > "$REPO_DIR/packages/pacman-explicit.txt"
    print_msg "success" "Packages explicitement installés sauvegardés"
    
    # Tous les packages (y compris les dépendances)
    pacman -Q > "$REPO_DIR/packages/pacman-all.txt"
    print_msg "success" "Liste complète des packages sauvegardée"
    
    # Packages AUR (si yay ou paru est installé)
    if command -v yay &>/dev/null; then
        yay -Qm > "$REPO_DIR/packages/aur-packages.txt"
        print_msg "success" "Packages AUR sauvegardés"
    elif command -v paru &>/dev/null; then
        paru -Qm > "$REPO_DIR/packages/aur-packages.txt"
        print_msg "success" "Packages AUR sauvegardés"
    fi
}

# Commit et push des changements
commit_changes() {
    cd "$REPO_DIR"
    
    # Vérifier s'il y a des changements à commiter
    if git status --porcelain | grep -q .; then
        git add .
        git commit -m "Sauvegarde: $(date +%Y-%m-%d_%H-%M-%S)"
        print_msg "success" "Changements commités localement"
        
        # Push vers le dépôt distant configuré
        print_msg "info" "Envoi des modifications vers le dépôt distant..."
        
        # Stratégie de push plus robuste
        # Si le dépôt distant existe, essayer de le synchroniser d'abord
        if git ls-remote --exit-code "$REMOTE_URL" &>/dev/null; then
            # Vérifier si la branche main existe sur le dépôt distant
            if git ls-remote --heads "$REMOTE_URL" main | grep -q main; then
                # La branche existe, donc pull d'abord pour éviter les conflits
                git pull --rebase origin main || true
                if ! git push origin main; then
                    print_msg "warning" "Push normal échoué, tentative avec --force..."
                    git push --force origin main
                fi
            else
                # La branche n'existe pas sur le dépôt distant, donc créer avec -u
                print_msg "info" "Premier push avec -u pour créer la branche main..."
                if ! git push -u origin main; then
                    print_msg "warning" "Push normal échoué, tentative avec --force..."
                    git push --force -u origin main
                fi
            fi
        else
            # Le dépôt distant n'existe probablement pas encore ou n'est pas accessible
            print_msg "warning" "Le dépôt distant pourrait ne pas exister encore."
            print_msg "info" "Veuillez créer un dépôt vide sur GitHub puis réessayer."
            return 1
        fi
        
        print_msg "success" "Changements poussés vers le dépôt distant"
    else
        print_msg "info" "Aucun changement à commiter"
    fi
}

# Fonction de restauration
restore_dotfiles() {
    print_msg "info" "Restauration des dotfiles..."
    
    # Parcourir et restaurer chaque fichier/dossier
    for config in "${CONFIG_DIRS[@]}"; do
        src="$REPO_DIR/dotfiles/$config"
        dest="$HOME/$config"
        
        if [ -e "$src" ]; then
            # Créer une sauvegarde du fichier existant si nécessaire
            if [ -e "$dest" ]; then
                backup_dest="${dest}.backup.$(date +%Y%m%d%H%M%S)"
                mv "$dest" "$backup_dest"
                print_msg "info" "Fichier existant sauvegardé: $backup_dest"
            fi
            
            # Créer le répertoire parent si nécessaire
            mkdir -p "$(dirname "$dest")"
            # Copier les fichiers
            cp -r "$src" "$(dirname "$dest")/"
            print_msg "success" "Restauré: $config"
        else
            print_msg "info" "Ignoré (n'existe pas dans la sauvegarde): $config"
        fi
    done
    
    # Restaurer aussi tous les autres dossiers trouvés dans la sauvegarde
    find "$REPO_DIR/dotfiles" -type d -mindepth 1 -maxdepth 1 2>/dev/null | while read dir; do
        dirname=$(basename "$dir")
        if [ -d "$dir" ]; then
            find "$dir" -mindepth 1 -maxdepth 1 2>/dev/null | while read subdir; do
                subdirname=$(basename "$subdir")
                src="$dir/$subdirname"
                # Créer le chemin relatif à partir de la structure du dépôt
                relative_path="$dirname/$subdirname"
                dest="$HOME/$relative_path"
                
                # Vérifier si ce n'est pas déjà dans les dossiers principaux
                if ! echo "${CONFIG_DIRS[@]}" | grep -q "$relative_path"; then
                    if [ -e "$src" ]; then
                        # Créer une sauvegarde du fichier existant si nécessaire
                        if [ -e "$dest" ]; then
                            backup_dest="${dest}.backup.$(date +%Y%m%d%H%M%S)"
                            mv "$dest" "$backup_dest"
                            print_msg "info" "Fichier existant sauvegardé: $backup_dest"
                        fi
                        
                        # Créer le répertoire parent si nécessaire
                        mkdir -p "$(dirname "$dest")"
                        # Copier les fichiers
                        cp -r "$src" "$(dirname "$dest")/"
                        print_msg "success" "Restauré: $relative_path"
                    fi
                fi
            done
        fi
    done
}

# Restauration des packages
restore_packages() {
    print_msg "info" "Restauration des packages..."
    
    if [ -f "$REPO_DIR/packages/pacman-explicit.txt" ]; then
        read -p "Voulez-vous réinstaller tous les packages? (o/n): " answer
        if [[ "$answer" == "o" || "$answer" == "O" ]]; then
            # Installation des packages avec pacman
            cat "$REPO_DIR/packages/pacman-explicit.txt" | grep -v "$(pacman -Qmq 2>/dev/null || echo '')" | awk '{print $1}' | while read pkg; do
                if ! pacman -Q "$pkg" &>/dev/null; then
                    print_msg "info" "Installation de $pkg..."
                    sudo pacman -S --noconfirm --needed "$pkg"
                fi
            done
            
            # Installation des packages AUR si disponible
            if [ -f "$REPO_DIR/packages/aur-packages.txt" ]; then
                if command -v yay &>/dev/null; then
                    cat "$REPO_DIR/packages/aur-packages.txt" | awk '{print $1}' | while read pkg; do
                        if ! pacman -Q "$pkg" &>/dev/null; then
                            print_msg "info" "Installation du package AUR: $pkg..."
                            yay -S --noconfirm --needed "$pkg"
                        fi
                    done
                elif command -v paru &>/dev/null; then
                    cat "$REPO_DIR/packages/aur-packages.txt" | awk '{print $1}' | while read pkg; do
                        if ! pacman -Q "$pkg" &>/dev/null; then
                            print_msg "info" "Installation du package AUR: $pkg..."
                            paru -S --noconfirm --needed "$pkg"
                        fi
                    done
                else
                    print_msg "info" "Aucun helper AUR trouvé (yay ou paru)."
                    read -p "Voulez-vous installer yay? (o/n): " install_yay
                    if [[ "$install_yay" == "o" || "$install_yay" == "O" ]]; then
                        sudo pacman -S --needed git base-devel
                        git clone https://aur.archlinux.org/yay.git /tmp/yay
                        cd /tmp/yay
                        makepkg -si --noconfirm
                        cd -
                        
                        # Maintenant installer les packages AUR
                        cat "$REPO_DIR/packages/aur-packages.txt" | awk '{print $1}' | while read pkg; do
                            if ! pacman -Q "$pkg" &>/dev/null; then
                                print_msg "info" "Installation du package AUR: $pkg..."
                                yay -S --noconfirm --needed "$pkg"
                            fi
                        done
                    fi
                fi
            fi
            
            print_msg "success" "Restauration des packages terminée!"
        fi
    else
        print_msg "error" "Aucune liste de packages trouvée."
    fi
}

# Menu principal
show_menu() {
    clear
    echo "=========================================="
    echo "   GESTIONNAIRE DE DOTFILES POUR ARCH    "
    echo "=========================================="
    echo "1. Sauvegarder les dotfiles et packages"
    echo "2. Ajouter un dossier personnalisé à la sauvegarde"
    echo "3. Restaurer les dotfiles et packages"
    echo "4. Quitter"
    echo "=========================================="
    read -p "Choisissez une option (1-4): " choice
    
    case $choice in
        1)
            check_dependencies
            setup_repo
            backup_dotfiles
            backup_packages
            commit_changes || print_msg "error" "Erreur lors du push. Vérifiez que le dépôt GitHub existe."
            print_msg "success" "Sauvegarde terminée!"
            read -p "Appuyez sur Entrée pour continuer..."
            show_menu
            ;;
        2)
            check_dependencies
            setup_repo
            add_custom_folder
            commit_changes || print_msg "error" "Erreur lors du push. Vérifiez que le dépôt GitHub existe."
            print_msg "success" "Dossier ajouté!"
            read -p "Appuyez sur Entrée pour continuer..."
            show_menu
            ;;
        3)
            check_dependencies
            
            if [ ! -d "$REPO_DIR" ]; then
                print_msg "info" "Aucun dépôt local trouvé. Tentative de clonage du dépôt distant..."
                
                # Vérifier si le dépôt distant existe avant de cloner
                if git ls-remote --exit-code "$REMOTE_URL" &>/dev/null; then
                    git clone "$REMOTE_URL" "$REPO_DIR"
                    print_msg "success" "Dépôt cloné avec succès"
                else
                    print_msg "error" "Le dépôt distant n'existe pas ou n'est pas accessible."
                    print_msg "info" "Veuillez créer un dépôt vide sur GitHub puis réessayer."
                    read -p "Appuyez sur Entrée pour continuer..."
                    show_menu
                    return
                fi
            fi
            
            restore_dotfiles
            restore_packages
            print_msg "success" "Restauration terminée!"
            read -p "Appuyez sur Entrée pour continuer..."
            show_menu
            ;;
        4)
            print_msg "info" "Au revoir!"
            exit 0
            ;;
        *)
            print_msg "error" "Option invalide."
            read -p "Appuyez sur Entrée pour continuer..."
            show_menu
            ;;
    esac
}

# Exécution du script
show_menu
