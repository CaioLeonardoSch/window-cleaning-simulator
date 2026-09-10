# Plano v0 — uma janela, primeira pessoa

> **Substituído.** O jogo vai ser feito em Godot, para Steam — o roteiro ativo é
> `PLANO-V0-GODOT.md`. Este documento fica como referência do protótipo web, que
> continua valendo como especificação de *como a limpeza tem que se comportar*.

Instruções para transformar a base atual (`Window Cleaning Simulator`) na primeira versão
jogável do jogo do prédio comercial: **uma única janela**, vista em primeira pessoa, de fora
do prédio, em cima de um andaime, com cenário mínimo.

Regra do plano: cada etapa termina com o jogo rodando. Nenhuma etapa depende de a seguinte
estar pronta. Se uma etapa ficar grande, ela está mal cortada — divida antes de começar.

Antes da etapa 1: `git init && git add -A && git commit -m "base"` (a pasta ainda não é
repositório). Cada etapa vira um commit.

---

## 1. O que essa versão é — e o que não é

**É:** a mesma simulação de limpeza que já existe, com a câmera no lugar dos olhos do
personagem, do lado de fora do prédio, olhando para o escritório através do vidro sujo.

**Não é:** movimentação no andaime, mais de uma janela, andares, dinheiro, upgrades, tipos
diferentes de sujeira, eventos de escritório. Tudo isso está listado na seção 8 e fica para
depois — a única obrigação da v0 é não fechar a porta para essas coisas.

---

## 2. O que já está pronto e não se mexe

A parte difícil — a sensação de limpar — já está resolvida e sai intacta desta etapa:

- `js/grid.js` — simulação de sujeira, água e sabão em grid 112x70, escorrimento e secagem.
- `js/tools.js` — borrifador, esponja e rodo; efeito no grid e desenho na mão.
- `js/game.js` — loop, interpolação do traço, HUD, condição de vitória.

Esta versão mexe em **quem olha e no que está em volta**, não na física do vidro.

---

## 3. O que muda

| Hoje | v0 |
| --- | --- |
| Terceira pessoa: personagem inteiro de costas | Primeira pessoa: antebraço, mão e ferramenta |
| Câmera dentro da sala, olhando para fora | Câmera fora do prédio, olhando para dentro |
| Céu e cidade atrás do vidro | Escritório atrás do vidro |
| Parede interna, peitoril, balde no chão da sala | Fachada de concreto, moldura de alumínio, plataforma do andaime |
| Janela ocupa metade da tela (sobra espaço para o corpo) | Janela ocupa quase toda a tela |

Mapa de arquivos:

| Arquivo | Ação |
| --- | --- |
| `js/config.js` | ampliar: novo enquadramento, origem do braço, andaime |
| `js/grid.js` | inalterado (um ajuste opcional na seção 7) |
| `js/tools.js` | inalterado, exceto o item opcional da etapa 3 (lâmina do rodo) |
| `js/scene.js` | reescrever |
| `js/character.js` | vira `js/hands.js` |
| `js/game.js` | ajustes pequenos: ordem de desenho e chamada das mãos |
| `index.html` | trocar o `<script>` de `character.js` para `hands.js` |
| `css/style.css` | inalterado |

---

## 4. Etapa 1 — Reenquadrar a câmera

Objetivo: tirar o personagem da tela e deixar a janela ocupar o quadro, mantendo o jogo
jogável (a ferramenta segue o ponteiro, sem braço nenhum).

1. Em `js/config.js`, trocar o retângulo do vidro e acrescentar as constantes novas:

```js
WCS.CONFIG = {
  canvas: { w: 960, h: 600 },
  // Vidro quase preenchendo o quadro; sobra a faixa de baixo para o andaime.
  pane: { x: 130, y: 34, w: 700, h: 430 },
  frame: 20,
  grid: { cols: 112, rows: 70 },
  win: { grime: 0.04, residue: 0.05 },
  // Primeira pessoa: o antebraço entra por fora da tela, embaixo à direita.
  hand: { originX: 700, originY: 700 },
  // Andaime: onde começa a plataforma e onde fica o guarda-corpo.
  scaffold: { floorY: 516, railY: 486 }
};
```

