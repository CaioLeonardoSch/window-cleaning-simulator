// Cenario: paisagem atras do vidro, brilho do vidro, esquadria e parede.
(function (WCS) {
  'use strict';

  var C = WCS.CONFIG;
  var pane = C.pane;
  var backdrop = null;

  function buildBackdrop() {
    var cv = document.createElement('canvas');
    cv.width = pane.w;
    cv.height = pane.h;
    var g = cv.getContext('2d');

    var sky = g.createLinearGradient(0, 0, 0, pane.h);
    sky.addColorStop(0, '#5fa8d8');
    sky.addColorStop(0.55, '#9ccbe4');
    sky.addColorStop(1, '#d8e6ea');
    g.fillStyle = sky;
    g.fillRect(0, 0, pane.w, pane.h);

    var sun = g.createRadialGradient(pane.w * 0.78, pane.h * 0.2, 6, pane.w * 0.78, pane.h * 0.2, 130);
    sun.addColorStop(0, 'rgba(255,246,214,.95)');
    sun.addColorStop(1, 'rgba(255,246,214,0)');
    g.fillStyle = sun;
    g.fillRect(0, 0, pane.w, pane.h);

    g.fillStyle = 'rgba(255,255,255,.5)';
    for (var c = 0; c < 5; c++) {
      var cx = Math.random() * pane.w;
      var cy = 20 + Math.random() * pane.h * 0.35;
      for (var p = 0; p < 5; p++) {
        g.beginPath();
        g.ellipse(cx + p * 18 - 36, cy + (p % 2) * 6, 30 - Math.abs(p - 2) * 5, 13, 0, 0, Math.PI * 2);
        g.fill();
      }
    }

    var layers = [
      { base: pane.h * 0.92, min: 60, max: 150, color: '#8ea6b8', win: 'rgba(255,255,255,.25)' },
      { base: pane.h, min: 90, max: 210, color: '#5f7488', win: 'rgba(255, 232, 170, .55)' }
    ];
    for (var l = 0; l < layers.length; l++) {
      var L = layers[l];
      var x = -20;
      while (x < pane.w + 20) {
        var w = 38 + Math.random() * 60;
        var h = L.min + Math.random() * (L.max - L.min);
        g.fillStyle = L.color;
        g.fillRect(x, L.base - h, w, h + 20);
        g.fillStyle = L.win;
        for (var wy = L.base - h + 12; wy < L.base - 10; wy += 16) {
          for (var wx = x + 7; wx < x + w - 8; wx += 13) {
            if (Math.random() < 0.55) g.fillRect(wx, wy, 6, 8);
          }
        }
        x += w + 6 + Math.random() * 12;
      }
    }
    backdrop = cv;
  }

  function drawBackdrop(ctx) {
    if (!backdrop) buildBackdrop();
    ctx.drawImage(backdrop, pane.x, pane.y);
  }

  function drawGloss(ctx) {
    ctx.save();
    ctx.beginPath();
    ctx.rect(pane.x, pane.y, pane.w, pane.h);
    ctx.clip();
    ctx.globalCompositeOperation = 'lighter';
    ctx.fillStyle = 'rgba(255,255,255,.06)';
    var bands = [60, 320];
    for (var i = 0; i < bands.length; i++) {
      var b = bands[i];
      ctx.beginPath();
      ctx.moveTo(pane.x + b, pane.y + pane.h);
      ctx.lineTo(pane.x + b + 140, pane.y);
      ctx.lineTo(pane.x + b + 225, pane.y);
      ctx.lineTo(pane.x + b + 85, pane.y + pane.h);
      ctx.closePath();
      ctx.fill();
    }
    ctx.restore();
  }

  function drawRoom(ctx) {
    var wall = ctx.createLinearGradient(0, 0, 0, C.canvas.h);
    wall.addColorStop(0, '#3a4453');
    wall.addColorStop(1, '#232b36');
    ctx.fillStyle = wall;
    ctx.fillRect(0, 0, C.canvas.w, C.canvas.h);
  }

  function drawFrame(ctx) {
    var f = C.frame;
    ctx.fillStyle = '#e7e2d6';
    ctx.fillRect(pane.x - f, pane.y - f, pane.w + f * 2, f);
    ctx.fillRect(pane.x - f, pane.y + pane.h, pane.w + f * 2, f);
    ctx.fillRect(pane.x - f, pane.y, f, pane.h);
    ctx.fillRect(pane.x + pane.w, pane.y, f, pane.h);

    ctx.strokeStyle = 'rgba(0,0,0,.28)';
    ctx.lineWidth = 2;
    ctx.strokeRect(pane.x - 1, pane.y - 1, pane.w + 2, pane.h + 2);

    ctx.fillStyle = 'rgba(0,0,0,.12)';
    ctx.fillRect(pane.x - f, pane.y - f, pane.w + f * 2, 4);

    ctx.fillStyle = '#cfc9bb';
    ctx.fillRect(pane.x - f - 14, pane.y + pane.h + f, pane.w + f * 2 + 28, 16);
    ctx.fillStyle = 'rgba(0,0,0,.2)';
    ctx.fillRect(pane.x - f - 14, pane.y + pane.h + f + 16, pane.w + f * 2 + 28, 6);
  }

  function drawBucket(ctx) {
    var x = 92, y = 556;
    ctx.fillStyle = '#2b6e8f';
    ctx.beginPath();
    ctx.moveTo(x - 34, y - 46);
    ctx.lineTo(x + 34, y - 46);
    ctx.lineTo(x + 26, y + 16);
    ctx.lineTo(x - 26, y + 16);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = '#eef4f7';
    ctx.beginPath();
    ctx.ellipse(x, y - 46, 34, 8, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#9aa7b5';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(x, y - 48, 33, Math.PI, 0);
    ctx.stroke();
  }

  WCS.Scene = {
    reset: buildBackdrop,
    drawRoom: drawRoom,
    drawBackdrop: drawBackdrop,
    drawGloss: drawGloss,
    drawFrame: drawFrame,
    drawBucket: drawBucket
  };
})(window.WCS);
