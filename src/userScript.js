pointInRect = function (e, t, n, s, i, c) {
  return e >= n && e <= n + i && t >= s && t <= s + c;
};

getClassElementFromPoint = function (e, t, n) {
  var s = document.getElementById('creator-endscreen');
  if (s && s.classList.contains('visible')) {
    for (var i = s.getElementsByClassName(n), c = 0; c < i.length; c++) {
      var o = i[c];
      if (
        pointInRect(
          e,
          t,
          o.offsetLeft,
          o.offsetTop,
          o.offsetWidth,
          o.offsetHeight
        )
      )
        return o;
    }
    return null;
  }
};

document.addEventListener(
  'click',
  function (e) {
    var t = getClassElementFromPoint(
      e.clientX,
      e.clientY,
      'creator-endscreen-cell'
    );
    if (null != t && !t.classList.contains('hidden')) {
      t.classList.add('focused');
      var n = document.createEvent('HTMLEvents');
      n.initEvent('keyup', !1, !0), (n.keyCode = 13), t.dispatchEvent(n);
    }
  },
  !0
);
