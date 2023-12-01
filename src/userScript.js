import 'whatwg-fetch';
import './domrect-polyfill';
import './adblock.js';
import './sponsorblock.js';
import './ui.js';

import { handleLaunch, waitForChildAdd } from './utils';
import { userScriptStartAdBlock } from './adblock.js';
import { userScriptStartSponsorBlock } from './sponsorblock.js';
import { userScriptStartUI } from './ui.js';

document.addEventListener(
  'webOSRelaunch',
  (evt) => {
    console.info('RELAUNCH:', evt, window.launchParams);
    handleLaunch(evt.detail);
  },
  true
);

// This IIFE is to keep the video element fill the entire window so that screensaver doesn't kick in.
(async () => {
  /** @type {HTMLVideoElement} */
  const video = await waitForChildAdd(
    document.body,
    (node) => node instanceof HTMLVideoElement
  );

  const playerCtrlObs = new MutationObserver(() => {
    const style = video.style;

    const targetWidth = `${window.innerWidth}px`;
    const targetHeight = `${window.innerHeight}px`;
    const targetLeft = '0px';
    // YT uses a negative top to hide player when not in use. Don't know why but let's not affect it.
    const targetTop =
      style.top === `-${window.innerHeight}px` ? style.top : '0px';

    /**
     * Check to see if identical before assignment as some webOS versions will trigger a mutation
     * mutation event even if the assignment effectively does nothing, leading to an infinite loop.
     */
    style.width !== targetWidth && (style.width = targetWidth);
    style.height !== targetHeight && (style.height = targetHeight);
    style.left !== targetLeft && (style.left = targetLeft);
    style.top !== targetTop && (style.top = targetTop);
  });

  playerCtrlObs.observe(video, {
    attributes: true,
    attributeFilter: ['style']
  });
})();

export function startUserScript() {
  userScriptStartAdBlock();
  userScriptStartSponsorBlock();
  userScriptStartUI();
}

(function () {
  startUserScript();
})();
