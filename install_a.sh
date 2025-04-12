#!/bin/bash
# Script simple de sauvegarde et restauration de dotfiles et packages pour Arch Linux

# Variables
REPO_DIR="$HOME/dotfiles-backup"
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
    esac
}

# Vérifier si git est installé
check_dependencies() {
    if ! command -v git &> /dev/null; then
        print_msg "info" "Git n'est pas installé. Installation..."
        sudo pacman -S --noconfirm git
    fi
}

# Initialiser le dépôt git
setup_repo() {
    if [ ! -d "$REPO_DIR" ]; then
        print_msg "info" "Création du répertoire de sauvegarde..."
        mkdir -p "$REPO_DIR"
        cd "$REPO_DIR"
        git init
        echo "# Dotfiles Backup" > README.md
        git add README.md
        git commit -m "Initial commit"
        print_msg "success" "Dépôt initialisé avec succès"
    else
        print_msg "info" "Le répertoire existe déjà"
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
    git add .
    git commit -m "Sauvegarde: $(date +%Y-%m-%d_%H-%M-%S)"
    print_msg "success" "Changements commités localement"
    
    # Vérifier si un remote existe déjà
    if git remote | grep -q "origin"; then
        read -p "Un dépôt distant est déjà configuré. Voulez-vous pousser les changements? (o/n): " push_answer
        if [[ "$push_answer" == "o" || "$push_answer" == "O" ]]; then
            git push origin master
            print_msg "success" "Changements poussés vers le dépôt distant"
        fi
    else
        # Demander à l'utilisateur s'il souhaite configurer un dépôt distant
        read -p "Voulez-vous configurer un dépôt distant? (o/n): " answer
        if [[ "$answer" == "o" || "$answer" == "O" ]]; then
            read -p "Entrez l'URL du dépôt distant (ex: https://github.com/username/repo.git): " remote_url
            git remote add origin "$remote_url"
            git push -u origin master
            print_msg "success" "Changements poussés vers le dépôt distant"
        fi
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
    find "$REPO_DIR/dotfiles" -type d -mindepth 1 -maxdepth 1 | while read dir; do
        dirname=$(basename "$dir")
        if [ -d "$dir" ]; then
            for subdir in $(find "$dir" -mindepth 1 -maxdepth 1); do
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
            cat "$REPO_DIR/packages/pacman-explicit.txt" | grep -v "$(pacman -Qmq)" | awk '{print $1}' | while read pkg; do
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
            commit_changes
            print_msg "success" "Sauvegarde terminée!"
            read -p "Appuyez sur Entrée pour continuer..."
            show_menu
            ;;
        2)
            check_dependencies
            add_custom_folder
            commit_changes
            print_msg "success" "Dossier ajouté!"
            read -p "Appuyez sur Entrée pour continuer..."
            show_menu
            ;;
        3)
            if [ ! -d "$REPO_DIR" ]; then
                read -p "Aucun dépôt local trouvé. Voulez-vous cloner un dépôt distant? (o/n): " answer
                if [[ "$answer" == "o" || "$answer" == "O" ]]; then
                    read -p "Entrez l'URL du dépôt distant: " remote_url
                    git clone "$remote_url" "$REPO_DIR"
                else
                    print_msg "error" "Impossible de restaurer sans dépôt."
                    exit 1
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