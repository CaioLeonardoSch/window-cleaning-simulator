// Simulação da sujeira do vidro: três camadas (sujeira, água, sabão)
// guardadas em um grid de baixa resolução e desenhadas escaladas.
(function (WCS) {
  'use strict';

  var pane = WCS.CONFIG.pane;
  var GRID = WCS.CONFIG.grid;

  function clamp01(v) { return v < 0 ? 0 : v > 1 ? 1 : v; }

  // Ruído de valor bilinear, usado para o padrão de encardido.
  function valueNoise(cols, rows, fx, fy) {
    var gw = fx + 1, gh = fy + 1;
    var g = new Float32Array(gw * gh);
    for (var i = 0; i < g.length; i++) g[i] = Math.random();

    var out = new Float32Array(cols * rows);
    for (var y = 0; y < rows; y++) {
      var v = (y / (rows - 1)) * fy;
      var y0 = Math.min(gh - 2, Math.floor(v));
      var ty = v - y0, sy = ty * ty * (3 - 2 * ty);
      for (var x = 0; x < cols; x++) {
        var u = (x / (cols - 1)) * fx;
        var x0 = Math.min(gw - 2, Math.floor(u));
        var tx = u - x0, sx = tx * tx * (3 - 2 * tx);
        var a = g[y0 * gw + x0], b = g[y0 * gw + x0 + 1];
        var c = g[(y0 + 1) * gw + x0], d = g[(y0 + 1) * gw + x0 + 1];
        out[y * cols + x] = (a + (b - a) * sx) * (1 - sy) + (c + (d - c) * sx) * sy;
      }
    }
    return out;
  }

  // Compõe uma cor sobre (r,g,b,a) já acumulados, source-over.
  function over(dst, sr, sg, sb, sa) {
    if (sa <= 0) return;
    var na = sa + dst[3] * (1 - sa);
    if (na <= 0) { dst[3] = 0; return; }
    var k = dst[3] * (1 - sa);
    dst[0] = (sr * sa + dst[0] * k) / na;
    dst[1] = (sg * sa + dst[1] * k) / na;
    dst[2] = (sb * sa + dst[2] * k) / na;
    dst[3] = na;
  }

  function WindowGrid() {
    this.cols = GRID.cols;
    this.rows = GRID.rows;
    this.n = this.cols * this.rows;
    this.cellW = pane.w / this.cols;
    this.cellH = pane.h / this.rows;

    this.grime = new Float32Array(this.n);
    this.water = new Float32Array(this.n);
    this.soap = new Float32Array(this.n);

    this.layer = document.createElement('canvas');
    this.layer.width = this.cols;
    this.layer.height = this.rows;
    this.lctx = this.layer.getContext('2d');
    this.image = this.lctx.createImageData(this.cols, this.rows);

    // Textura fixa da espuma, para o sabao nao virar um branco chapado.
    this.foam = valueNoise(this.cols, this.rows, 26, 18);

    this.initialGrime = 1;
    this.reset();
  }

  WindowGrid.prototype.reset = function () {
    var cols = this.cols, rows = this.rows;
    var base = valueNoise(cols, rows, 7, 5);
    var fine = valueNoise(cols, rows, 21, 14);
    var total = 0;

    for (var y = 0; y < rows; y++) {
      var v = y / (rows - 1);
      for (var x = 0; x < cols; x++) {
        var u = x / (cols - 1);
        var i = y * cols + x;

        var g = 0.38 + 0.34 * base[i] + 0.16 * fine[i];

        // Cantos e bordas acumulam mais crosta.
        var edge = 1 - Math.min(1, Math.min(u, 1 - u) * 5) * Math.min(1, Math.min(v, 1 - v) * 5);
        g += 0.3 * edge * edge;

        // Escorridos de chuva descendo o vidro.
        var drip = Math.sin(u * Math.PI * 11 + base[i] * 3) * 0.5 + 0.5;
        g += 0.18 * Math.pow(drip, 3) * v;

        g = clamp01(g);
        this.grime[i] = g;
        this.water[i] = 0;
        this.soap[i] = 0;
        total += g;
      }
    }
    this.initialGrime = Math.max(0.001, total / this.n);
  };

  // Percorre células dentro de um círculo (coordenadas do canvas).
  // fn(indice, falloff 0..1)
  WindowGrid.prototype.eachInCircle = function (x, y, radius, fn) {
    var cx = (x - pane.x) / this.cellW;
    var cy = (y - pane.y) / this.cellH;
    var rx = radius / this.cellW, ry = radius / this.cellH;

    var x0 = Math.max(0, Math.floor(cx - rx));
    var x1 = Math.min(this.cols - 1, Math.ceil(cx + rx));
    var y0 = Math.max(0, Math.floor(cy - ry));
    var y1 = Math.min(this.rows - 1, Math.ceil(cy + ry));

    for (var gy = y0; gy <= y1; gy++) {
      var dy = (gy + 0.5 - cy) / ry;
      for (var gx = x0; gx <= x1; gx++) {
        var dx = (gx + 0.5 - cx) / rx;
        var d2 = dx * dx + dy * dy;
        if (d2 > 1) continue;
        fn(gy * this.cols + gx, 1 - d2 * 0.75);
      }
    }
  };

  // Percorre células dentro de um retângulo (usado pela lâmina do rodo).
  WindowGrid.prototype.eachInRect = function (x, y, hw, hh, fn) {
    var cx = (x - pane.x) / this.cellW;
    var cy = (y - pane.y) / this.cellH;
    var rx = hw / this.cellW, ry = hh / this.cellH;

    var x0 = Math.max(0, Math.floor(cx - rx));
    var x1 = Math.min(this.cols - 1, Math.ceil(cx + rx));
    var y0 = Math.max(0, Math.floor(cy - ry));
    var y1 = Math.min(this.rows - 1, Math.ceil(cy + ry));

    for (var gy = y0; gy <= y1; gy++) {
      var ty = Math.abs(gy + 0.5 - cy) / ry;
      if (ty > 1) continue;
      var fy = ty < 0.75 ? 1 : (1 - ty) * 4;
      for (var gx = x0; gx <= x1; gx++) {
        var tx = Math.abs(gx + 0.5 - cx) / rx;
        if (tx > 1) continue;
        var fx = tx < 0.75 ? 1 : (1 - tx) * 4;
        fn(gy * this.cols + gx, clamp01(fx * fy));
      }
    }
  };

  // Água escorre para baixo, água e sabão secam devagar.
  WindowGrid.prototype.step = function (dt) {
    var cols = this.cols, rows = this.rows;
    var water = this.water, soap = this.soap;
    var flow = Math.min(0.2, dt * 0.7);

    for (var y = rows - 2; y >= 0; y--) {
      for (var x = 0; x < cols; x++) {
        var i = y * cols + x;
        var w = water[i];
        if (w > 0.3) {
          var move = (w - 0.3) * flow * 0.9;
          water[i] = w - move;
          water[i + cols] = clamp01(water[i + cols] + move);
        }
      }
    }

    // Última linha pinga para fora do vidro.
    var drain = Math.max(0, 1 - dt * 0.5);
    for (var x2 = 0; x2 < cols; x2++) water[(rows - 1) * cols + x2] *= drain;

    var dryW = Math.max(0, 1 - dt * 0.015);
    var dryS = Math.max(0, 1 - dt * 0.008);
    for (var j = 0; j < this.n; j++) { water[j] *= dryW; soap[j] *= dryS; }
  };

  WindowGrid.prototype.stats = function () {
    var g = 0, r = 0;
    for (var i = 0; i < this.n; i++) {
      g += this.grime[i];
      r += this.soap[i] + this.water[i] * 0.6;
    }
    g /= this.n;
    r /= this.n;
    return {
      grime: g,
      residue: clamp01(r),
      clean: clamp01((this.initialGrime - g) / this.initialGrime)
    };
  };

  WindowGrid.prototype.render = function (ctx) {
    var data = this.image.data;
    var px = [0, 0, 0, 0];

    for (var i = 0; i < this.n; i++) {
      px[0] = 0; px[1] = 0; px[2] = 0; px[3] = 0;

      var g = this.grime[i];
      if (g > 0.002) over(px, 88 + 18 * g, 78 + 14 * g, 60, clamp01(g * 0.92));

      var w = this.water[i];
      if (w > 0.002) over(px, 186, 214, 238, clamp01(w * 0.34));

      var s = this.soap[i];
      if (s > 0.002) over(px, 244, 248, 252, clamp01(s * (0.45 + 0.8 * this.foam[i])));

      var o = i * 4;
      data[o] = px[0];
      data[o + 1] = px[1];
      data[o + 2] = px[2];
      data[o + 3] = px[3] * 255;
    }

    this.lctx.putImageData(this.image, 0, 0);
    ctx.save();
    ctx.imageSmoothingEnabled = true;
    ctx.drawImage(this.layer, pane.x, pane.y, pane.w, pane.h);
    ctx.restore();
  };

  WCS.WindowGrid = WindowGrid;
  WCS.clamp01 = clamp01;
})(window.WCS);
