// Personagem estático, visto de costas, de frente para a janela.
// Só o braço se move: ele acompanha o ponteiro segurando a ferramenta.
(function (WCS) {
  'use strict';

  var SHOULDER = { x: 566, y: 548 };
  var HEAD = { x: 470, y: 486, r: 48 };
  var SKIN = '#c98f68';
  var SHIRT = '#3f6f8f';
  var SHIRT_DARK = '#33586f';

  function drawBody(ctx, t) {
    var bob = Math.sin(t * 1.6) * 2;

    ctx.save();
    ctx.translate(0, bob);

    // Sombra sutil na parede, atras dos ombros.
    ctx.fillStyle = 'rgba(0,0,0,.10)';
    ctx.beginPath();
    ctx.ellipse(HEAD.x, 620, 118, 22, 0, 0, Math.PI * 2);
    ctx.fill();

    // Tronco.
    ctx.fillStyle = SHIRT;
    ctx.beginPath();
    ctx.moveTo(HEAD.x - 108, 620);
    ctx.lineTo(HEAD.x - 96, 556);
    ctx.quadraticCurveTo(HEAD.x - 88, 534, HEAD.x - 34, 528);
    ctx.lineTo(HEAD.x + 34, 528);
    ctx.quadraticCurveTo(HEAD.x + 88, 534, HEAD.x + 96, 556);
    ctx.lineTo(HEAD.x + 108, 620);
    ctx.closePath();
    ctx.fill();

    // Gola e vinco das costas.
    ctx.fillStyle = SHIRT_DARK;
    ctx.beginPath();
    ctx.ellipse(HEAD.x, 530, 36, 11, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = 'rgba(0,0,0,.12)';
    ctx.lineWidth = 6;
    ctx.beginPath();
    ctx.moveTo(HEAD.x, 546);
    ctx.lineTo(HEAD.x, 612);
    ctx.stroke();

    // Pescoco e cabeca (nuca).
    ctx.fillStyle = SKIN;
    ctx.fillRect(HEAD.x - 17, HEAD.y + 20, 34, 26);
    ctx.beginPath();
    ctx.arc(HEAD.x, HEAD.y, HEAD.r, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#2f2620';
    ctx.beginPath();
    ctx.arc(HEAD.x, HEAD.y - 4, HEAD.r, Math.PI * 0.08, Math.PI * 0.92, true);
    ctx.fill();
    ctx.beginPath();
    ctx.ellipse(HEAD.x, HEAD.y + 6, HEAD.r * 0.92, HEAD.r * 0.7, 0, 0, Math.PI * 2);
    ctx.fill();

    // Orelhas.
    ctx.fillStyle = SKIN;
    ctx.beginPath();
    ctx.ellipse(HEAD.x - HEAD.r + 3, HEAD.y + 6, 7, 11, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.ellipse(HEAD.x + HEAD.r - 3, HEAD.y + 6, 7, 11, 0, 0, Math.PI * 2);
    ctx.fill();

    // Braco parado (esquerdo).
    ctx.strokeStyle = SHIRT;
    ctx.lineWidth = 26;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(HEAD.x - 88, 556);
    ctx.quadraticCurveTo(HEAD.x - 116, 594, HEAD.x - 104, 624);
    ctx.stroke();

    ctx.restore();
    return bob;
  }

  // Braco ativo: ombro -> cotovelo (curva) -> mao no ponteiro.
  function drawArm(ctx, hand, bob) {
    var sx = SHOULDER.x, sy = SHOULDER.y + bob;
    var dx = hand.x - sx, dy = hand.y - sy;
    var dist = Math.hypot(dx, dy) || 1;
    var bend = Math.max(0, 1 - dist / 260) * 70 + 18;
    var mx = sx + dx * 0.5, my = sy + dy * 0.5;
    var ex = mx + (dy / dist) * bend;
    var ey = my - (dx / dist) * bend;

    ctx.lineCap = 'round';
    ctx.strokeStyle = SKIN;
    ctx.lineWidth = 21;
    ctx.beginPath();
    ctx.moveTo(sx, sy);
    ctx.quadraticCurveTo(ex, ey, hand.x, hand.y);
    ctx.stroke();

    // Manga.
    ctx.strokeStyle = SHIRT;
    ctx.lineWidth = 27;
    ctx.beginPath();
    ctx.moveTo(sx, sy);
    ctx.lineTo(sx + (ex - sx) * 0.45, sy + (ey - sy) * 0.45);
    ctx.stroke();

    return Math.atan2(hand.y - ey, hand.x - ex);
  }

  function drawHand(ctx, hand) {
    ctx.fillStyle = SKIN;
    ctx.beginPath();
    ctx.arc(hand.x, hand.y, 13, 0, Math.PI * 2);
    ctx.fill();
  }

  // Desenha corpo + braco + ferramenta na mao.
  function draw(ctx, hand, tool, active, t) {
    var bob = drawBody(ctx, t);
    if (!hand) return;

    var angle = drawArm(ctx, hand, bob);

    ctx.save();
    ctx.translate(hand.x, hand.y);
    ctx.rotate(angle);
    tool.draw(ctx, active);
    ctx.restore();

    drawHand(ctx, hand);
  }

  WCS.Character = { draw: draw, SHOULDER: SHOULDER };
})(window.WCS);
