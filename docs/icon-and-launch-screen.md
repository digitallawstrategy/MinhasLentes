# Ícone e tela de lançamento — requisitos (sem arte final)

Preparação para a issue [#11](https://github.com/digitallawstrategy/MinhasLentes/issues/11).
Nenhum ícone final é produzido aqui — só requisitos técnicos, estrutura de asset e conceitos
descritos para decisão.

## Estado atual do projeto

- `MinhasLentes/Assets.xcassets/AppIcon.appiconset/Contents.json` já usa o formato moderno de
  **um único ícone universal 1024×1024** (`"idiom": "universal", "platform": "ios"`) — o Xcode
  gera todos os tamanhos derivados automaticamente a partir dele. Não há necessidade de
  produzir múltiplos arquivos de tamanho manualmente.
- A tela de lançamento já é gerada nativamente pelo sistema
  (`INFOPLIST_KEY_UILaunchScreen_Generation = YES` no `project.pbxproj`, sem
  `LaunchScreen.storyboard` customizado) — ou seja, já satisfaz o requisito de ser "simples e
  nativa, sem animações artificiais que atrasem a abertura". Nada estrutural precisa mudar
  aqui além de, opcionalmente, definir uma cor de fundo/ícone central via
  `INFOPLIST_KEY_UILaunchScreen_BackgroundColor` quando a paleta for decidida.

## Requisitos técnicos do ícone

- Arquivo único **1024×1024px**, PNG, **sem canal alfa** (a App Store rejeita ícone com
  transparência) e sem cantos arredondados pré-aplicados — o sistema aplica a máscara.
  sRGB, sem perfil de cor incorporado problemático.
  - Devem existir versões para os contextos que o `AppIcon.appiconset` do Xcode 16+ deriva do
    universal: modo claro, modo escuro (`"appearance": "luminosity", "value": "dark"`) e
    contraste alto tintado (`"appearance": "luminosity", "value": "tinted"`), se quisermos
    variantes por aparência — hoje o `Contents.json` só declara a variante universal única, o
    que é aceitável (o sistema aplica o mesmo ícone nos três modos), mas a decisão de criar
    variantes por modo é uma escolha de design a tomar junto da paleta final.
  - Á rea de segurança: o motivo principal deve caber dentro de ~**80%** da tela (iOS aplica
    máscara de cantos arredondados/squircle automaticamente; conteúdo perto da borda é cortado
    de forma imprevisível entre tamanhos).

## Legibilidade em tamanhos pequenos

- O ícone aparece a partir de **~29×29pt** (Configurações, Spotlight) — nesse tamanho, só
  formas simples e alto contraste permanecem legíveis. Testar o conceito reduzido a
  aproximadamente 60×60px antes de aprovar.
- Evitar texto no ícone (ilegível em qualquer tamanho pequeno).
- Evitar detalhes finos ou múltiplos elementos sobrepostos — um motivo central único lê melhor
  que uma composição.

## Três conceitos descritos (não desenhados)

1. **Lente estilizada** — um círculo/anel concêntrico simples (referência direta a uma lente
   de contato), preenchido com a cor primária da paleta escolhida sobre fundo sólido da cor
   secundária ou neutra. Vantagem: literal e imediatamente reconhecível como "app de lentes".
2. **Gota + anel de progresso** — uma gota estilizada (cuidado/hidratação) combinada com um
   traço de anel parcial, ecoando o `ProgressRingView` já usado no app para "usos restantes".
   Vantagem: conecta o ícone à métrica central do produto (contagem de usos), não só ao objeto
   físico.
3. **Monograma geométrico** — as iniciais ou uma forma abstrata construída com os mesmos tons
   primário/secundário da paleta, sem referência literal a olho/lente. Vantagem: menos
   "clichê de app de saúde", mais fácil de diferenciar de concorrentes; desvantagem: exige mais
   trabalho de tipo/forma para não ficar genérico.

## Tela de lançamento

- Manter a geração nativa do sistema (já configurada) — sem `LaunchScreen.storyboard` custom,
  sem animação de abertura.
- Quando a paleta for decidida: definir só a cor de fundo da tela de lançamento
  (`INFOPLIST_KEY_UILaunchScreen_BackgroundColor`) para a cor de superfície neutra da direção
  escolhida, e opcionalmente o ícone centralizado — nada além disso, para não atrasar a
  abertura do app.
