# fopen (fish)

Função fish nativa de busca fuzzy de arquivos/diretórios, com seleção de
aplicativo por tipo MIME. É a implementação em uso — roda no processo do
shell atual, então o `cd` funciona de verdade.

## Instalação

```bash
cp fopen.fish ~/.config/fish/functions/fopen.fish
```

## Dependências

- `fzf` (obrigatório) — interface de seleção
- `file` (obrigatório) — detecção de tipo MIME
- `fd` (opcional) — busca mais rápida que `find`
- `bat` (opcional) — preview com syntax highlighting
- Editores/visualizadores usados pelas opções: `nvim`, `code`, `gedit`, `kate`, `loupe`, `okular`, `nautilus`

## Uso

```fish
fopen          # busca sem arquivos ocultos
fopen -h       # busca incluindo ocultos
```

Dentro do fzf: `Alt+h` mostra ocultos, `Alt+H` esconde, `Enter` seleciona,
`Ctrl+C` cancela.
