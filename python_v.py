#!/usr/bin/env python3
# Script Python de sauvegarde et restauration de dotfiles et packages pour Arch Linux

import os
import sys
import subprocess
import datetime
import shutil
from pathlib import Path
import re

# Variables
HOME = os.path.expanduser("~")
REPO_DIR = os.path.join(HOME, "dotfiles-backup")
REMOTE_URL = "https://github.com/TMCooper/ArchDots.git"
CONFIG_DIRS = [
    # Configurations graphiques et environnement
    ".config/hypr",
    ".config/waybar",
    ".config/swaync",
    ".config/ags",
    ".config/wlogout",
    ".config/rofi",
    ".config/kitty",
    ".config/cava",
    ".config/fastfetch",
    ".config/swappy",
    ".config/wallust",
    
    # Thèmes et styles
    ".config/gtk-3.0",
    ".config/Kvantum",
    ".config/qt5ct",
    ".config/qt6ct",
    
    # Multimédia
    ".config/mpv",
    ".config/spotify",
    
    # Gestionnaires de fichiers
    ".config/Thunar",
    ".config/xarchiver",
    
    # Fichiers de session et configuration utilisateur
    ".config/autostart",
    ".config/user-dirs.dirs",
    ".config/user-dirs.locale",
    ".config/mimeapps.list",
    
    # Fichiers utilisateur importants
    ".zshrc",
    ".bashrc",
    ".xinitrc",
    ".Xresources",
]

# Couleurs pour le terminal
GREEN = "\033[32m"
BLUE = "\033[34m"
RED = "\033[31m"
RESET = "\033[0m"

# Fonction pour afficher les messages
def print_msg(msg_type, message):
    if msg_type == "info":
        print(f"{BLUE}[INFO]{RESET} {message}")
    elif msg_type == "success":
        print(f"{GREEN}[SUCCESS]{RESET} {message}")
    elif msg_type == "error":
        print(f"{RED}[ERROR]{RESET} {message}")

