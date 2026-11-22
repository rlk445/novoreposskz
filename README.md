# Metulas iOS (cenário Desert + rastreamento de mãos MediaPipe)

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
- Botões: ligar/desligar giro, mostrar/ocultar câmera, centralizar.

## O que foi portado
- `scene.bin` (formato V40S v2): 359 nós, 41 malhas, 248 mil vértices.
- Texturas KTX/ASTC (8x8 e 6x6) carregadas direto na GPU.
- `ambient.ogg` convertido para m4a (iOS não toca ogg).

## O que não foi portado
- Animações de balanço das palmeiras e skins (dados lidos e ignorados).
- Navegador, mídia, captura, notificações, boot: não existem no iOS.
