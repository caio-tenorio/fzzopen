#!/usr/bin/env python3
"""
Exemplo de como implementar detecção automática de aplicações
"""

import shutil
import os
from pathlib import Path

def detect_available_applications():
    """Detecta aplicações disponíveis no sistema"""
    
    # Define known applications per category
    known_apps = {
        'text_editors': [
            {'cmd': 'nvim', 'label': 'NeoVim', 'terminal': True, 'priority': 1},
            {'cmd': 'vim', 'label': 'Vim', 'terminal': True, 'priority': 2},
            {'cmd': 'code', 'label': 'VS Code', 'terminal': False, 'priority': 3},
            {'cmd': 'gedit', 'label': 'Text Editor', 'terminal': False, 'priority': 4},
            {'cmd': 'kate', 'label': 'Kate', 'terminal': False, 'priority': 5},
            {'cmd': 'nano', 'label': 'Nano', 'terminal': True, 'priority': 6},
        ],
        'file_managers': [
            {'cmd': 'nautilus', 'label': 'Files (GNOME)', 'terminal': False, 'priority': 1},
            {'cmd': 'dolphin', 'label': 'Dolphin (KDE)', 'terminal': False, 'priority': 2},
            {'cmd': 'thunar', 'label': 'Thunar (XFCE)', 'terminal': False, 'priority': 3},
            {'cmd': 'nemo', 'label': 'Nemo', 'terminal': False, 'priority': 4},
        ],
        'image_viewers': [
            {'cmd': 'loupe', 'label': 'Loupe', 'terminal': False, 'priority': 1},
            {'cmd': 'eog', 'label': 'Eye of GNOME', 'terminal': False, 'priority': 2},
            {'cmd': 'gwenview', 'label': 'Gwenview', 'terminal': False, 'priority': 3},
            {'cmd': 'feh', 'label': 'Feh', 'terminal': False, 'priority': 4},
        ]
    }
    
    available = {}
    
    for category, apps in known_apps.items():
        available[category] = []
        for app in apps:
            if shutil.which(app['cmd']):
                available[category].append(app)
        
        # Sort by priority
        available[category].sort(key=lambda x: x['priority'])
    
    return available

def detect_desktop_environment():
    """Detecta o ambiente desktop para sugerir aplicações específicas"""
    desktop = os.environ.get('XDG_CURRENT_DESKTOP', '').lower()
    
    if 'gnome' in desktop:
        return 'gnome'
    elif 'kde' in desktop:
        return 'kde'
    elif 'xfce' in desktop:
        return 'xfce'
    elif 'mate' in desktop:
        return 'mate'
    else:
        return 'unknown'

def get_config_priority_boost(desktop_env):
    """Aplica boost de prioridade baseado no ambiente desktop"""
    boosts = {
        'gnome': ['nautilus', 'gedit', 'eog', 'evince'],
        'kde': ['dolphin', 'kate', 'gwenview', 'okular'],
        'xfce': ['thunar', 'mousepad', 'ristretto'],
    }
    return boosts.get(desktop_env, [])

if __name__ == '__main__':
    apps = detect_available_applications()
    desktop = detect_desktop_environment()
    print(f"Desktop: {desktop}")
    print("\nAplicações disponíveis:")
    for category, app_list in apps.items():
        print(f"\n{category}:")
        for app in app_list:
            print(f"  - {app['label']} ({app['cmd']})")
