#!/bin/bash

# Script para testar o fzzo em diferentes shells

set -e

FZZOPEN_PATH="/home/caio/dist/fzzo"

echo "🧪 Testando fzzo em diferentes shells..."
echo "📁 Binário: $FZZOPEN_PATH ($(du -h "$FZZOPEN_PATH" | cut -f1))"
echo ""

# Verifica se o binário existe
if [ ! -f "$FZZOPEN_PATH" ]; then
    echo "❌ Binário não encontrado: $FZZOPEN_PATH"
    exit 1
fi

# Lista de shells para testar
SHELLS=("sh" "bash" "dash" "zsh")

for shell in "${SHELLS[@]}"; do
    if command -v "$shell" &> /dev/null; then
        echo -n "🐚 Testando $shell: "
        if $shell -c "exec '$FZZOPEN_PATH' --help >/dev/null 2>&1"; then
            echo "✅ OK"
        else
            echo "❌ FALHOU"
        fi
    else
        echo "⚠️  $shell não instalado"
    fi
done

echo ""
echo "🔍 Dependências:"

# Verifica dependências essenciais
deps=("fzf" "file" "fd" "bat")
for dep in "${deps[@]}"; do
    if command -v "$dep" &> /dev/null; then
        echo "✅ $dep: $(which "$dep")"
    else
        case $dep in
            "fzf"|"file")
                echo "❌ $dep: OBRIGATÓRIO - não encontrado"
                ;;
            *)
                echo "⚠️  $dep: opcional - não encontrado"
                ;;
        esac
    fi
done

echo ""
echo "📊 Informações do sistema:"
echo "OS: $(uname -s) $(uname -r)"
echo "Arquitetura: $(uname -m)"
echo "Python: $(python3 --version 2>/dev/null || echo "não encontrado")"

echo ""
echo "✨ Teste em um diretório com arquivos:"
echo "Exemplo: cd /tmp && $FZZOPEN_PATH"