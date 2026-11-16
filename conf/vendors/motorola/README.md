# Perfil Motorola

O perfil inicial foi criado a partir de um Motorola edge 70 pro com Android
16. Os aplicativos de terceiros e os primeiros pacotes de sistema foram
revisados em lotes independentes.

Aplicativos independentes do fabricante foram adicionados a
`conf/base/packages.conf`. O perfil Motorola contem apenas pacotes exclusivos
da marca. Os demais pacotes de sistema, incluindo `com.dti.motorola`, ainda
nao foram avaliados e nao fazem parte das configuracoes ativas. No perfil
`basic`, o executor filtra em tempo real e aceita somente pacotes que o proprio
Android classifica como terceiros.

`system-reviewed.conf` e um lote experimental separado, criado apenas com os
pacotes marcados apos revisao manual. O executor nao combina a camada base com
esse lote e confirma em tempo real que cada entrada e um pacote de sistema.
Teste primeiro com `Disable`, reinicie o aparelho e valide os recursos antes
de escolher `Uninstall`.