2. Em `js/game.js`, no `render`, comentar a chamada de `WCS.Character.draw` e desenhar a
   ferramenta direto no ponteiro, sem braço:

```js
if (this.pointer.inside) {
  ctx.save();
  ctx.translate(this.pointer.x, this.pointer.y);
  this.tool.draw(ctx, this.pressed);
  ctx.restore();
}
```

**Aceite:** o vidro sujo ocupa quase todo o canvas, a ferramenta acompanha o mouse, limpar
ainda funciona e a barra de limpeza ainda chega a 100%. A tela está feia — é esperado.

---

## 5. Etapa 2 — As mãos em primeira pessoa

Renomear `js/character.js` para `js/hands.js`, apagar o conteúdo e escrever o módulo abaixo.
Atualizar o `<script>` em `index.html`.

Contrato: `WCS.Hands.draw(ctx, hand, tool, active, t)` — mesma assinatura que
`WCS.Character.draw` tinha, para o `game.js` mudar só o nome.

Geometria, em três partes:

**a) Antebraço.** Sai da origem fora da tela (`CONFIG.hand`) e termina na mão, no ponteiro.
Desenhar como quadrilátero afunilado (grosso na origem, fino no punho), não como linha de
espessura fixa — é o que dá a leitura de profundidade:

```js
function drawForearm(ctx, hand) {
  var o = WCS.CONFIG.hand;
  var dx = hand.x - o.originX, dy = hand.y - o.originY;
  var d = Math.hypot(dx, dy) || 1;
  var nx = -dy / d, ny = dx / d;      // perpendicular
  var wo = 46, wh = 15;               // meia-largura na origem e no punho
  ctx.fillStyle = SKIN;
  ctx.beginPath();
  ctx.moveTo(o.originX + nx * wo, o.originY + ny * wo);
  ctx.lineTo(hand.x + nx * wh, hand.y + ny * wh);
  ctx.lineTo(hand.x - nx * wh, hand.y - ny * wh);
  ctx.lineTo(o.originX - nx * wo, o.originY - ny * wo);
  ctx.closePath();
  ctx.fill();
  // Manga: mesmo caminho, cortado no primeiro terço.
  return Math.atan2(dy, dx);
}
```

**b) Mão e ferramenta.** A ferramenta já é desenhada em `tools.js` no espaço local da mão
(corpo para a esquerda, ponta para a direita), então basta rotacionar pelo ângulo do
antebraço. Acrescentar uma escala de perspectiva: mais perto da base da tela, maior.

```js
var s = 0.72 + 0.42 * (hand.y / WCS.CONFIG.canvas.h);
ctx.translate(hand.x, hand.y);
ctx.rotate(angle);
ctx.scale(s, s);
tool.draw(ctx, active);
```

**c) Mão parada.** Uma mão fechada no guarda-corpo, no canto inferior esquerdo, em posição
fixa (`x ≈ 120`, `y ≈ CONFIG.scaffold.railY`). Só um punho e o começo da manga; ela nunca se
move nesta versão.

Tirar o `bob` senoidal do corpo antigo — em primeira pessoa a oscilação vai no cenário
inteiro (item opcional da etapa 6), não no braço.

**Aceite:** movendo o mouse pelo vidro, o braço sai de baixo à direita e a ferramenta gira
seguindo o braço; a ferramenta encolhe ao subir na tela; a mão parada segura a barra à
esquerda. Limpar continua funcionando exatamente como antes.

---

## 6. Etapa 3 — Do lado de fora: o escritório atrás do vidro

Reescrever `js/scene.js`. A API que o `game.js` usa passa a ser:

```js
WCS.Scene = {
  build: build,           // monta os offscreens (interior); determinístico
  reset: build,           // R reconstrói a mesma cena
  drawFacade: ...,        // parede do prédio, atrás de tudo
  drawInterior: ...,      // escritório, recortado no retângulo do vidro
  drawGloss: ...,         // reflexo do céu no vidro (aproveitar o atual)
  drawFrame: ...,         // moldura de alumínio + pingadeira
  drawScaffold: ...       // cabos, piso, guarda-corpo, balde
};
```

