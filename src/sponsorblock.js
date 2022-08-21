import * as sha256 from 'tiny-sha256';
import { configRead } from './config';
import { showNotification } from './ui';

export function userScriptStartSponsorBlock() {}

// Copied from https://github.com/ajayyy/SponsorBlock/blob/9392d16617d2d48abb6125c00e2ff6042cb7bebe/src/config.ts#L179-L233
const barTypes = {
  sponsor: {
    color: '#00d400',
    opacity: '0.7',
    name: 'sponsored segment'
  },
  intro: {
    color: '#00ffff',
    opacity: '0.7',
    name: 'intro'
  },
  outro: {
    color: '#0202ed',
    opacity: '0.7',
    name: 'outro'
  },
  interaction: {
    color: '#cc00ff',
    opacity: '0.7',
    name: 'interaction reminder'
  },
  selfpromo: {
    color: '#ffff00',
    opacity: '0.7',
    name: 'self-promotion'
  },
  music_offtopic: {
    color: '#ff9900',
    opacity: '0.7',
    name: 'non-music part'
  }
};

const sponsorblockAPI = 'https://sponsorblock.inf.re/api';

class SponsorBlockHandler {
  video = null;
  active = true;

  attachVideoTimeout = null;
  nextSkipTimeout = null;
  slicer = null;
  slicerKeeperInterval = null;

  segmentsoverlay = null;
  scheduleSkipHandler = null;
  durationChangeHandler = null;
  segments = null;
  skippableCategories = [];

  constructor(videoID) {
    this.videoID = videoID;
  }

  fetchSegements(url, callback) {
    // url = "https://sponsorblock.inf.re/api/skipSegments/59e7?categories=%5B%22sponsor%22%2C%22intro%22%2C%22outro%22%2C%22interaction%22%2C%22selfpromo%22%2C%22music_offtopic%22%5D";
    const xhr = new XMLHttpRequest();
    xhr.onreadystatechange = () => {
      if (xhr.readyState == 1) {
        console.log('Sponsor:', this.videoID, 'xhr state:', '...Opened');
      } else if (xhr.readyState == 2) {
        console.log(
          'Sponsor:',
          this.videoID,
          'xhr state:',
          '...HeadersReceived'
        );
      } else if (xhr.readyState == 3) {
        console.log('Sponsor:', this.videoID, 'xhr state:', '...Loading');
      } else if (xhr.readyState == 4) {
        console.log('Sponsor:', this.videoID, 'xhr state:', '...Loaded.');
      }
    };
    xhr.onload = () => {
      console.log(
        'Sponsor:',
        this.videoID,
        'xhr response status:',
        xhr.status,
        xhr
      );
      if (xhr.status >= 200 && xhr.status < 300) {
        // parse JSON
        const response = JSON.parse(xhr.responseText);
        console.log('Sponsor:', this.videoID, 'xhr response: success');
        // console.log(response);
        callback(response);
      }
    };
    xhr.open('GET', url);
    xhr.send();
  }

  async init() {
    const videoHash = sha256(this.videoID).substring(0, 4);
    const categories = [
      'sponsor',
      'intro',
      'outro',
      'interaction',
      'selfpromo',
      'music_offtopic'
    ];
    const url = `${sponsorblockAPI}/skipSegments/${videoHash}?categories=${encodeURIComponent(
      JSON.stringify(categories)
    )}`;
    console.info('Sponsor:', this.videoID, 'going to make request', url);

    try {
      this.fetchSegements(url, (results) => {
        const result = results.find((v) => v.videoID === this.videoID);
        console.info('Sponsor:', this.videoID, 'Got it:', result);

        if (!result || !result.segments || !result.segments.length) {
          console.info('Sponsor:', this.videoID, 'No segments found.');
          return;
        }

        this.segments = result.segments;
        this.skippableCategories = this.getSkippableCategories();

        this.scheduleSkipHandler = () => this.scheduleSkip();
        this.durationChangeHandler = () => this.buildOverlay();

        this.attachVideo();
        this.buildOverlay();
      });
    } catch (err) {
      console.warn('Sponsor:', this.videoID, 'fetch error:', err);
    }
  }

