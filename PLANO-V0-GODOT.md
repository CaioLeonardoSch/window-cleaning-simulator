# Plano v0 — Godot 3D, uma janela, primeira pessoa

Plano de implementação da primeira versão jogável em **Godot**, mirando lançamento em Steam.
Escopo desta versão: **uma única janela**, câmera em primeira pessoa, jogador parado em um
andaime, cenário mínimo. Nada de movimentação vertical, andares, dinheiro ou upgrades.

O protótipo web em `js/` **não é jogado fora**: ele vira a especificação executável de como a
limpeza tem que se comportar. Sempre que um número neste plano parecer arbitrário, ele veio de
lá, e dá para abrir o `index.html` e comparar lado a lado.

## Decisões já tomadas

| | |
| --- | --- |
| Engine | Godot **4.7.x** (4.7.2 é o stable atual). Renderer **Forward+** |
| Linguagem | GDScript |
| Dimensão | 3D de verdade (Camera3D, geometria, luz) |
| Simulação | **Híbrida**: CPU manda no jogo, GPU manda na aparência (seção 3) |
| Alvo | Windows x86_64, teclado + mouse; gamepad previsto no input map desde já |

---

## 1. Reorganizar a pasta antes de começar

```
window-cleaning-simulator/
  web-prototype/          <- todo o conteúdo atual (index.html, css/, js/, README.md)
  godot/                  <- projeto novo do Godot
  PLANO-V0-GODOT.md       <- este arquivo
  PLANO-V0.md             <- plano da versão web; referência, não roteiro
```

`git init` na raiz, se ainda não houver. `.gitignore` com `godot/.godot/`, `godot/export/`,
`*.tmp`. Um commit por etapa.

---

## 2. A mudança conceitual do 2D para o 3D

No protótipo, o mouse **é a mão**: o ponteiro anda pela tela e o braço acompanha. Em primeira
pessoa 3D isso não se sustenta — o jogador precisa poder olhar para os cantos da janela, para
o escritório, para baixo e ver a altura.

Então a v0 adota o padrão do gênero (o mesmo do PowerWash Simulator):

- **o mouse gira a cabeça** (`Input.MOUSE_MODE_CAPTURED`);
- **a mira fica fixa no centro da tela**;
- a ferramenta é um *viewmodel*: um `Node3D` filho da câmera, sempre na mesma posição
  relativa, com um sway suave quando a câmera gira;
- onde a limpeza acontece é onde o **raio que sai do centro da tela** encosta no vidro.

Consequência prática boa: o balanço do andaime, que no plano web era um risco de desalinhar o
traço, aqui sai de graça — se a câmera balança, o raio balança junto e continua correto.

Consequência prática ruim: alcançar os cantos passa a depender do enquadramento. Verificar
ainda na etapa 2 (seção 6) que, da posição do jogador, todo o vidro é alcançável com giros
confortáveis de cabeça.

---

## 3. A arquitetura híbrida

A regra que organiza tudo:

> **A CPU é a verdade do jogo. A GPU é a aparência.**

**CPU — grade de 128x80 sobre o vidro (`PackedFloat32Array`)**
Três camadas, exatamente como o protótipo: `grime`, `water`, `soap`. É aqui que rodam o
escorrimento da água, a secagem, a regra de que a esponja precisa de vidro molhado e a de que
o rodo só funciona lubrificado. É daqui que sai a porcentagem de limpeza do HUD e a condição
de vitória.

**GPU — máscara de sujeira em 1024x768 dentro de um `SubViewport`**
Serve só para o vidro ficar bonito: a sujeira some com detalhe fino, borda de pincelada
nítida, marca de rodo visível. Nada de lógica de jogo mora aqui.

**A ponte entre as duas: *brush stamps*.**
Cada ferramenta, a cada passo do traço, faz duas coisas:

1. altera os arrays da CPU (a verdade);
2. devolve uma lista de carimbos `{uv, raio, rotação, força, tipo}` para o pintor da GPU
   desenhar (a aparência).

