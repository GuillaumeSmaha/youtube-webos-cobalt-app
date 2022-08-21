(function () {
  // The polyfill must not be executed, if it's already enabled via browser engine or browser extensions.
  if ('navigate' in window) {
    console.log('No need for navigate polyfill');
    return;
  }
  console.log('Set navigate polyfill');

  function navigateCheckbox(dir) {
    // 1
    let searchOrigin = document.activeElement;
    if (!searchOrigin) {
      searchOrigin = document.querySelector(':focus');
    }
    if (!searchOrigin) {
      searchOrigin = document.querySelector('[tabindex="0"]');
    }

    let tabIndex = searchOrigin.tabIndex;
    let nextElement = document.querySelector('[tabindex="0"]');
    if (tabIndex !== null) {
      if (dir == 'down' || dir == 'right') {
        tabIndex += 1;
        const e = document.querySelector('[tabindex="' + tabIndex + '"]');
        if (e !== null) {
          nextElement = e;
        }
      } else if (dir == 'up' || dir == 'left') {
        tabIndex -= 1;
        if (tabIndex >= 0) {
          const e = document.querySelector('[tabindex="' + tabIndex + '"]');
          if (e !== null) {
            nextElement = e;
          }
        } else {
          let elmts = document.querySelectorAll('[tabindex]');
          let v = 0;
          for (let i = 0; i < elmts.length; ++i) {
            if (elmts[i].tabIndex > v) {
              v = elmts[i].tabIndex;
              tabIndex = v;
              nextElement = elmts[i];
            }
          }
        }
      }
    }

    console.log('Move to tabIndex: ' + tabIndex);
    nextElement.focus();
  }

  window.navigate = navigateCheckbox;
  window.__spatialNavigation__ = {};
})();
