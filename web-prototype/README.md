# Window Cleaning Simulator

Base de um jogo de limpar janelas. O personagem fica parado de costas para a câmera, de frente
para um vidro sujo, e só o braço se move: ele acompanha o ponteiro segurando a ferramenta atual.

A limpeza acontece em três etapas, na ordem:

1. **Borrifador (1)** — molha o vidro. Sem água, a esponja não faz espuma.
2. **Esponja com sabão (2)** — precisa de movimento e de vidro molhado. Solta a sujeira e deixa
   espuma, mas sempre sobra uma película: a esponja sozinha não termina o serviço.
3. **Rodo de mão (3)** — puxado em linha reta, remove espuma, água e a película que sobrou.
   Passado em vidro seco, ele só arrasta a sujeira e piora o resultado.

A janela é considerada limpa quando a sujeira média fica abaixo de 4% e o resíduo (água + sabão)
abaixo de 5%. O cronômetro começa no primeiro clique.

## Como rodar

Não tem build nem dependência: abra `index.html` no navegador (Chrome, Edge ou Firefox atuais —
o desenho usa `roundRect`). Se preferir servir por HTTP:

```
npx serve .
```

## Controles

| Ação | Comando |
| --- | --- |
| Usar a ferramenta | segurar o botão do mouse / arrastar o dedo sobre o vidro |
| Trocar de ferramenta | `1`, `2`, `3` ou os botões abaixo do canvas |
| Reiniciar a janela | `R` ou o botão *Reiniciar* |

## Estrutura

```
index.html        marcação, HUD e ordem de carga dos scripts
css/style.css     interface (barras de limpeza/resíduo, cronômetro, barra de ferramentas)
js/config.js      constantes: tamanho do canvas, retângulo do vidro, resolução do grid, vitória
js/grid.js        simulação: camadas de sujeira, água e sabão + desenho do vidro
js/tools.js       as três ferramentas (efeito no grid + desenho na mão)
js/scene.js       cenário: paisagem atrás do vidro, brilho, esquadria, peitoril, balde
js/character.js   personagem estático e o braço que segue o ponteiro
js/game.js        loop, entrada de mouse/toque, HUD e condição de vitória
js/main.js        bootstrap
```

## Como a simulação funciona

O vidro é um grid de 112x70 células (`js/config.js`) com três `Float32Array`: `grime`, `water` e
`soap`. Cada ferramenta escreve nesses arrays; o grid é desenhado em um canvas do tamanho do grid
e esticado sobre o vidro, o que dá o borrão suave da sujeira de graça.

- `grid.step(dt)` faz a água escorrer para baixo (só onde o filme é grosso, acima de 0.3), pingar
  para fora na última linha e a água/sabão secarem devagar.
- O traço do mouse é interpolado em passos de 4px (`Game.update`), então movimento rápido não
  deixa buracos.
- O rodo usa uma lâmina retangular orientada pelo eixo dominante do movimento: arrastar na
  horizontal deixa a lâmina em pé, e vice-versa.

Os números de ajuste ficam todos juntos: força e raio de cada ferramenta em `js/tools.js`,
persistência de água/sabão em `WindowGrid.prototype.step`, limiares de vitória em `js/config.js`.

## Ideias para as próximas etapas

- Fases: mais de uma janela, sujeiras diferentes (gordura, tinta, cocô de pombo) e alvo de tempo.
- Estados da ferramenta: balde que suja, esponja que satura, borrifador que esvazia.
- Marcas do rodo: registrar as estrias deixadas por passadas mal feitas e cobrar por elas.
- Áudio e feedback (rangido do rodo, chiado do borrifador).