Mesma pincelada, mesma fórmula de falloff, dois destinos.

**Por que assim, e não com leitura de volta da GPU.** O jeito ingênuo de medir a limpeza num
sistema em GPU é `SubViewport.get_texture().get_image()` — que sincroniza CPU e GPU e engasga
o frame. Mantendo a contabilidade na grade de 128x80, o número sai de graça, todo frame, sem
readback nenhum. A GPU nunca precisa ser lida.

**A única leitura de volta acontece uma vez:** quando a CPU declara a janela limpa, faz-se um
`get_image()` de confirmação para conferir que não sobrou uma mancha visível que a grade
grosseira não pegou. Um stall de um frame, na tela de conclusão, é irrelevante.

**Risco a vigiar: divergência.** Se as duas camadas discordarem, o jogador vê sujeira e o HUD
diz 100% (ou o contrário) — é o tipo de bug que destrói a confiança no jogo. Mitigação: uma
única função de falloff, compartilhada, e a rede de segurança da seção 8.

---

## 4. Estrutura do projeto Godot

```
godot/
  project.godot
  scenes/
    main.tscn              # cena raiz: mundo + player + HUD
    window_unit.tscn       # moldura + vidro + interior do escritório
    scaffold.tscn          # plataforma, guarda-corpo, cabos, balde
    player.tscn            # CameraRig + Camera3D + viewmodel
    hud.tscn
  scripts/
    player.gd              # mouse look, seleção de ferramenta, mira
    window_pane.gd         # raycast->UV, orquestra CPU e GPU
    grime_sim.gd           # simulação CPU (port do js/grid.js)
    grime_painter.gd       # pintor do SubViewport (Node2D)
    tools/
      tool_base.gd
      tool_spray.gd
      tool_sponge.gd
      tool_squeegee.gd
    hud.gd
  shaders/
    glass.gdshader
  assets/
    brush_soft.png         # pincel radial (borrifador/esponja)
    brush_blade.png        # pincel retangular (rodo)
    grime_base.png         # ou NoiseTexture2D gerada em runtime
```

---

## 5. Dimensões do mundo

Fixar isto na etapa 1 e não mexer mais — quase todo número posterior depende daqui:

| | |
| --- | --- |
| Vidro | 1.60 m (largura) x 1.20 m (altura) — proporção 4:3, igual à do SubViewport |
| Centro do vidro | y = 1.55 m |
| Moldura | perfil de 0.06 m em volta |
| Piso do andaime | y = 0.00 m, plataforma 3.00 x 0.80 m |
| Guarda-corpo | y = 1.05 m |
| Olhos do jogador | y = 1.65 m, a 0.75 m do vidro |
| FOV | 75° |
| Grade CPU | 128 x 80 células → célula de 12.5 x 15 mm |
| Máscara GPU | 1024 x 768 → texel de 1.6 x 1.6 mm |

Conversão dos raios do protótipo (o vidro tinha 620px para os atuais 1.60 m — fator
0.00258 m/px):

| Ferramenta | Protótipo | Godot |
| --- | --- | --- |
| Borrifador | raio 54 px | raio 0.14 m |
| Esponja | raio 34 px | raio 0.088 m |
| Rodo | meia-lâmina 84 px | lâmina de 0.43 m (meia-lâmina 0.217 m), espessura 0.02 m |

---

## 6. Etapas

Cada etapa fecha com o jogo rodando **e com o `.exe` exportado abrindo**. Se uma etapa não
couber numa sessão de trabalho, ela está mal cortada.

### Etapa 0 — Projeto que abre e exporta

Godot 4.7.x, Forward+, resolução 1920x1080, `stretch_mode = canvas_items`. Input map com
ações nomeadas desde já (nada de tecla hardcoded): `clean` (botão esquerdo), `tool_1/2/3`,
`reset`, `pause`. Baixar os export templates e **exportar um .exe vazio agora** — descobrir
problema de exportação no fim do projeto é o clássico que atrasa lançamento.

