# Android Debloater

Script em Bash para inspecionar, desativar, remover ou restaurar pacotes
Android por ADB. A configuracao e composta por uma camada opcional de apps
comuns e um perfil especifico do fabricante.

## Estado atual

- Samsung: listas historicas nos niveis basico, moderado e pesado.
- Xiaomi: lista basica derivada do Redmi Note 10S.
- Motorola: aplicativos de terceiros e um lote separado de sistema revisado
  no Edge 70 Pro.
- Tweaks: preservados como historico Samsung, mas nao executados.

As listas Samsung antigas nao devem ser tratadas como recomendacoes para
versoes atuais da One UI. Leia as descricoes dos perfis antes de executar.

## Requisitos

- GNU/Linux com Bash 4 ou posterior.
- Android Platform Tools (`adb`).
- Opcoes do desenvolvedor e depuracao USB habilitadas.
- Exatamente um aparelho autorizado por vez.

## Uso

```bash
git clone https://github.com/abairo/debloat_xiaomi_redmi
cd debloat_xiaomi_redmi
./run.sh
```

O programa detecta Samsung, Xiaomi ou Motorola, permite selecionar o perfil e
pergunta se a camada base deve ser incluida quando ela for aplicavel. A opcao
padrao mais segura e **Apenas visualizar**, que nao modifica o aparelho.

No Motorola existem dois perfis independentes: aplicativos de terceiros
revisados e sistema revisado (experimental). O perfil de sistema nao carrega a
camada base. Use primeiro **Desativar**, reinicie e teste o aparelho; escolha
**Desinstalar** somente depois dessa validacao.

Antes de `disable`, `uninstall` ou `restore`, o programa mostra somente os
pacotes do perfil encontrados no dispositivo e exige a confirmacao literal
`SIM`.

## Estrutura

```text
conf/
├── base/
│   └── packages.conf
└── vendors/
    ├── samsung/
    │   ├── packages/
    │   │   ├── basic.conf
    │   │   ├── light.conf
    │   │   └── heavy.conf
    │   └── tweaks.conf
    ├── motorola/
    │   ├── packages/
    │   │   ├── basic.conf
    │   │   └── system-reviewed.conf
    │   └── README.md
    └── xiaomi/
        └── packages/
            └── basic.conf
```

## Acoes

- **Visualizar:** cruza a configuracao com os pacotes conhecidos pelo Android.
- **Desativar:** usa `pm disable-user --user 0` e preserva o APK.
- **Desinstalar:** usa `pm uninstall --user 0`; em apps de sistema, nao apaga
  o APK da particao de sistema.
- **Restaurar:** usa `cmd package install-existing --user 0` e tenta habilitar
  novamente o pacote.

## Origem

O projeto foi adaptado de
[`slackjeff/debloated_Samsung`](https://github.com/slackjeff/debloated_Samsung),
por sua vez baseado em
[`invinciblevenom/debloat_samsung_android`](https://github.com/invinciblevenom/debloat_samsung_android).
Os commits originais anteriores a adaptacao Xiaomi permanecem no historico.
