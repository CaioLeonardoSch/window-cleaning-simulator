// Bootstrap.
window.addEventListener('load', function () {
  var game = new WCS.Game(document.getElementById('game'));
  window.game = game;
  game.start();
});
