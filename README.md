# Metulas iOS (cenário + menu flutuante + rastreamento de mãos MediaPipe)

Port do cenário `desert` do app Quest para iPhone/iPad (Metal). As mãos vêm da câmera
frontal via MediaPipe Hand Landmarker (21 pontos por mão).

## Como gerar o IPA
1. Crie um repositório no GitHub e envie TODO o conteúdo desta pasta
   (código + `Resources/desert/` + `Resources/sfx/`), mantendo a estrutura.
2. Aba **Actions** > workflow **Build IPA** > **Run workflow** (ou faça um push).
3. Ao terminar, baixe o artifact **Metulas-ipa** (`Metulas.ipa`).
4. O IPA sai **sem assinatura**. Instale com AltStore, Sideloadly ou outro assinador
   usando seu Apple ID.

O modelo `hand_landmarker.task` é baixado automaticamente pelo workflow.

## Controles
- Giroscópio gira a câmera. Arrastar o dedo na tela também gira.
- Pinça (polegar + indicador) na frente da câmera e arraste: gira a cena.
- Botão redondo (embaixo): abre o menu. Com o menu aberto, o cursor branco segue sua mão;
  **pinçar em cima de um botão = clicar**. Pinçar e arrastar sobre um controle deslizante ajusta o valor,
  e sobre uma área vazia de uma lista rola a página. A barrinha embaixo do dock move o menu.
- Tudo no menu também funciona por toque na tela.

## Menu (port do Shell.java do Quest)
- Dock: hora/bateria/Wi-Fi (abre as Configurações rápidas), Ambientes, Configurações, Sobre, Fechar.
- Configurações rápidas: volume, brilho, Wi-Fi, mãos, centralizar, câmera, modo noturno, sons, rastreio de mãos, giroscópio.
- Configurações: Sistema, Personalização (ambiente e tema claro/escuro), Mãos e Controles,
  Acessibilidade (tamanho do texto), Armazenamento, Sobre.
- Cores, medidas do dock e a organização das páginas seguem o `Shell.java` original.

## Trocar de ambiente
O menu lista os 7 ambientes do original. Só aparecem como "Disponível" os que estão em `Resources/<id>/`
(mesmo formato do `desert`: `scene.bin`, `*.ktx`, `ambient.m4a`). Ids: `winterlodge`, `desert`, `bubbles`,
`ryokan`, `dome`, `spacestation`, `cybercity`. Para incluir um, coloque a pasta em `Resources/` e envie ao GitHub;
o `project.yml` já ignora as pastas que não existirem. Cada ambiente pesa uns 45 MB.

## O que foi portado
- `scene.bin` (formato V40S v2): 359 nós, 41 malhas, 248 mil vértices.
- Texturas KTX/ASTC (8x8 e 6x6) carregadas direto na GPU.
- `ambient.ogg` convertido para m4a (iOS não toca ogg).

## O que não foi portado
- Animações de balanço das palmeiras e skins (dados lidos e ignorados).
- Do menu original ficaram de fora o que depende do Quest ou de outros apps: loja, Explore, People, biblioteca de apps,
  navegador, mídia, captura, notificações, Guardian, Air Link, teclado virtual e tela de boot.
