#!/bin/bash

# Script para compilar fopen.py em um binário standalone
# Requer PyInstaller: pip install pyinstaller

set -e

echo "🔧 Compilando fopen para binário..."

# Verifica se PyInstaller está instalado
if ! command -v pyinstaller &> /dev/null; then
    echo "❌ PyInstaller não encontrado. Instalando..."
    pip install pyinstaller
fi

# Compila o binário
pyinstaller --onefile \
            --name fopen \
            --console \
            --strip \
            --optimize 2 \
            fopen.py

echo "✅ Compilação concluída!"
echo "📁 Binário gerado em: dist/fopen"
echo ""
echo "Para instalar globalmente:"
echo "  sudo cp dist/fopen /usr/local/bin/"
echo "  # ou"
echo "  cp dist/fopen ~/.local/bin/"
echo ""
echo "Para testar:"
echo "  ./dist/fopen"