**Aceite:** roda no editor e o `.exe` exportado abre.

### Etapa 1 — A cena física

Tudo em geometria primitiva, sem textura, sem simulação:

- vidro: `QuadMesh` 1.60x1.20 no plano XY, com `StaticBody3D` + `CollisionShape3D` em uma
  camada de física própria (`glass`);
- moldura em quatro `BoxMesh`, fachada como um box grande atrás;
- interior: uma sala fechada de 6 x 3 x 4 m atrás do vidro, paredes claras, uma mesa, um
  monitor, duas luminárias de teto. **Precisa ser claro** — o mesmo motivo do protótipo: a
  sujeira é escura, fundo escuro faz ela sumir;
- `WorldEnvironment` com um céu simples, para o vidro limpo ter o que refletir;
- andaime pela tabela da seção 5;
- `player.tscn`: `CameraRig` (Node3D) → `Camera3D`, mouse look com limite de pitch de ±70°.

**Aceite:** dá para olhar em volta, entender que se está do lado de fora e ver o escritório
através do vidro. Rodando a 60 fps sem esforço.

### Etapa 2 — Mira, raycast e UV

```gdscript
func aim() -> Dictionary:
    var vp := get_viewport()
    var center := vp.get_visible_rect().size * 0.5
    var from := camera.project_ray_origin(center)
    var to := from + camera.project_ray_normal(center) * 3.0
    var q := PhysicsRayQueryParameters3D.create(from, to)
    q.collision_mask = GLASS_LAYER
    return camera.get_world_3d().direct_space_state.intersect_ray(q)

func point_to_uv(p: Vector3) -> Vector2:
    var l := glass.global_transform.affine_inverse() * p
    return Vector2(l.x / GLASS_SIZE.x + 0.5, 0.5 - l.y / GLASS_SIZE.y)
```

Um `Sprite3D` pequeno no ponto do impacto, como debug.

**Aceite:** o marcador acompanha a mira com precisão, inclusive nas bordas — e, girando a
cabeça confortavelmente, alcança **os quatro cantos do vidro**. Se não alcançar, ajustar
distância da câmera ou tamanho do vidro agora, antes de qualquer outra coisa.

### Etapa 3 — Simulação CPU

`grime_sim.gd`, port direto de `web-prototype/js/grid.js`:

- `PackedFloat32Array` para `grime`, `water`, `soap` (128 x 80);
- `reset()` — sujeira inicial: `FastNoiseLite` em duas frequências (a base e a fina do
  protótipo), mais o acúmulo nos cantos e os escorridos de chuva;
- `step(dt)` — port literal: água desce onde o filme passa de 0.3, última linha pinga para
  fora, água e sabão secam devagar;
- `stats()` — sujeira média, resíduo, `% limpo`;
- `each_in_circle(uv, radius, fn)` e `each_in_rect(...)`, agora em UV.

Enquanto a GPU não existe, mandar a grade CPU direto para o material do vidro como
`ImageTexture` (feio, mas é o que permite conferir a lógica).

Upload eficiente do fluido: manter água e sabão intercalados em **um único**
`PackedFloat32Array` de tamanho `W*H*2` e enviar com

```gdscript
var img := Image.create_from_data(W, H, false, Image.FORMAT_RGF, fluid.to_byte_array())
fluid_tex.update(img)
```

— `set_pixel` célula a célula seriam 10.240 chamadas por frame; `to_byte_array()` é uma.

**Aceite:** a barra de limpeza sobe, a água escorre e seca, e o que se vê no debug bate com
os números do HUD.

### Etapa 4 — As três ferramentas e o viewmodel

`tool_base.gd`:

```gdscript
class_name CleaningTool extends Resource
# stroke = { uv, uv_prev, delta, dist, dt, sub }
func apply(sim: GrimeSim, stroke: Dictionary) -> Array[Dictionary]:
    return []   # devolve os brush stamps
```

