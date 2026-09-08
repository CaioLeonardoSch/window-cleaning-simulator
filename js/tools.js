// Ferramentas: cada uma altera o grid e sabe se desenhar na mão do personagem.
// apply(grid, s) recebe um passo do traço:
//   s = { x, y, dx, dy, dist, speed, dt, sub }
(function (WCS) {
  'use strict';

  var clamp01 = WCS.clamp01;

  var spray = {
    id: 'spray',
    label: 'Borrifador',
    key: '1',
    radius: 54,
    hint: 'Borrife para molhar o vidro — esponja seca não faz espuma.',

    apply: function (grid, s) {
      var amount = (2.2 * s.dt) / s.sub;
      grid.eachInCircle(s.x, s.y, this.radius, function (i, f) {
        grid.water[i] = clamp01(grid.water[i] + amount * f);
        grid.grime[i] = clamp01(grid.grime[i] - amount * 0.06 * f);
      });
    },

    draw: function (ctx, active) {
      if (active) {
        ctx.fillStyle = 'rgba(180, 214, 240, .35)';
        for (var i = 0; i < 14; i++) {
          var a = (Math.random() - 0.5) * 0.9;
          var d = 12 + Math.random() * 48;
          ctx.beginPath();
          ctx.arc(Math.cos(a) * d, Math.sin(a) * d, 1 + Math.random() * 2, 0, Math.PI * 2);
          ctx.fill();
        }
      }
      ctx.fillStyle = '#2f7fb8';
      ctx.beginPath();
      ctx.roundRect(-46, -16, 34, 46, 5);
      ctx.fill();
      ctx.fillStyle = '#cfe6f5';
      ctx.fillRect(-40, -6, 22, 18);
      ctx.fillStyle = '#37556b';
      ctx.beginPath();
      ctx.moveTo(-16, -14);
      ctx.lineTo(2, -10);
      ctx.lineTo(2, -3);
      ctx.lineTo(-16, -2);
      ctx.closePath();
      ctx.fill();
      ctx.fillRect(-22, -22, 14, 10);
    }
  };

  var sponge = {
    id: 'sponge',
    label: 'Esponja com sabão',
    key: '2',
    radius: 34,
    hint: 'Esfregue em movimento sobre o vidro molhado para soltar a sujeira.',

    apply: function (grid, s) {
      if (s.dist < 0.6) return;
      grid.eachInCircle(s.x, s.y, this.radius, function (i, f) {
        var wet = clamp01(grid.water[i] / 0.25);
        // A esponja solta a sujeira, mas deixa um vau de espuma: so o rodo tira o resto.
        if (grid.grime[i] > 0.12) grid.grime[i] = Math.max(0.12, grid.grime[i] - 0.07 * wet * f);
        grid.soap[i] = clamp01(grid.soap[i] + 0.07 * wet * f);
        grid.water[i] = clamp01(grid.water[i] - 0.02 * f);
      });
    },

    draw: function (ctx) {
      ctx.fillStyle = '#e8c246';
      ctx.beginPath();
      ctx.roundRect(-30, -22, 54, 42, 8);
      ctx.fill();
      ctx.fillStyle = '#3f9463';
      ctx.beginPath();
      ctx.roundRect(-30, -22, 54, 14, 7);
      ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,.55)';
      for (var i = 0; i < 5; i++) {
        ctx.beginPath();
        ctx.arc(-22 + i * 12, 6 + (i % 2) * 7, 3, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  };

  var squeegee = {
    id: 'squeegee',
    label: 'Rodo de mão',
    key: '3',
    blade: 84,
    hint: 'Puxe em linha reta para remover espuma e água — no vidro seco ele borra.',

    apply: function (grid, s) {
      var vertical = Math.abs(s.dx) >= Math.abs(s.dy);
      var hw = vertical ? 8 : this.blade;
      var hh = vertical ? this.blade : 8;

      grid.eachInRect(s.x, s.y, hw, hh, function (i, f) {
        var lube = clamp01(grid.soap[i] * 2.6 + grid.water[i] * 1.2);
        grid.grime[i] = clamp01(grid.grime[i] * (1 - 0.95 * lube * f));
        grid.soap[i] = clamp01(grid.soap[i] * (1 - 0.92 * f));
        grid.water[i] = clamp01(grid.water[i] * (1 - 0.88 * f));
        if (lube < 0.08 && grid.grime[i] > 0.05) {
          grid.grime[i] = Math.min(0.75, grid.grime[i] + 0.008 * f);
        }
      });
    },

    draw: function (ctx) {
      ctx.fillStyle = '#22303c';
      ctx.beginPath();
      ctx.roundRect(-42, -9, 40, 18, 6);
      ctx.fill();
      ctx.fillStyle = '#9aa7b5';
      ctx.fillRect(-6, -6, 12, 12);
      ctx.fillStyle = '#c8d3dd';
      ctx.fillRect(4, -this.blade, 8, this.blade * 2);
      ctx.fillStyle = '#12191f';
      ctx.fillRect(12, -this.blade, 4, this.blade * 2);
    }
  };

  WCS.TOOLS = [spray, sponge, squeegee];
  WCS.toolById = function (id) {
    for (var i = 0; i < WCS.TOOLS.length; i++) if (WCS.TOOLS[i].id === id) return WCS.TOOLS[i];
    return WCS.TOOLS[0];
  };
})(window.WCS);