# Exécute une commande shell et retourne la sortie
def run_command(command, shell=False):
    try:
        if shell:
            result = subprocess.run(command, shell=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        else:
            result = subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print_msg("error", f"Erreur lors de l'exécution de la commande: {e}")
        return None

# Vérifier si git est installé
def check_dependencies():
    try:
        subprocess.run(["git", "--version"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print_msg("info", "Git n'est pas installé. Installation...")
        subprocess.run(["sudo", "pacman", "-S", "--noconfirm", "git"], check=True)

# Initialiser le dépôt git
def setup_repo():
    if not os.path.exists(REPO_DIR):
        print_msg("info", "Création du répertoire de sauvegarde...")
        os.makedirs(REPO_DIR)
        os.chdir(REPO_DIR)
        run_command(["git", "init", "-b", "main"])
        
        with open(os.path.join(REPO_DIR, "README.md"), "w") as readme:
            readme.write("# Dotfiles Backup\n")
        
        run_command(["git", "add", "README.md"])
        run_command(["git", "commit", "-m", "Initial commit"])
        run_command(["git", "remote", "add", "origin", REMOTE_URL])
        print_msg("success", "Dépôt initialisé avec succès")
    else:
        print_msg("info", "Le répertoire existe déjà")
        os.chdir(REPO_DIR)
        # Vérifier si origin existe, sinon l'ajouter
        remotes = run_command(["git", "remote"])
        if "origin" not in remotes:
            run_command(["git", "remote", "add", "origin", REMOTE_URL])
            print_msg("info", "Dépôt distant ajouté")

# Sauvegarder les fichiers de configuration
def backup_dotfiles():
    print_msg("info", "Sauvegarde des dotfiles...")
    
    # Créer la structure de répertoires
    dotfiles_dir = os.path.join(REPO_DIR, "dotfiles")
    os.makedirs(dotfiles_dir, exist_ok=True)
    
    # Copier chaque répertoire/fichier de configuration
    for config in CONFIG_DIRS:
        src = os.path.join(HOME, config)
        dest = os.path.join(dotfiles_dir, config)
        
        if os.path.exists(src):
            # Créer le répertoire parent si nécessaire
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            
            # Copier les fichiers
            if os.path.isdir(src):
                if os.path.exists(dest):
                    shutil.rmtree(dest)
                shutil.copytree(src, dest)
            else:
                shutil.copy2(src, dest)
            print_msg("success", f"Sauvegardé: {config}")
        else:
            print_msg("info", f"Ignoré (n'existe pas): {config}")

# Permettre à l'utilisateur d'ajouter un dossier personnalisé
def add_custom_folder():
    print_msg("info", "Ajout d'un dossier personnalisé")
    custom_folder = input(f"Entrez le chemin relatif depuis {HOME} (ex: .config/mon_dossier): ")
    
    if not custom_folder:
        print_msg("error", "Chemin vide, opération annulée")
        return
    
    src = os.path.join(HOME, custom_folder)
    dest = os.path.join(REPO_DIR, "dotfiles", custom_folder)
    
    if os.path.exists(src):
        # Créer le répertoire parent si nécessaire
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        
        # Copier les fichiers
        if os.path.isdir(src):
            if os.path.exists(dest):
                shutil.rmtree(dest)
            shutil.copytree(src, dest)
        else:
            shutil.copy2(src, dest)
        print_msg("success", f"Sauvegardé: {custom_folder}")
    else:
        print_msg("error", f"Le dossier {custom_folder} n'existe pas")

# Sauvegarder la liste des packages
def backup_packages():
    print_msg("info", "Sauvegarde des packages installés...")
    packages_dir = os.path.join(REPO_DIR, "packages")
    os.makedirs(packages_dir, exist_ok=True)
    
    # Packages explicitement installés
    explicit_packages = run_command(["pacman", "-Qe"])
    with open(os.path.join(packages_dir, "pacman-explicit.txt"), "w") as f:
        f.write(explicit_packages)
    print_msg("success", "Packages explicitement installés sauvegardés")
    
    # Tous les packages (y compris les dépendances)
    all_packages = run_command(["pacman", "-Q"])
    with open(os.path.join(packages_dir, "pacman-all.txt"), "w") as f:
        f.write(all_packages)
    print_msg("success", "Liste complète des packages sauvegardée")
    
    # Packages AUR (si yay ou paru est installé)
    try:
        aur_helper = None
        if shutil.which("yay"):
            aur_helper = "yay"
        elif shutil.which("paru"):
            aur_helper = "paru"
        
        if aur_helper:
            aur_packages = run_command([aur_helper, "-Qm"])
            with open(os.path.join(packages_dir, "aur-packages.txt"), "w") as f:
                f.write(aur_packages)
            print_msg("success", "Packages AUR sauvegardés")
    except Exception as e:
        print_msg("error", f"Erreur lors de la sauvegarde des packages AUR: {e}")

# Commit et push des changements
def commit_changes():
    os.chdir(REPO_DIR)
    run_command(["git", "add", "."])
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    run_command(["git", "commit", "-m", f"Sauvegarde: {timestamp}"])
    print_msg("success", "Changements commités localement")
    
    # Push vers le dépôt distant configuré
    print_msg("info", "Envoi des modifications vers le dépôt distant...")
    run_command(["git", "push", "-u", "origin", "main"])
    print_msg("success", "Changements poussés vers le dépôt distant")

# Fonction de restauration
def restore_dotfiles():
    print_msg("info", "Restauration des dotfiles...")
    
    # Parcourir et restaurer chaque fichier/dossier
    for config in CONFIG_DIRS:
        src = os.path.join(REPO_DIR, "dotfiles", config)
        dest = os.path.join(HOME, config)
        
        if os.path.exists(src):
            # Créer une sauvegarde du fichier existant si nécessaire
            if os.path.exists(dest):
                timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
                backup_dest = f"{dest}.backup.{timestamp}"
                if os.path.isdir(dest):
                    shutil.move(dest, backup_dest)
                else:
                    shutil.copy2(dest, backup_dest)
                print_msg("info", f"Fichier existant sauvegardé: {backup_dest}")
            
            # Créer le répertoire parent si nécessaire
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            
            # Copier les fichiers
            if os.path.isdir(src):
                if os.path.exists(dest):
                    shutil.rmtree(dest)
                shutil.copytree(src, dest)
            else:
                shutil.copy2(src, dest)
            print_msg("success", f"Restauré: {config}")
        else:
            print_msg("info", f"Ignoré (n'existe pas dans la sauvegarde): {config}")
    
    # Restaurer aussi tous les autres dossiers trouvés dans la sauvegarde
    dotfiles_dir = os.path.join(REPO_DIR, "dotfiles")
    if os.path.exists(dotfiles_dir):
        for dirpath, dirnames, filenames in os.walk(dotfiles_dir):
            # Ignorer le répertoire racine
            if dirpath == dotfiles_dir:
                continue
            
            # Calculer le chemin relatif
            rel_path = os.path.relpath(dirpath, dotfiles_dir)
            
            # Vérifier si ce n'est pas déjà dans les dossiers principaux
            if rel_path not in CONFIG_DIRS and not any(rel_path.startswith(d + "/") for d in CONFIG_DIRS):
                dest = os.path.join(HOME, rel_path)
                
                # Créer une sauvegarde du fichier existant si nécessaire
                if os.path.exists(dest) and os.path.isdir(dest):
                    timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
                    backup_dest = f"{dest}.backup.{timestamp}"
                    shutil.move(dest, backup_dest)
                    print_msg("info", f"Fichier existant sauvegardé: {backup_dest}")
                
                # Créer le répertoire
                os.makedirs(dest, exist_ok=True)
                
                # Copier les fichiers de ce répertoire
                for filename in filenames:
                    src_file = os.path.join(dirpath, filename)
                    dest_file = os.path.join(dest, filename)
                    
                    if os.path.exists(dest_file):
                        timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
                        backup_file = f"{dest_file}.backup.{timestamp}"
                        shutil.copy2(dest_file, backup_file)
                    
                    shutil.copy2(src_file, dest_file)
                
                print_msg("success", f"Restauré: {rel_path}")

# Restauration des packages
def restore_packages():
    print_msg("info", "Restauration des packages...")
    
    pacman_explicit_file = os.path.join(REPO_DIR, "packages", "pacman-explicit.txt")
    if os.path.exists(pacman_explicit_file):
        answer = input("Voulez-vous réinstaller tous les packages? (o/n): ")
        if answer.lower() == "o":
            # Obtenir la liste des packages AUR installés
            aur_packages = []
            try:
                aur_packages_output = run_command(["pacman", "-Qmq"])
                if aur_packages_output:
                    aur_packages = aur_packages_output.split("\n")
            except Exception:
                aur_packages = []
            
            # Installation des packages avec pacman
            with open(pacman_explicit_file, "r") as f:
                for line in f:
                    pkg = line.split()[0]
                    if pkg not in aur_packages:
                        try:
                            # Vérifier si le package est déjà installé
                            subprocess.run(["pacman", "-Q", pkg], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                        except subprocess.CalledProcessError:
                            print_msg("info", f"Installation de {pkg}...")
                            subprocess.run(["sudo", "pacman", "-S", "--noconfirm", "--needed", pkg], check=False)
            
            # Installation des packages AUR si disponible
            aur_packages_file = os.path.join(REPO_DIR, "packages", "aur-packages.txt")
            if os.path.exists(aur_packages_file):
                aur_helper = None
                if shutil.which("yay"):
                    aur_helper = "yay"
                elif shutil.which("paru"):
                    aur_helper = "paru"
                
                if aur_helper:
                    with open(aur_packages_file, "r") as f:
                        for line in f:
                            pkg = line.split()[0]
                            try:
                                # Vérifier si le package est déjà installé
                                subprocess.run(["pacman", "-Q", pkg], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                            except subprocess.CalledProcessError:
                                print_msg("info", f"Installation du package AUR: {pkg}...")
                                subprocess.run([aur_helper, "-S", "--noconfirm", "--needed", pkg], check=False)
                else:
                    print_msg("info", "Aucun helper AUR trouvé (yay ou paru).")
                    install_yay = input("Voulez-vous installer yay? (o/n): ")
                    if install_yay.lower() == "o":
                        subprocess.run(["sudo", "pacman", "-S", "--needed", "git", "base-devel"], check=True)
                        tmp_dir = "/tmp/yay"
                        if os.path.exists(tmp_dir):
                            shutil.rmtree(tmp_dir)
                        subprocess.run(["git", "clone", "https://aur.archlinux.org/yay.git", tmp_dir], check=True)
                        os.chdir(tmp_dir)
                        subprocess.run(["makepkg", "-si", "--noconfirm"], check=True)
                        os.chdir(os.path.expanduser("~"))
                        
                        # Maintenant installer les packages AUR
                        with open(aur_packages_file, "r") as f:
                            for line in f:
                                pkg = line.split()[0]
                                try:
                                    # Vérifier si le package est déjà installé
                                    subprocess.run(["pacman", "-Q", pkg], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                                except subprocess.CalledProcessError:
                                    print_msg("info", f"Installation du package AUR: {pkg}...")
                                    subprocess.run(["yay", "-S", "--noconfirm", "--needed", pkg], check=False)
            
            print_msg("success", "Restauration des packages terminée!")
    else:
        print_msg("error", "Aucune liste de packages trouvée.")

# Menu principal
def show_menu():
    while True:
        os.system("clear" if os.name == "posix" else "cls")
        print("==========================================")
        print("   GESTIONNAIRE DE DOTFILES POUR ARCH    ")
        print("==========================================")
        print("1. Sauvegarder les dotfiles et packages")
        print("2. Ajouter un dossier personnalisé à la sauvegarde")
        print("3. Restaurer les dotfiles et packages")
        print("4. Quitter")
        print("==========================================")
        
        choice = input("Choisissez une option (1-4): ")
        
        if choice == "1":
            check_dependencies()
            setup_repo()
            backup_dotfiles()
            backup_packages()
            commit_changes()
            print_msg("success", "Sauvegarde terminée!")
            input("Appuyez sur Entrée pour continuer...")
        
        elif choice == "2":
            check_dependencies()
            add_custom_folder()
            commit_changes()
            print_msg("success", "Dossier ajouté!")
            input("Appuyez sur Entrée pour continuer...")
        
        elif choice == "3":
            if not os.path.exists(REPO_DIR):
                print_msg("info", "Aucun dépôt local trouvé. Clonage du dépôt distant...")
                subprocess.run(["git", "clone", REMOTE_URL, REPO_DIR], check=True)
            restore_dotfiles()
            restore_packages()
            print_msg("success", "Restauration terminée!")
            input("Appuyez sur Entrée pour continuer...")
        
        elif choice == "4":
            print_msg("info", "Au revoir!")
            sys.exit(0)
        
        else:
            print_msg("error", "Option invalide.")
            input("Appuyez sur Entrée pour continuer...")

# Exécution du script
if __name__ == "__main__":
    show_menu()