  getSkippableCategories() {
    const skippableCategories = [];
    if (configRead('enableSponsorBlockSponsor')) {
      skippableCategories.push('sponsor');
    }
    if (configRead('enableSponsorBlockIntro')) {
      skippableCategories.push('intro');
    }
    if (configRead('enableSponsorBlockOutro')) {
      skippableCategories.push('outro');
    }
    if (configRead('enableSponsorBlockInteraction')) {
      skippableCategories.push('interaction');
    }
    if (configRead('enableSponsorBlockSelfPromo')) {
      skippableCategories.push('selfpromo');
    }
    if (configRead('enableSponsorBlockMusicOfftopic')) {
      skippableCategories.push('music_offtopic');
    }
    return skippableCategories;
  }

  attachVideo() {
    clearTimeout(this.attachVideoTimeout);
    this.attachVideoTimeout = null;

    this.video = document.querySelector('video');
    if (!this.video) {
      console.info('Sponsor:', this.videoID, 'No video yet...');
      this.attachVideoTimeout = setTimeout(() => this.attachVideo(), 100);
      return;
    }

    console.info('Sponsor:', this.videoID, 'Video found, binding...');

    this.video.addEventListener('play', this.scheduleSkipHandler);
    this.video.addEventListener('pause', this.scheduleSkipHandler);
    this.video.addEventListener('timeupdate', this.scheduleSkipHandler);
    this.video.addEventListener('durationchange', this.durationChangeHandler);
  }

  buildOverlay() {
    console.info('Sponsor:', this.videoID, 'Build overlay');
    if (this.segmentsoverlay) {
      console.info('Sponsor:', this.videoID, 'Overlay already built');
      return;
    }

    if (!this.video || !this.video.duration) {
      console.info('Sponsor:', this.videoID, 'No video duration yet');
      return;
    }

    const videoDuration = this.video.duration;
    console.info('Sponsor:', this.videoID, 'Video Duration', videoDuration);

    this.segmentsoverlay = document.createElement('div');
    this.segmentsoverlay.classList.add('sponsorblock-slider');
    this.segments.forEach((segment) => {
      const [start, end] = segment.segment;
      const barType = barTypes[segment.category] || {
        color: 'blue',
        opacity: 0.7
      };
      const transform = `translateX(${
        (start / videoDuration) * 100.0
      }%) scaleX(${(end - start) / videoDuration})`;
      const elm = document.createElement('div');
      elm.classList.add('ytlr-progress-bar__played');
      elm.style['background'] = barType.color;
      elm.style['opacity'] = barType.opacity;
      elm.style['-webkit-transform'] = transform;
      elm.style['transform'] = transform;
      console.info(
        'Sponsor:',
        this.videoID,
        'Generated element',
        elm,
        'from',
        segment,
        transform
      );
      this.segmentsoverlay.appendChild(elm);
    });

    try {
      console.info('Sponsor:', this.videoID, 'startSlicerKeeper');
      this.startSlicerKeeper();
      console.info('Sponsor:', this.videoID, 'startSlicerKeeper Done');
    } catch (err) {
      console.warn('Sponsor:', this.videoID, 'error', err);
    }
  }

  stopSlicerKeeper() {
    if (this.slicerKeeperInterval) {
      clearInterval(this.slicerKeeperInterval);
      this.slicerKeeperInterval = null;
    }
  }

  startSlicerKeeper() {
    this.stopSlicerKeeper();

    if (!this.active) {
      return;
    }
    this.slicerKeeperInterval = setInterval(() => {
      try {
        if (this.segmentsoverlay.offsetParent === null) {
          const slicer = this.getCurrentSlicer();
          if (slicer) {
            slicer.appendChild(this.segmentsoverlay);
          }
          // console.info("Sponsor:", this.videoID, 'Bringing back segments overlay');
        }
      } catch (err) {
        console.warn('Sponsor:', this.videoID, 'error', err);
      }
    }, 100);
  }

  getCurrentSlicer() {
    let slicer = document.querySelector(
      '.ytlr-multi-markers-player-bar-renderer'
    );
    if (!slicer) {
      slicer = document.querySelector('.ytlr-progress-bar__slider');
    }
    return slicer;
  }

