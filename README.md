# fzzopen

Seletor fuzzy de arquivos/diretórios (via `fzf`) com abertura automática por
tipo de aplicativo, de acordo com o MIME type do arquivo.

## Estrutura

- **[fish/](fish/)** — implementação ativa: uma função fish nativa. Roda no
  processo do shell atual, então `cd` para o diretório escolhido funciona
  de verdade. Veja [fish/README.md](fish/README.md) para instalação e uso.

- **[python-binary/](python-binary/)** — experimento abandonado: tentativa
  de reescrever a ferramenta em Python e distribuí-la como binário
  standalone (via PyInstaller) para funcionar em qualquer shell. Foi
  descartado porque um binário roda como subprocesso e não consegue mudar
  o diretório de trabalho do shell pai — problema que a versão fish não
  tem, por rodar in-process. Mantido apenas como referência/histórico.

## Recomendação

Use a função em [fish/fopen.fish](fish/fopen.fish). Se um dia for retomada
a ideia de suportar outros shells (bash/zsh), o caminho é o padrão usado
por ferramentas como `zoxide`/`direnv`/`broot`: um script "burro" que só
imprime o caminho escolhido, envolvido por uma função fina de shell que
faz o `cd` no processo atual — não um binário standalone tentando fazer
isso sozinho.