Regras portadas sem invenção (é o que faz a limpeza ser gostosa; foi calibrado no protótipo):

- **borrifador** — molha; tira só um fiapo de sujeira sozinho;
- **esponja** — só age em movimento e proporcionalmente à água; nunca leva a sujeira abaixo
  de 0.12 e deixa espuma;
- **rodo** — lâmina retangular orientada pelo eixo dominante do movimento; remove sujeira
  proporcionalmente à lubrificação (`soap*2.6 + water*1.2`); em vidro seco **piora**.

Interpolação do traço: o protótipo subdivide a cada 4 px; aqui, a cada 0.004 em UV
(≈ 6 mm no vidro).

Viewmodel: `Node3D` filho da câmera com o braço e a ferramenta, a ~0.35 m, `near` da câmera
em 0.05 para não cortar. Sway por `lerp` da rotação em relação à velocidade angular da
câmera. Trocar ferramenta com 1/2/3.

**Aceite:** molhar → esfregar → rodar leva a janela a "limpa"; o rodo em vidro seco atrapalha
de forma perceptível.

### Etapa 5 — A máscara de sujeira em GPU

`SubViewport` 1024x768 com `render_target_update_mode = UPDATE_ALWAYS` e
`render_target_clear_mode = CLEAR_MODE_NEVER` — é o "nunca limpar" que faz a textura
**acumular** as pinceladas em vez de zerar todo frame.

Sujeira inicial: um `TextureRect` com o ruído da sujeira, visível apenas no primeiro frame e
escondido em seguida; com clear desligado, o que ele desenhou permanece.

Pintor (`grime_painter.gd`, um `Node2D` com `CanvasItemMaterial.blend_mode = BLEND_MODE_SUB`):

```gdscript
func _draw() -> void:
    for s in _pending:
        draw_set_transform(s.pos, s.rot, s.scale)
        draw_texture_rect(s.brush, s.rect, false, Color(1, 1, 1, s.strength))
    _pending.clear()
```

Um único `_draw()` por frame consumindo a fila de stamps é bem mais barato que instanciar
`Sprite2D` por pincelada.

**Aceite:** a sujeira some em alta resolução, com borda de pincelada nítida e marca de rodo
visível — e o contador da CPU continua batendo com o que se vê (divergência abaixo de 3%).

### Etapa 6 — O shader do vidro

`glass.gdshader`, transparente, juntando as duas camadas:

- `uniform sampler2D grime_tex` — a máscara do SubViewport: escurece, embaça e aumenta a
  rugosidade;
- `uniform sampler2D fluid_tex` — `Image.FORMAT_RGF` da CPU (R = água, G = sabão), com filtro
  linear: é a interpolação da textura de baixa resolução que dá o borrão do filme d'água de
  graça, o mesmo truque do protótipo;
- água → brilho especular e leve distorção; sabão → espuma esbranquiçada modulada por noise;
- vidro limpo → reflexo do céu do `WorldEnvironment` e o escritório visível.

**Aceite:** sujo parece sujo, molhado parece molhado, espuma parece espuma, limpo parece
vidro.

### Etapa 7 — Fechar a janela e polir

- HUD com as duas barras e o cronômetro, banner de conclusão com tempo e uma avaliação em
  três faixas (nada de dinheiro ainda);
- `get_image()` único de confirmação na vitória (seção 3);
- balanço lento do andaime aplicado ao `CameraRig`;
- som: chiado do borrifador, esfrega da esponja, rangido do rodo em vidro seco;
- salvar melhor tempo em `user://`.

---

## 7. Performance: o que medir e quando

Não otimizar nada antes de medir. Mas saber onde vai doer:

**A grade CPU são 10.240 células por frame em GDScript.** Deve ficar na casa de 1–3 ms, o que
cabe. Se pesar, na ordem: (1) rodar `step()` a 30 Hz em vez de todo frame — a água não precisa
de 60; (2) baixar para 96x60; (3) tirar chamada de função de dentro do laço por célula; (4)
só então pensar em compute shader ou GDExtension. A grade é pequena de propósito: ela existe
para a lógica, não para a aparência.