  scheduleSkip() {
    clearTimeout(this.nextSkipTimeout);
    this.nextSkipTimeout = null;

    if (!this.active) {
      console.info('Sponsor:', this.videoID, 'No longer active, ignoring...');
      return;
    }

    if (this.video.paused) {
      console.info('Sponsor:', this.videoID, 'Currently paused, ignoring...');
      return;
    }

    // Sometimes timeupdate event (that calls scheduleSkip) gets fired right before
    // already scheduled skip routine below. Let's just look back a little bit
    // and, in worst case, perform a skip at negative interval (immediately)...
    const nextSegments = this.segments.filter(
      (seg) =>
        seg.segment[0] > this.video.currentTime - 0.3 &&
        seg.segment[1] > this.video.currentTime - 0.3
    );
    nextSegments.sort((s1, s2) => s1.segment[0] - s2.segment[0]);

    if (!nextSegments.length) {
      // console.info("Sponsor:", this.videoID, 'No more segments');
      return;
    }

    const [segment] = nextSegments;
    const [start, end] = segment.segment;
    // console.info(
    //   "Sponsor:",
    //   this.videoID,
    //   'Scheduling skip of',
    //   segment,
    //   'in',
    //   start - this.video.currentTime
    // );

    this.nextSkipTimeout = setTimeout(() => {
      if (this.video.paused) {
        console.info('Sponsor:', this.videoID, 'Currently paused, ignoring...');
        return;
      }
      if (!this.skippableCategories.includes(segment.category)) {
        console.info(
          'Sponsor:',
          this.videoID,
          'Segment',
          segment.category,
          'is not skippable, ignoring...'
        );
        return;
      }

      const skipName = barTypes[segment.category]?.name || segment.category;
      console.info('Sponsor:', this.videoID, 'Skipping', segment);
      showNotification(`Skipping ${skipName}`);
      this.video.currentTime = end;
      this.scheduleSkip();
    }, (start - this.video.currentTime) * 1000);
  }

  destroy() {
    console.info('Sponsor:', this.videoID, 'Destroying');

    this.active = false;

    if (this.nextSkipTimeout) {
      clearTimeout(this.nextSkipTimeout);
      this.nextSkipTimeout = null;
    }

    if (this.attachVideoTimeout) {
      clearTimeout(this.attachVideoTimeout);
      this.attachVideoTimeout = null;
    }

    this.stopSlicerKeeper();

    if (this.video) {
      this.video.removeEventListener('play', this.scheduleSkipHandler);
      this.video.removeEventListener('pause', this.scheduleSkipHandler);
      this.video.removeEventListener('timeupdate', this.scheduleSkipHandler);
      this.video.removeEventListener(
        'durationchange',
        this.durationChangeHandler
      );
    }

    if (this.segmentsoverlay && this.segmentsoverlay.parentElement) {
      this.segmentsoverlay.parentElement.removeChild(this.segmentsoverlay);
    }
    this.segmentsoverlay = null;

    console.info('Sponsor:', this.videoID, 'Destroyed');
  }
}

// When this global variable was declared using let and two consecutive hashchange
// events were fired (due to bubbling? not sure...) the second call handled below
// would not see the value change from first call, and that would cause multiple
// SponsorBlockHandler initializations... This has been noticed on Chromium 38.
// This either reveals some bug in chromium/webpack/babel scope handling, or
// shows my lack of understanding of javascript. (or both)
window.sponsorblock = null;

function hashChange() {
  const newURL = new URL(location.hash.substring(1), location.href);
  const videoID = newURL.searchParams.get('v');
  const needsReload =
    videoID &&
    (!window.sponsorblock ||
      window.sponsorblock.videoID != videoID ||
      window.sponsorblock.segmentsoverlay == null);

  console.info(
    'Sponsor:',
    videoID,
    'hashchange',
    window.sponsorblock,
    window.sponsorblock ? window.sponsorblock.videoID : null,
    needsReload
  );

  if (!videoID) {
    return;
  }

  if (needsReload) {
    if (window.sponsorblock) {
      try {
        window.sponsorblock.destroy();
      } catch (err) {
        console.warn('window.sponsorblock.destroy() failed!', err);
      }
      window.sponsorblock = null;
    }

    if (configRead('enableSponsorBlock')) {
      console.info('Sponsor', videoID, 'initialize');
      window.sponsorblock = new SponsorBlockHandler(videoID);
      window.sponsorblock.init();
    } else {
      console.info('SponsorBlock disabled, not loading');
    }
  }
}

window.addEventListener('hashchange', hashChange, false);

hashChange();
