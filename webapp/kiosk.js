// Скрипт надстроек сенсорного киоска (работает в тандеме с официальным app.js)
(function () {
  'use strict';

  let activeInput = null;
  let idleTimer = null;

  // Элементы
  const bellsBtn = document.getElementById('bellsBtn');
  const bellsModal = document.getElementById('bellsModal');
  const closeBellsBtn = document.getElementById('closeBellsBtn');

  const appQrBtn = document.getElementById('appQrBtn');
  const appQrModal = document.getElementById('appQrModal');
  const closeAppQrBtn = document.getElementById('closeAppQrBtn');

  const kbDrawer = document.getElementById('touchKeyboardDrawer');
  const kbHideBtn = document.getElementById('kbHideBtn');
  const kbTitle = document.getElementById('kbTitle');
  const kBackspace = document.getElementById('kBackspace');
  const kSpace = document.getElementById('kSpace');
  const kClear = document.getElementById('kClear');

  const groupSearchInput = document.getElementById('groupSearchInput');
  const teacherSearchInput = document.getElementById('teacherSearchInput');

  // Управление модалкой звонков
  if (bellsBtn && bellsModal) {
    bellsBtn.addEventListener('click', () => {
      resetIdleTimer();
      bellsModal.classList.remove('hidden');
    });
  }

  if (closeBellsBtn && bellsModal) {
    closeBellsBtn.addEventListener('click', () => {
      bellsModal.classList.add('hidden');
    });
  }

  // Управление модалкой QR-кода
  if (appQrBtn && appQrModal) {
    appQrBtn.addEventListener('click', () => {
      resetIdleTimer();
      appQrModal.classList.remove('hidden');
    });
  }

  if (closeAppQrBtn && appQrModal) {
    closeAppQrBtn.addEventListener('click', () => {
      appQrModal.classList.add('hidden');
    });
  }

  // Экранная сенсорная клавиатура
  function showKeyboard(inputEl, label) {
    activeInput = inputEl;
    if (kbTitle) kbTitle.textContent = label || 'Ввод текста';
    if (kbDrawer) kbDrawer.classList.remove('hidden');
  }

  function hideKeyboard() {
    activeInput = null;
    if (kbDrawer) kbDrawer.classList.add('hidden');
  }

  if (kbHideBtn) kbHideBtn.addEventListener('click', hideKeyboard);

  if (groupSearchInput) {
    groupSearchInput.addEventListener('click', () => {
      showKeyboard(groupSearchInput, 'Поиск учебной группы');
    });
  }

  if (teacherSearchInput) {
    teacherSearchInput.addEventListener('click', () => {
      showKeyboard(teacherSearchInput, 'Поиск преподавателя');
    });
  }

  // Обработка клавиш букв и цифр
  document.querySelectorAll('.k-btn[data-char]').forEach(btn => {
    btn.addEventListener('click', () => {
      resetIdleTimer();
      if (!activeInput) return;
      const ch = btn.getAttribute('data-char');
      activeInput.value += ch;
      activeInput.dispatchEvent(new Event('input', { bubbles: true }));
    });
  });

  if (kBackspace) {
    kBackspace.addEventListener('click', () => {
      resetIdleTimer();
      if (!activeInput) return;
      activeInput.value = activeInput.value.slice(0, -1);
      activeInput.dispatchEvent(new Event('input', { bubbles: true }));
    });
  }

  if (kSpace) {
    kSpace.addEventListener('click', () => {
      resetIdleTimer();
      if (!activeInput) return;
      activeInput.value += ' ';
      activeInput.dispatchEvent(new Event('input', { bubbles: true }));
    });
  }

  if (kClear) {
    kClear.addEventListener('click', () => {
      resetIdleTimer();
      if (!activeInput) return;
      activeInput.value = '';
      activeInput.dispatchEvent(new Event('input', { bubbles: true }));
    });
  }

  // Таймер бездействия (60 секунд)
  function resetIdleTimer() {
    if (idleTimer) clearTimeout(idleTimer);
    idleTimer = setTimeout(() => {
      hideKeyboard();
      if (bellsModal) bellsModal.classList.add('hidden');
      if (appQrModal) appQrModal.classList.add('hidden');
      const gModal = document.getElementById('groupModal');
      if (gModal) gModal.classList.add('hidden');
      const tModal = document.getElementById('teacherModal');
      if (tModal) tModal.classList.add('hidden');
      const tcModal = document.getElementById('teachersCatalogModal');
      if (tcModal) tcModal.classList.add('hidden');
    }, 60000);
  }

  ['touchstart', 'mousedown', 'pointerdown'].forEach(ev => {
    window.addEventListener(ev, resetIdleTimer, { passive: true });
  });

  resetIdleTimer();
})();
