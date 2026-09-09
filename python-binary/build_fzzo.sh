#!/bin/bash

# Script para compilar fzzo.py em um binário standalone
# Requer PyInstaller: pip install pyinstaller

set -e

echo "🔧 Compilando fzzo para binário..."

# Verifica se PyInstaller está instalado
if ! command -v pyinstaller &> /dev/null; then
    echo "❌ PyInstaller não encontrado. Instalando..."
    pip install pyinstaller
fi

# Compila o binário
pyinstaller --onefile \
            --name fzzo \
            --console \
            --strip \
            --optimize 2 \
            fzzo.py

echo "✅ Compilação concluída!"
echo "📁 Binário gerado em: dist/fzzo"
echo ""
echo "Para instalar globalmente:"
echo "  sudo cp dist/fzzo /usr/local/bin/"
echo "  # ou"
echo "  cp dist/fzzo ~/.local/bin/"
echo ""
echo "Para testar:"
echo "  ./dist/fzzo"