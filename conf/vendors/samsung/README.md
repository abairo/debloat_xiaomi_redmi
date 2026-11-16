# Perfil Samsung

As listas `basic`, `light` e `heavy` foram recuperadas do snapshot historico
`ba70d25` deste repositorio, anterior a adaptacao para o Redmi Note 10S.
Autores, datas e mensagens originais permanecem no historico Git.

As listas foram normalizadas para uso na nova estrutura: duplicatas internas
e pacotes presentes na camada base foram removidos. O conteudo original pode
ser consultado com, por exemplo:

```bash
git show ba70d25:conf/basic.conf
git show ba70d25:conf/light.conf
git show ba70d25:conf/heavy.conf
```

Essas listas vieram de scripts voltados a versoes antigas da One UI e devem
ser consideradas historicas e nao validadas em aparelhos Samsung atuais.

`tweaks.conf` tambem e historico. Ele nao e carregado pelo executor porque as
chaves dependem da versao da One UI e precisam ser revisadas separadamente.