**Fachada** (`drawFacade`): gradiente vertical de concreto (`#6d7480` no topo para `#565c66`
embaixo), duas ou três juntas horizontais em `rgba(0,0,0,.10)`. Nada além disso.

**Interior** (`drawInterior`): montar uma vez em canvas offscreen do tamanho do vidro, como
o `buildBackdrop` atual já faz, e desenhar com `drawImage` no retângulo do vidro. Conteúdo
mínimo, sem `Math.random()` — a sala precisa ser a mesma toda vez que o jogador aperta R:

- parede do fundo clara (`#dfe3e6`) ocupando os dois terços de cima;
- forro com duas luminárias retangulares acesas (`#fbfaf2`) e um halo suave embaixo delas;
- piso em carpete (`#9aa3a9`) no terço de baixo, com uma linha de rodapé;
- uma mesa em silhueta escura contra a parede, um monitor com a tela em azul apagado, uma
  cadeira e uma planta em vaso no canto.

**Contraste — o ponto que estraga tudo se for ignorado:** a sujeira é desenhada em
`grid.render` como um marrom acinzentado (`88,78,60`) com alfa até `0.92`, ou seja, escura
sobre fundo claro. O céu de hoje é claro e por isso a sujeira lê bem. Um escritório escuro
faria a sujeira sumir. Portanto: manter a maior parte do interior com luminância alta
(paredes e forro claros, luzes acesas) e deixar as partes escuras (mesa, monitor) ocupando
pouco espaço. Se em algum momento o interior escurecer de vez, o ajuste é em `grid.render`,
trocando a cor da sujeira por uma clara e mudando a composição — não vale mexer no interior
depois de calibrar o resto.

**Moldura** (`drawFrame`): partir da função atual, trocando o branco interno (`#e7e2d6`) por
alumínio (`#9099a3` com um brilho de topo em `#b8c0c8`) e o peitoril interno por uma
pingadeira externa mais fina, saliente para fora, logo abaixo do vidro.

**Aceite:** ao abrir o jogo, dá para entender em um segundo que se está do lado de fora
olhando para dentro de um escritório; a sujeira continua nítida e a barra de limpeza ainda
sobe do mesmo jeito com as três ferramentas.

*Opcional, barato, melhora muito o rodo:* hoje `squeegee.apply` orienta a lâmina pelo eixo
dominante do movimento, mas `squeegee.draw` desenha a lâmina sempre na mesma direção em
relação ao braço. Guardar em `Game` o último eixo (`this.bladeVertical`) e passá-lo como
terceiro argumento de `tool.draw(ctx, active, opts)`, usando-o para girar a lâmina 90° no
desenho. Só o rodo lê `opts`; as outras duas ferramentas ignoram.

---

## 7. Etapa 4 — O andaime

`drawScaffold`, desenhado depois da moldura e antes das mãos:

- dois cabos de aço verticais (`#3c4149`, 4px) descendo do topo do canvas até o piso, um em
  cada lateral, passando **na frente** da fachada e da janela;
- piso da plataforma a partir de `CONFIG.scaffold.floorY`: tábuas horizontais em madeira
  cinzenta, com uma linha escura a cada ~70px, e sombra na quina de encontro com a parede;
- guarda-corpo em `CONFIG.scaffold.railY`: um tubo horizontal atravessando a tela inteira,
  com dois montantes verticais ligando-o ao piso;
- o balde (aproveitar `drawBucket`) apoiado no piso, à esquerda, reposicionado para
  `y ≈ floorY + 30`;
- uma vinheta discreta nas bordas do canvas (`rgba(0,0,0,.18)` em gradiente radial) para
  fechar o enquadramento de primeira pessoa.