**O SubViewport com `UPDATE_ALWAYS` custa por frame mesmo sem pinceladas.** Se aparecer no
profiler, alternar para `UPDATE_ONCE` disparado só nos frames em que há stamps na fila.

---

## 8. Rede de segurança: reconstruir a máscara

O conteúdo de um `SubViewport` com clear desligado é um buffer que pode se perder — troca de
resolução, alt-tab em certas configurações, recriação do viewport. Se sumir no meio de uma
janela, o jogador perde o progresso visual (o progresso *real* está na CPU, intacto).

Implementar desde a etapa 5 uma função `repaint_from_cpu()` que redesenha a máscara inteira a
partir da grade de 128x80 (borrada, sem o detalhe fino, mas correta) e chamá-la em
`NOTIFICATION_APPLICATION_RESUMED`, na troca de resolução e ao voltar de pausa. É o tipo de
proteção que custa meia hora agora e evita relato de bug depois do lançamento.

---

## 9. Steam: o que já dá para acertar agora

Nada de SDK nesta versão. Mas estas escolhas são caras de desfazer:

- **Renderer Forward+ (Vulkan)** decidido agora; migrar depois mexe em todo material e luz.
- **Exportar Windows a cada etapa.** Um `.exe` que abre é parte do critério de aceite.
- **Input pelo InputMap**, com um mapeamento de gamepad já previsto — Steam Deck e Big
  Picture cobram isso.
- **Textos por `tr()`** e um CSV de tradução desde a primeira string, com pt-BR e en. Trocar
  string solta por chave de tradução depois de 200 strings é trabalho perdido.
- **Salvar em `user://`**, nunca ao lado do executável (a pasta do Steam pode ser somente
  leitura).
- **O jogo tem que rodar sem a Steam.** GodotSteam entra como GDExtension quando houver
  conquistas ou nuvem; se o jogo depender dela para iniciar, testar vira um inferno.
- Página da loja, appid, capsulas: depois. Não é problema da v0.

---

## 10. O que fica de fora — e onde encaixa depois

| Depois | Onde encaixa |
| --- | --- |
| Subir e descer no andaime | o jogador já é um rig separado; vira movimento em Y da plataforma, com o vidro ativo trocando |
| Vários vidros por andar | `window_unit.tscn` já é uma cena instanciável, com sua própria `GrimeSim` e seu próprio SubViewport. Vigiar o custo: um SubViewport por janela viva ao mesmo tempo é caro — provavelmente só a janela em foco mantém a máscara em alta resolução, e as outras guardam só o estado CPU |
| Dinheiro e upgrades | os números das ferramentas ficam em `Resource` (`tool_*.tres`); upgrade é multiplicador em cima deles |
| Tipos de sujeira (gordura, pombo) | uma quarta camada na grade CPU, com regra própria de remoção e sua própria máscara na GPU |
| Segredos do escritório | o interior já é uma cena 3D de verdade — dá para esconder coisas lá dentro e o jogador só enxergar depois de limpar |

---

## 11. De onde vêm os números

Todos calibrados no protótipo web; ao portar, conferir contra ele antes de "melhorar":

| O quê | No protótipo | No Godot |
| --- | --- | --- |
| Raio e força das ferramentas | topo de cada objeto em `js/tools.js` | `tool_*.tres` |
| Escorrimento e secagem | `WindowGrid.prototype.step` | `grime_sim.gd: step()` |
| Sujeira inicial | `WindowGrid.prototype.reset` | `grime_sim.gd: reset()` |
| Limiares de conclusão | `CONFIG.win` (sujeira 4%, resíduo 5%) | constantes em `window_pane.gd` |
| Aparência da sujeira/água/sabão | `WindowGrid.prototype.render` | `glass.gdshader` |
