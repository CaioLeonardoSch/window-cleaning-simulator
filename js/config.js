// Constantes compartilhadas do jogo.
window.WCS = window.WCS || {};

WCS.CONFIG = {
  canvas: { w: 960, h: 600 },
  // Retângulo do vidro, em pixels do canvas.
  pane: { x: 170, y: 60, w: 620, h: 380 },
  frame: 22,
  // Resolução da simulação de sujeira (uma célula ~5.5px).
  grid: { cols: 112, rows: 70 },
  // Limiares de vitória (médias do grid).
  win: { grime: 0.04, residue: 0.05 }
};
