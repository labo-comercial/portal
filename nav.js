/* ============================================================================
   Portal 4housing — nav.js
   Botón flotante de navegación entre módulos. Cada app lo incluye con:
     <script src="/portal/nav.js" defer></script>
   Links relativos al origen: sobrevive a un rename de la organización GitHub.
   No depende de Supabase ni de sesión: son links estáticos (v1).
   ============================================================================ */
(function () {
  'use strict';

  var MODULOS = [
    { path: '/portal/',               nombre: 'Portal' },
    { path: '/4housing-comercial/',   nombre: 'Comercial 4housing' },
    { path: '/labo-comercial/',       nombre: 'Comercial LABO' },
    { path: '/diseno-4housing/',      nombre: 'Diseño' },
    { path: '/planificacion-taller/', nombre: 'Planificación' }
  ];

  // No mostrar el link de la app en la que ya estamos
  var actual = window.location.pathname;
  var items = MODULOS.filter(function (m) { return actual.indexOf(m.path) !== 0; });
  if (items.length === MODULOS.length) {
    // path no reconocido (ej. dominio propio a futuro): mostrar todo igual
    items = MODULOS;
  }

  var css = [
    '#fh-nav{position:fixed;bottom:18px;right:18px;z-index:99999;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;}',
    '#fh-nav-btn{width:46px;height:46px;border-radius:50%;border:1px solid rgba(0,0,0,.15);background:#235a8f;color:#fff;cursor:pointer;box-shadow:0 2px 10px rgba(0,0,0,.25);display:flex;align-items:center;justify-content:center;padding:0;}',
    '#fh-nav-btn:hover{filter:brightness(1.1);}',
    '#fh-nav-btn:focus-visible{outline:2px solid #235a8f;outline-offset:2px;}',
    '#fh-nav-menu{position:absolute;bottom:56px;right:0;background:#fff;color:#20262e;border:1px solid #d8dce0;border-radius:10px;box-shadow:0 6px 24px rgba(0,0,0,.18);min-width:210px;padding:6px;display:none;}',
    '#fh-nav.open #fh-nav-menu{display:block;}',
    '#fh-nav-menu a{display:block;padding:9px 12px;border-radius:7px;color:inherit;text-decoration:none;font-size:14px;white-space:nowrap;}',
    '#fh-nav-menu a:hover{background:#e6eef6;}',
    '#fh-nav-menu .fh-nav-titulo{font-size:10.5px;letter-spacing:.08em;text-transform:uppercase;color:#8b939c;padding:6px 12px 4px;}',
    '@media (prefers-color-scheme: dark){#fh-nav-menu{background:#1b2128;color:#e8ebee;border-color:#2c343d;}#fh-nav-menu a:hover{background:#1e3349;}}'
  ].join('');

  var style = document.createElement('style');
  style.textContent = css;

  var root = document.createElement('div');
  root.id = 'fh-nav';

  var btn = document.createElement('button');
  btn.id = 'fh-nav-btn';
  btn.type = 'button';
  btn.title = 'Ir a otro módulo 4housing';
  btn.setAttribute('aria-label', 'Ir a otro módulo 4housing');
  btn.setAttribute('aria-expanded', 'false');
  btn.innerHTML = '<svg width="18" height="18" viewBox="0 0 18 18" fill="currentColor" aria-hidden="true">' +
    '<rect x="1" y="1" width="7" height="7" rx="1.5"/><rect x="10" y="1" width="7" height="7" rx="1.5"/>' +
    '<rect x="1" y="10" width="7" height="7" rx="1.5"/><rect x="10" y="10" width="7" height="7" rx="1.5"/></svg>';

  var menu = document.createElement('div');
  menu.id = 'fh-nav-menu';
  menu.innerHTML = '<div class="fh-nav-titulo">4housing</div>' + items.map(function (m) {
    return '<a href="' + m.path + '">' + m.nombre + '</a>';
  }).join('');

  btn.addEventListener('click', function (e) {
    e.stopPropagation();
    var abierto = root.classList.toggle('open');
    btn.setAttribute('aria-expanded', abierto ? 'true' : 'false');
  });
  document.addEventListener('click', function () {
    root.classList.remove('open');
    btn.setAttribute('aria-expanded', 'false');
  });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') {
      root.classList.remove('open');
      btn.setAttribute('aria-expanded', 'false');
    }
  });

  root.appendChild(btn);
  root.appendChild(menu);

  function montar() {
    document.head.appendChild(style);
    document.body.appendChild(root);
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', montar);
  } else {
    montar();
  }
})();
