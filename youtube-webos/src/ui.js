/*global navigate*/

// import './spatial-navigation-polyfill.js';
import './navigation-checkbox.js';

import './ui.css';

import { configRead, configWrite } from './config.js';
import { checkboxTools } from './checkboxTools.js';

let lastTabIndex = 0;

export function userScriptStartUI() {
  // We handle key events ourselves.
  window.__spatialNavigation__.keyMode = 'NONE';

  const ARROW_KEY_CODE = { 37: 'left', 38: 'up', 39: 'right', 40: 'down' };

  const uiContainer = document.createElement('div');
  uiContainer.classList.add('ytaf-ui-container');
  uiContainer.style.display = 'none';
  uiContainer.setAttribute('tabindex', 0);
  uiContainer.addEventListener(
    'focus',
    () => {
      console.info('uiContainer focused!');
      const tabIndex = document.querySelector(':focus').tabIndex;
      if (tabIndex !== null) {
        lastTabIndex = tabIndex;
      }
    },
    true
  );
  uiContainer.addEventListener(
    'blur',
    () => console.info('uiContainer blured!'),
    true
  );

  uiContainer.addEventListener(
    'keydown',
    (evt) => {
      console.info(
        'uiContainer key event:',
        evt.type,
        evt.charCode,
        evt.keyCode
      );
      if (evt.charCode !== 404 && evt.charCode !== 172) {
        if (evt.keyCode in ARROW_KEY_CODE) {
          if (uiContainer.offsetParent !== null) {
            navigate(ARROW_KEY_CODE[evt.keyCode]);
          }
        } else if (evt.keyCode === 13 || evt.keyCode === 32) {
          // "OK" button
          checkboxTools.toggleCheck(document.querySelector(':focus').id);
        } else if (evt.keyCode === 27) {
          // Back button
          closeContainer();
        }
        evt.preventDefault();
        evt.stopPropagation();
      }
    },
    true
  );

  const callbackConfig = (configName) => {
    return (newState) => {
      configWrite(configName, newState);
    };
  };

  const divTitle = document.createElement('div');
  divTitle.classList.add('center');
  divTitle.innerHTML = `<h1>webOS YouTube Extended</h1>`;
  uiContainer.appendChild(divTitle);

  uiContainer.appendChild(
    checkboxTools.add(
      '__adblock',
      'Enable AdBlocking',
      configRead('enableAdBlock'),
      callbackConfig('enableAdBlock')
    )
  );
  uiContainer.appendChild(
    checkboxTools.add(
      '__sponsorblock',
      'Enable SponsorBlock',
      configRead('enableSponsorBlock'),
      callbackConfig('enableSponsorBlock')
    )
  );

  const sponsorBlock = document.createElement('div');
  sponsorBlock.classList.add('blockquote');
  sponsorBlock.appendChild(
    checkboxTools.add(
      '__sponsorblock_sponsor',
      'Skip Sponsor Segments',
      configRead('enableSponsorBlockSponsor'),
      callbackConfig('enableSponsorBlockSponsor')
    )
  );
  sponsorBlock.appendChild(
    checkboxTools.add(
      '__sponsorblock_intro',
      'Skip Intro Segments',
      configRead('enableSponsorBlockIntro'),
      callbackConfig('enableSponsorBlockIntro')
    )
  );
  sponsorBlock.appendChild(
    checkboxTools.add(
      '__sponsorblock_outro',
      'Skip Outro Segments',
      configRead('enableSponsorBlockOutro'),
      callbackConfig('enableSponsorBlockOutro')
    )
  );
  sponsorBlock.appendChild(
    checkboxTools.add(
      '__sponsorblock_interaction',
      'Skip Interaction Reminder Segments',
      configRead('enableSponsorBlockInteraction'),
      callbackConfig('enableSponsorBlockInteraction')
    )
  );
  sponsorBlock.appendChild(
    checkboxTools.add(
      '__sponsorblock_selfpromo',
      'Skip Self Promotion Segments',
      configRead('enableSponsorBlockSelfPromo'),
      callbackConfig('enableSponsorBlockSelfPromo')
    )
  );
  sponsorBlock.appendChild(
    checkboxTools.add(
      '__sponsorblock_music_offtopic',
      'Skip Music and Off-topic Segment',
      configRead('enableSponsorBlockMusicOfftopic'),
      callbackConfig('enableSponsorBlockMusicOfftopic')
    )
  );
  uiContainer.appendChild(sponsorBlock);

  const sponsorLink = document.createElement('div');
  sponsorLink.classList.add('small');
  sponsorLink.innerHTML = `Sponsor segments skipping - https://sponsor.ajay.app`;
  uiContainer.appendChild(sponsorLink);

  document.querySelector('body').appendChild(uiContainer);

  let latestFocus = null;
  function openContainer() {
    console.info('Container: Showing & Focusing!');
    uiContainer.style.display = 'block';
    latestFocus = document.querySelector(':focus');
    document.querySelector('[tabindex="' + lastTabIndex + '"]').focus();
    keepContainerFocus();
  }

  function keepContainerFocus() {
    if (uiContainer.offsetParent !== null) {
      if (
        !uiContainer.matches(':focus') &&
        uiContainer.querySelector(':focus') == null
      ) {
        latestFocus = document.querySelector(':focus');
        console.info('Container: Not have focus: Focusing!');
        document.querySelector('[tabindex="' + lastTabIndex + '"]').focus();
      }

      setTimeout(keepContainerFocus, 100);
    }
  }

  function closeContainer() {
    console.info('Container: Hiding!');
    uiContainer.style.display = 'none';
    uiContainer.blur();
    if (latestFocus != null) {
      latestFocus.focus();
    }
  }

  const eventHandler = (evt) => {
    console.info(
      'Key event:',
      evt.type,
      evt.charCode,
      evt.keyCode,
      evt.defaultPrevented
    );
    if (evt.charCode == 404 || evt.charCode == 172) {
      console.info('Taking over!');
      evt.preventDefault();
      evt.stopPropagation();
      if (evt.type === 'keydown') {
        if (uiContainer.style.display === 'none') {
          openContainer();
        } else {
          closeContainer();
        }
      }
      return false;
    } else if (
      evt.type === 'keydown' &&
      evt.charCode == 0 &&
      evt.keyCode == 187
    ) {
      // char '='
      if (uiContainer.style.display === 'none') {
        openContainer();
        evt.preventDefault();
        evt.stopPropagation();
      } else {
        closeContainer();
        evt.preventDefault();
        evt.stopPropagation();
      }
    }
    return true;
  };

  // Red, Green, Yellow, Blue
  // 403, 404, 405, 406
  // ---, 172, 170, 191
  document.addEventListener('keydown', eventHandler, true);
  document.addEventListener('keypress', eventHandler, true);
  document.addEventListener('keyup', eventHandler, true);

  setTimeout(() => {
    showNotification('Press [GREEN] to open YTAF configuration screen');
  }, 2000);
}

export function showNotification(text, time = 3000) {
  console.info('Show notification: ' + text);
  if (!document.querySelector('.ytaf-notification-container')) {
    console.info('Adding notification container');
    const c = document.createElement('div');
    c.classList.add('ytaf-notification-container');
    document.body.appendChild(c);
  }

  const elm = document.createElement('div');
  const elmInner = document.createElement('div');
  elmInner.innerHTML = text;
  elmInner.classList.add('message');
  elmInner.classList.add('message-hidden');
  elm.appendChild(elmInner);
  document.querySelector('.ytaf-notification-container').appendChild(elm);

  setTimeout(() => {
    elmInner.classList.remove('message-hidden');
  }, 100);
  setTimeout(() => {
    elmInner.classList.add('message-hidden');
    setTimeout(() => {
      document.querySelector('.ytaf-notification-container').removeChild(elm);
    }, 1000);
  }, time);
}
