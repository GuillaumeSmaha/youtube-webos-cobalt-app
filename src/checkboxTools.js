import './checkboxTools.css';

let checkboxTabIndex = 1;

let callbacks = {};

function add(name, label, checked = false, callback = null) {
  /*
  <div class="toggler-wrapper" for="adblock">
    <div type="checkbox" tabindex="1" checked="checked">
      <div class="toggler-slider">
        <div class="toggler-knob"></div>
      </div>
    </div>
    <div class="desc">Enable AdBlocking</div>
  </div>
  */

  const wrapper = document.createElement('div');
  wrapper.classList.add('toggler-wrapper');

  const sliderDiv = document.createElement('div');
  sliderDiv.classList.add('toggler-slider');
  const knobDiv = document.createElement('div');
  knobDiv.classList.add('toggler-knob');
  sliderDiv.appendChild(knobDiv);

  const checkboxSliderDiv = document.createElement('div');
  checkboxSliderDiv.setAttribute('id', name);
  checkboxSliderDiv.setAttribute('type', 'checkbox');
  checkboxSliderDiv.setAttribute('tabindex', checkboxTabIndex);
  checkboxSliderDiv.appendChild(sliderDiv);

  const divabel = document.createElement('div');
  divabel.classList.add('desc');
  divabel.innerHTML = label;

  wrapper.appendChild(checkboxSliderDiv);
  wrapper.appendChild(divabel);

  if (checked) {
    checkboxSliderDiv.setAttribute('checked', 'checked');
  }

  callbacks[checkboxTabIndex] = (newState) => {
    if (callback != null) {
      callback(newState);
    }
  };

  const cb = (evt) => {
    const newState = toggleCheck(name);
  };

  wrapper.addEventListener(
    'click',
    (evt) => {
      cb(evt);
    },
    true
  );

  checkboxTabIndex += 1;

  return wrapper;
}

function isChecked(name) {
  if (!name) {
    return;
  }
  const sliceDiv = document.querySelector('#' + name);
  return sliceDiv.hasAttribute('checked');
}

function toggleCheck(name) {
  if (!name) {
    return;
  }
  if (isChecked(name)) {
    uncheck(name);
    return false;
  } else {
    check(name);
    return true;
  }
}

function check(name) {
  if (!name) {
    return;
  }
  const sliceDiv = document.querySelector('#' + name);
  sliceDiv.setAttribute('checked', 'checked');
  callbacks[sliceDiv.tabIndex](true);
}

function uncheck(name) {
  if (!name) {
    return;
  }
  const sliceDiv = document.querySelector('#' + name);
  sliceDiv.removeAttribute('checked');
  callbacks[sliceDiv.tabIndex](false);
}

function remove(name) {
  if (!name) {
    return;
  }
  const sliceDiv = document.querySelector('#' + name);
  sliceDiv.removeEventListener('click', callbacks[sliceDiv.tabIndex]);
}

export const checkboxTools = {
  add: add,
  isChecked: isChecked,
  toggleCheck: toggleCheck,
  check: check,
  uncheck: uncheck,
  remove: remove
};