Com os valores da etapa 1, o vidro termina em `y = 464` e o guarda-corpo fica em `y = 486`,
ou seja, sobre a moldura, logo abaixo do vidro. Se você subir o guarda-corpo para dentro do
vidro — fica mais bonito, vende melhor a altura —, ele não pode cobrir mais que uns 25px,
senão sobra sujeira inalcançável na borda de baixo. O teste é a barra de limpeza: se ela
travar abaixo de 100% mesmo com o vidro parecendo limpo, é o andaime cobrindo célula do
grid; subir `CONFIG.scaffold.railY` ou reduzir `CONFIG.pane.h`.

**Aceite:** dá para limpar a janela inteira, incluindo os quatro cantos, sem que nenhum
elemento do andaime atrapalhe o traço.

---

## 8. Etapa 5 — Fechar o ciclo de uma janela

O loop já tem começo (primeiro clique) e fim (limiares de vitória). Falta só apresentar isso
como *uma diária de trabalho de uma janela*:

- no banner de vitória, além do tempo, mostrar uma avaliação simples derivada do que já
  existe: `tempo` e `resíduo final`, em três faixas (por exemplo, abaixo de 60s e resíduo
  abaixo de 2% = melhor faixa). Nada de dinheiro ainda — só o texto;
- ajustar o `#hint` para reagir ao estado do vidro, não só à ferramenta escolhida: se a
  ferramenta é a esponja e a média de água está perto de zero, sugerir borrifar antes;
- trocar o título em `index.html` e o `<h1>` para o nome do jogo do prédio;
- atualizar o `README.md`: a base agora é primeira pessoa, do lado de fora, e a seção
  "Ideias para as próximas etapas" passa a apontar para a seção 9 deste documento.

**Aceite:** um jogador que nunca viu o jogo consegue, sem explicação, molhar, esfregar,
rodar e ver a janela ser dada como concluída.

---

## 9. Etapa 6 — Polimento opcional

Só depois de todas as anteriores fecharem, e apenas se sobrar vontade:

- **Balanço do andaime.** Deslocar toda a cena por `sx = Math.sin(t * 0.6) * 2`,
  `sy = Math.cos(t * 0.4) * 1.5` com um `ctx.translate` que envolve tudo. **Cuidado:** o
  ponteiro é convertido para coordenadas do canvas em `Game.toCanvas` e usado direto para
  indexar o grid. Se a cena se desloca e a conversão não, o traço fica fora do lugar. Guardar
  o deslocamento em `this.sway` e subtraí-lo em `toCanvas`.
- **Poeira e reflexo:** um brilho fraco de sol varrendo o vidro devagar.
- **Som:** chiado do borrifador, rangido do rodo em vidro seco. Um `AudioContext` e dois
  ruídos curtos sintetizados bastam; nada de arquivos.

---

## 10. O que fica de fora (e onde vai encaixar depois)

Nada disso entra na v0. Está aqui para que as decisões acima não atrapalhem:

| Depois | Onde encaixa |
| --- | --- |
| Subir e descer no andaime | `CONFIG.pane` e as funções de cena já recebem tudo por parâmetro/config; a movimentação vira um deslocamento vertical da cena e uma troca do vidro ativo |
| Várias janelas por andar | `WindowGrid` hoje lê `CONFIG.pane` no carregamento do módulo. Passar o retângulo no construtor (`new WindowGrid(rect)`) é uma mudança de três linhas e destrava múltiplas janelas — vale fazer já, se for barato |
| Dinheiro e upgrades | as constantes de força e raio já estão isoladas em `tools.js`; upgrade vira multiplicador nesses números |
| Tipos de sujeira (gordura, pombo) | uma quarta `Float32Array` no grid, com regra própria de remoção |
| Segredos do escritório | o interior já é um offscreen próprio: dá para trocar o conteúdo por andar e esconder coisas nele |

---

## 11. Onde ficam os números de ajuste

Para não caçar depois:

- enquadramento, origem do braço e andaime: `js/config.js`;
- força e raio das ferramentas: topo de cada objeto em `js/tools.js`;
- persistência de água e sabão: `WindowGrid.prototype.step`;
- cor e opacidade da sujeira: `WindowGrid.prototype.render`;
- limiares de conclusão: `CONFIG.win`.
