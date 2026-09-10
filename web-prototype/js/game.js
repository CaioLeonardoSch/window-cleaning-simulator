// Loop principal, entrada do mouse/toque e HUD.
(function (WCS) {
  'use strict';

  var C = WCS.CONFIG;

  function Game(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.grid = new WCS.WindowGrid();
    this.tool = WCS.TOOLS[0];

    this.pointer = { x: C.canvas.w / 2, y: C.canvas.h / 2, inside: false };
    this.pressed = false;
    this.applied = null;

    this.time = 0;
    this.started = false;
    this.won = false;
    this.hudAcc = 0;
    this.last = 0;

    this.el = {
      clean: document.getElementById('bar-clean'),
      cleanVal: document.getElementById('val-clean'),
      residue: document.getElementById('bar-residue'),
      residueVal: document.getElementById('val-residue'),
      timer: document.getElementById('timer'),
      hint: document.getElementById('hint'),
      banner: document.getElementById('banner'),
      bannerTime: document.getElementById('banner-time')
    };

    this.bind();
    this.selectTool(this.tool.id);
  }

  Game.prototype.toCanvas = function (ev) {
    var r = this.canvas.getBoundingClientRect();
    return {
      x: (ev.clientX - r.left) * (C.canvas.w / r.width),
      y: (ev.clientY - r.top) * (C.canvas.h / r.height)
    };
  };

  Game.prototype.bind = function () {
    var self = this;
    var cv = this.canvas;

    cv.addEventListener('pointerdown', function (ev) {
      cv.setPointerCapture(ev.pointerId);
      var p = self.toCanvas(ev);
      self.pointer.x = p.x;
      self.pointer.y = p.y;
      self.pointer.inside = true;
      self.pressed = true;
      self.applied = { x: p.x, y: p.y };
      self.started = true;
      ev.preventDefault();
    });

    cv.addEventListener('pointermove', function (ev) {
      var p = self.toCanvas(ev);
      self.pointer.x = p.x;
      self.pointer.y = p.y;
      self.pointer.inside = true;
    });

    var release = function () {
      self.pressed = false;
      self.applied = null;
    };
    cv.addEventListener('pointerup', release);
    cv.addEventListener('pointercancel', release);
    cv.addEventListener('pointerleave', function () {
      self.pointer.inside = false;
      release();
    });

    window.addEventListener('keydown', function (ev) {
      var k = ev.key.toLowerCase();
      if (k === 'r') { self.reset(); return; }
      for (var i = 0; i < WCS.TOOLS.length; i++) {
        if (WCS.TOOLS[i].key === k) self.selectTool(WCS.TOOLS[i].id);
      }
    });

    var buttons = document.querySelectorAll('.tool');
    for (var b = 0; b < buttons.length; b++) {
      (function (btn) {
        btn.addEventListener('click', function () { self.selectTool(btn.dataset.tool); });
      })(buttons[b]);
    }
    document.getElementById('reset').addEventListener('click', function () { self.reset(); });
  };

  Game.prototype.selectTool = function (id) {
    this.tool = WCS.toolById(id);
    var buttons = document.querySelectorAll('.tool');
    for (var i = 0; i < buttons.length; i++) {
      buttons[i].classList.toggle('active', buttons[i].dataset.tool === this.tool.id);
    }
    this.el.hint.textContent = this.tool.hint;
  };

  Game.prototype.reset = function () {
    this.grid.reset();
    WCS.Scene.reset();
    this.time = 0;
    this.started = false;
    this.won = false;
    this.pressed = false;
    this.applied = null;
    this.el.banner.classList.add('hidden');
  };

  Game.prototype.update = function (dt) {
    if (this.started && !this.won) this.time += dt;

    if (this.pressed && !this.won) {
      var from = this.applied || this.pointer;
      var dx = this.pointer.x - from.x;
      var dy = this.pointer.y - from.y;
      var dist = Math.hypot(dx, dy);
      // Interpola o traco para nao deixar buracos em movimentos rapidos.
      var sub = Math.max(1, Math.ceil(dist / 4));

      for (var i = 1; i <= sub; i++) {
        var t = i / sub;
        this.tool.apply(this.grid, {
          x: from.x + dx * t,
          y: from.y + dy * t,
          dx: dx,
          dy: dy,
          dist: dist,
          speed: dist / Math.max(dt, 1 / 240),
          dt: dt,
          sub: sub
        });
      }
      this.applied = { x: this.pointer.x, y: this.pointer.y };
    }

    this.grid.step(dt);

    this.hudAcc += dt;
    if (this.hudAcc >= 0.1) {
      this.hudAcc = 0;
      this.updateHud();
    }
  };

  Game.prototype.updateHud = function () {
    var s = this.grid.stats();
    var clean = Math.round(s.clean * 100);
    var residue = Math.round(s.residue * 100);

    this.el.clean.style.width = clean + '%';
    this.el.cleanVal.textContent = clean + '%';
    this.el.residue.style.width = Math.min(100, residue * 3) + '%';
    this.el.residueVal.textContent = residue + '%';
    this.el.timer.textContent = this.time.toFixed(1) + 's';

    if (!this.won && this.started && s.grime < C.win.grime && s.residue < C.win.residue) {
      this.won = true;
      this.el.bannerTime.textContent = this.time.toFixed(1) + 's';
      this.el.banner.classList.remove('hidden');
    }
  };

  Game.prototype.render = function (t) {
    var ctx = this.ctx;
    ctx.clearRect(0, 0, C.canvas.w, C.canvas.h);

    WCS.Scene.drawRoom(ctx);
    WCS.Scene.drawBackdrop(ctx);
    this.grid.render(ctx);
    WCS.Scene.drawGloss(ctx);
    WCS.Scene.drawFrame(ctx);
    WCS.Scene.drawBucket(ctx);

    var hand = this.pointer.inside ? this.pointer : null;
    WCS.Character.draw(ctx, hand, this.tool, this.pressed, t);
  };

  Game.prototype.start = function () {
    var self = this;
    this.last = performance.now();
    this.updateHud();

    function frame(now) {
      var dt = Math.min(0.05, (now - self.last) / 1000);
      self.last = now;
      self.update(dt);
      self.render(now / 1000);
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  };

  WCS.Game = Game;
})(window.WCS);
