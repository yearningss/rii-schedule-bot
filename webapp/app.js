// Telegram Mini App логика на чистом Vanilla JS
const tg = window.Telegram?.WebApp;
if (tg) {
  tg.ready();
  tg.expand();
  if (tg.setHeaderColor) tg.setHeaderColor('bg_color');
}

const telegramUser = tg?.initDataUnsafe?.user || null;
const telegramUserId = telegramUser?.id || null;

function triggerHaptic(style = 'light') {
  if (tg?.HapticFeedback) {
    try {
      tg.HapticFeedback.impactOccurred(style);
    } catch (e) {}
  }
}

// Состояние приложения
const state = {
  currentGroupId: localStorage.getItem('selected_group_id') ? parseInt(localStorage.getItem('selected_group_id')) : null,
  currentGroupName: localStorage.getItem('selected_group_name') || '',
  currentWeek: 1,
  currentDay: 1,
  subgroup: localStorage.getItem('selected_subgroup') ? parseInt(localStorage.getItem('selected_subgroup')) : 0,
  scheduleData: null,
  allGroups: [],
  userChangedManually: false
};

// Элементы интерфейса
const el = {
  groupSelectBtn: document.getElementById('groupSelectBtn'),
  currentGroupName: document.getElementById('currentGroupName'),
  week1Btn: document.getElementById('week1Btn'),
  week2Btn: document.getElementById('week2Btn'),
  daysNav: document.getElementById('daysNav'),
  liveStatusBar: document.getElementById('liveStatusBar'),
  liveStatusText: document.getElementById('liveStatusText'),
  scheduleCards: document.getElementById('scheduleCards'),
  emptyState: document.getElementById('emptyState'),
  loadingState: document.getElementById('loadingState'),
  groupModal: document.getElementById('groupModal'),
  closeModalBtn: document.getElementById('closeModalBtn'),
  groupSearchInput: document.getElementById('groupSearchInput'),
  groupsListContainer: document.getElementById('groupsListContainer'),
  subgroupBtns: document.querySelectorAll('.sg-btn'),
  scheduleContainer: document.getElementById('scheduleContainer')
};

// Определение текущего времени и дня в Рубцовске (UTC+7)
function getRubtsovskDate() {
  const now = new Date();
  const utc = now.getTime() + now.getTimezoneOffset() * 60000;
  return new Date(utc + 7 * 3600000);
}

function parseParaTime(timeStr, defaultParaNum = 1) {
  const defaultTimes = {
    1: { s: 8 * 60 + 30, e: 10 * 60 + 0, sStr: "08:30", eStr: "10:00" },
    2: { s: 10 * 60 + 10, e: 11 * 60 + 40, sStr: "10:10", eStr: "11:40" },
    3: { s: 12 * 60 + 10, e: 13 * 60 + 40, sStr: "12:10", eStr: "13:40" },
    4: { s: 13 * 60 + 50, e: 15 * 60 + 20, sStr: "13:50", eStr: "15:20" },
    5: { s: 15 * 60 + 30, e: 17 * 60 + 0, sStr: "15:30", eStr: "17:00" },
    6: { s: 17 * 60 + 10, e: 18 * 60 + 40, sStr: "17:10", eStr: "18:40" }
  };

  if (!timeStr) return defaultTimes[defaultParaNum] || { s: 0, e: 0, sStr: "", eStr: "" };

  const cleaned = timeStr.replace(/<br\s*\/?>/gi, " - ").replace(/\./g, ":").trim();
  const match = cleaned.match(/(\d{1,2})[:.](\d{2})\s*-\s*(\d{1,2})[:.](\d{2})/);
  if (match) {
    const sH = parseInt(match[1]), sM = parseInt(match[2]);
    const eH = parseInt(match[3]), eM = parseInt(match[4]);
    return {
      s: sH * 60 + sM,
      e: eH * 60 + eM,
      sStr: `${String(sH).padStart(2, '0')}:${String(sM).padStart(2, '0')}`,
      eStr: `${String(eH).padStart(2, '0')}:${String(eM).padStart(2, '0')}`
    };
  }
  return defaultTimes[defaultParaNum] || { s: 0, e: 0, sStr: "", eStr: "" };
}

// Фоновая синхронизация настроек пользователя с ботом
async function syncUserWithBot(groupId, groupName, subgroup) {
  if (!telegramUserId) return;
  try {
    await fetch('/api/user/sync', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        user_id: telegramUserId,
        group_id: groupId,
        group_name: groupName,
        subgroup: subgroup
      })
    });
  } catch (e) {
    console.warn('Синхронизация с ботом не удалась:', e);
  }
}

// Загрузка данных пользователя из бота
async function fetchUserBotSettings() {
  if (!telegramUserId) return null;
  try {
    const res = await fetch(`/api/user?user_id=${telegramUserId}`);
    if (res.ok) {
      const data = await res.json();
      if (data.group_id) {
        return data;
      }
    }
  } catch (e) {
    console.warn('Не удалось загрузить настройки пользователя:', e);
  }
  return null;
}

// Загрузка списка групп и инициализация
async function initApp() {
  try {
    const res = await fetch('/api/groups');
    if (!res.ok) throw new Error('Ошибка сети');
    state.allGroups = await res.json();
    renderGroupsList();

    // 1. Проверяем настройки пользователя из Telegram-бота
    const botUser = await fetchUserBotSettings();
    const urlParams = new URLSearchParams(window.location.search);
    const paramGid = urlParams.get('group_id');

    if (botUser && botUser.group_id) {
      // Приоритет настроек из бота
      state.currentGroupId = botUser.group_id;
      state.currentGroupName = botUser.group_name;
      state.subgroup = botUser.subgroup ?? state.subgroup;
      localStorage.setItem('selected_group_id', state.currentGroupId);
      localStorage.setItem('selected_group_name', state.currentGroupName);
      localStorage.setItem('selected_subgroup', state.subgroup);
    } else if (paramGid) {
      const g = state.allGroups.find(x => x.id === parseInt(paramGid));
      if (g) {
        state.currentGroupId = g.id;
        state.currentGroupName = g.name;
        localStorage.setItem('selected_group_id', g.id);
        localStorage.setItem('selected_group_name', g.name);
      }
    } else if (!state.currentGroupId && state.allGroups.length > 0) {
      // Если вообще ничего не выбрано
      state.currentGroupId = state.allGroups[0].id;
      state.currentGroupName = state.allGroups[0].name;
    }

    if (state.currentGroupId) {
      el.currentGroupName.textContent = state.currentGroupName;
      updateSubgroupButtonsUI();
      loadSchedule();
    }
  } catch (err) {
    console.error('Ошибка инициализации:', err);
  }
}

// Загрузка расписания
async function loadSchedule() {
  if (!state.currentGroupId) return;

  el.loadingState.classList.remove('hidden');
  el.emptyState.classList.add('hidden');
  el.scheduleCards.innerHTML = '';
  el.liveStatusBar.classList.add('hidden');

  try {
    const res = await fetch(`/api/schedule?group_id=${state.currentGroupId}`);
    if (!res.ok) throw new Error('Ошибка загрузки расписания');
    state.scheduleData = await res.json();

    const siteWeek = parseInt(state.scheduleData.weekNumber || 1);
    const rDate = getRubtsovskDate();
    let rDay = rDate.getDay();
    if (rDay === 0) rDay = 7;

    // Первичная установка текущей недели и дня
    if (!state.userChangedManually) {
      state.currentWeek = siteWeek;
      state.currentDay = rDay > 6 ? 1 : rDay;
    }

    updateWeekButtonsUI();
    updateDaysNavUI();
    renderSchedule();
  } catch (err) {
    console.error('Ошибка расписания:', err);
    el.loadingState.classList.add('hidden');
    el.emptyState.classList.remove('hidden');
  }
}

// Отрисовка расписания на выбранный день
function renderSchedule() {
  el.loadingState.classList.add('hidden');
  if (!state.scheduleData) return;

  const weekData = state.scheduleData.scheduleData?.[String(state.currentWeek)] || {};
  const dayData = weekData[String(state.currentDay)] || {};
  const paraTimes = state.scheduleData.paraTimes || {};

  const rDate = getRubtsovskDate();
  let rDay = rDate.getDay();
  if (rDay === 0) rDay = 7;
  const siteWeek = parseInt(state.scheduleData.weekNumber || 1);
  const isToday = (state.currentWeek === siteWeek && state.currentDay === rDay);

  const curMins = rDate.getHours() * 60 + rDate.getMinutes();

  const sortedParas = Object.keys(dayData).sort((a, b) => parseInt(a) - parseInt(b));

  if (sortedParas.length === 0) {
    el.scheduleCards.innerHTML = '';
    el.emptyState.classList.remove('hidden');
    el.liveStatusBar.classList.add('hidden');
    return;
  }

  el.emptyState.classList.add('hidden');

  // Расчет плашки живого статуса для сегодняшнего дня
  if (isToday) {
    let ongoingPara = null;
    let nextPara = null;

    for (const pStr of sortedParas) {
      const pN = parseInt(pStr);
      const tInfo = parseParaTime(paraTimes[pStr], pN);
      if (tInfo.s <= curMins && curMins <= tInfo.e) {
        ongoingPara = { pN, rem: tInfo.e - curMins, eStr: tInfo.eStr };
        break;
      } else if (curMins < tInfo.s && !nextPara) {
        nextPara = { pN, rem: tInfo.s - curMins, sStr: tInfo.sStr };
      }
    }

    if (ongoingPara) {
      el.liveStatusText.textContent = `Идет ${ongoingPara.pN} пара (до ${ongoingPara.eStr}, осталось ${ongoingPara.rem} мин)`;
      el.liveStatusBar.classList.remove('hidden');
    } else if (nextPara) {
      const firstPN = parseInt(sortedParas[0]);
      const firstTInfo = parseParaTime(paraTimes[String(firstPN)], firstPN);
      if (curMins < firstTInfo.s) {
        el.liveStatusText.textContent = `Занятия не начались. ${firstPN} пара начнется в ${firstTInfo.sStr} (через ${firstTInfo.s - curMins} мин)`;
      } else {
        el.liveStatusText.textContent = `Перемена (до ${nextPara.sStr}, осталось ${nextPara.rem} мин). Следующая: ${nextPara.pN} пара`;
      }
      el.liveStatusBar.classList.remove('hidden');
    } else {
      el.liveStatusText.textContent = 'Все пары на сегодня завершены';
      el.liveStatusBar.classList.remove('hidden');
    }
  } else {
    el.liveStatusBar.classList.add('hidden');
  }

  // Генерация карточек пар
  let html = '';
  let foundNext = false;

  for (const pStr of sortedParas) {
    const item = dayData[pStr];
    const pN = parseInt(pStr);
    const tInfo = parseParaTime(paraTimes[pStr], pN);
    const timeDisplay = tInfo.sStr ? `${tInfo.sStr} - ${tInfo.eStr}` : '';

    let statusClass = '';
    let badgeHtml = '';

    if (isToday) {
      if (curMins > tInfo.e) {
        statusClass = '';
        badgeHtml = '<span class="para-badge badge-completed">Завершена</span>';
      } else if (tInfo.s <= curMins && curMins <= tInfo.e) {
        statusClass = 'is-ongoing';
        badgeHtml = '<span class="para-badge badge-ongoing">Идет сейчас</span>';
      } else if (curMins < tInfo.s && !foundNext) {
        statusClass = 'is-next';
        badgeHtml = '<span class="para-badge badge-next">Следующая</span>';
        foundNext = true;
      }
    }

    if (item.isDouble) {
      let partsHtml = '';
      if ((state.subgroup === 0 || state.subgroup === 1) && (item.subj1 || item.aud1)) {
        partsHtml += `
          <div class="subgroup-block">
            <div class="subgroup-label">1 подгруппа</div>
            <div class="para-subject">${item.subj1 || 'Предмет'} <span class="type-pill">${item.type1 ? `(${item.type1})` : ''}</span></div>
            <div class="para-meta">
              ${item.aud1 ? `<span class="aud-pill">ауд. ${item.aud1}</span>` : ''}
              <span>${item.teacher1 || ''} ${item.teachPost1 ? `(${item.teachPost1})` : ''}</span>
            </div>
          </div>`;
      }
      if ((state.subgroup === 0 || state.subgroup === 2) && (item.subj2 || item.aud2)) {
        partsHtml += `
          <div class="subgroup-block">
            <div class="subgroup-label">2 подгруппа</div>
            <div class="para-subject">${item.subj2 || 'Предмет'} <span class="type-pill">${item.type2 ? `(${item.type2})` : ''}</span></div>
            <div class="para-meta">
              ${item.aud2 ? `<span class="aud-pill">ауд. ${item.aud2}</span>` : ''}
              <span>${item.teacher2 || ''} ${item.teachPost2 ? `(${item.teachPost2})` : ''}</span>
            </div>
          </div>`;
      }

      html += `
        <div class="para-card ${statusClass}">
          <div class="para-header">
            <div class="para-num-time">
              <span class="para-num">${pN} пара</span>
              <span>${timeDisplay}</span>
            </div>
            ${badgeHtml}
          </div>
          ${partsHtml}
        </div>`;
    } else {
      html += `
        <div class="para-card ${statusClass}">
          <div class="para-header">
            <div class="para-num-time">
              <span class="para-num">${pN} пара</span>
              <span>${timeDisplay}</span>
            </div>
            ${badgeHtml}
          </div>
          <div class="para-subject">${item.subj1 || 'Предмет'} <span class="type-pill">${item.type1 ? `(${item.type1})` : ''}</span></div>
          <div class="para-meta">
            ${item.aud1 ? `<span class="aud-pill">ауд. ${item.aud1}</span>` : ''}
            <span>${item.teacher1 || ''} ${item.teachPost1 ? `(${item.teachPost1})` : ''}</span>
          </div>
        </div>`;
    }
  }

  el.scheduleCards.innerHTML = html;
}

// Переключение недели
function setWeek(weekNum) {
  if (state.currentWeek === weekNum) return;
  triggerHaptic();
  state.userChangedManually = true;
  state.currentWeek = weekNum;
  updateWeekButtonsUI();
  renderSchedule();
}

// Переключение дня
function setDay(dayNum) {
  if (state.currentDay === dayNum) return;
  triggerHaptic();
  state.userChangedManually = true;
  state.currentDay = dayNum;
  updateDaysNavUI();
  renderSchedule();
}

// Выбор группы
function selectGroup(groupId, groupName) {
  triggerHaptic('medium');
  state.currentGroupId = groupId;
  state.currentGroupName = groupName;
  localStorage.setItem('selected_group_id', groupId);
  localStorage.setItem('selected_group_name', groupName);
  el.currentGroupName.textContent = groupName;
  closeGroupModal();
  syncUserWithBot(groupId, groupName, state.subgroup);
  loadSchedule();
}

function updateWeekButtonsUI() {
  el.week1Btn.classList.toggle('active', state.currentWeek === 1);
  el.week2Btn.classList.toggle('active', state.currentWeek === 2);
}

function updateDaysNavUI() {
  const rDate = getRubtsovskDate();
  let rDay = rDate.getDay();
  if (rDay === 0) rDay = 7;

  document.querySelectorAll('.day-chip').forEach(btn => {
    const d = parseInt(btn.dataset.day);
    btn.classList.toggle('active', d === state.currentDay);
    btn.classList.toggle('today-badge', d === rDay);
  });
}

function updateSubgroupButtonsUI() {
  el.subgroupBtns.forEach(b => {
    b.classList.toggle('active', parseInt(b.dataset.sg) === state.subgroup);
  });
}

// Отрисовка списка групп в модалке
function renderGroupsList(filterQuery = '') {
  const query = filterQuery.toLowerCase().trim().replace(/[\s\-_]/g, '');
  const courses = {};

  state.allGroups.forEach(g => {
    const gNorm = g.name.toLowerCase().replace(/[\s\-_]/g, '');
    if (!query || gNorm.includes(query)) {
      courses[g.course] = courses[g.course] || [];
      courses[g.course].push(g);
    }
  });

  let html = '';
  Object.keys(courses).sort().forEach(course => {
    html += `<div class="course-section-title">${course} курс</div>`;
    courses[course].forEach(g => {
      html += `<button class="group-item-btn" onclick="selectGroup(${g.id}, '${g.name}')">${g.name}</button>`;
    });
  });

  if (html === '') {
    html = '<p style="text-align:center; padding: 20px; color: var(--hint-color);">Группы не найдены</p>';
  }

  el.groupsListContainer.innerHTML = html;
}

// Модалка групп
function openGroupModal() {
  triggerHaptic();
  el.groupModal.classList.remove('hidden');
  el.groupSearchInput.value = '';
  renderGroupsList();
  el.groupSearchInput.focus();
}

function closeGroupModal() {
  el.groupModal.classList.add('hidden');
}

// Свайпы дней недели (Touch gestures)
let touchStartX = 0;
let touchStartY = 0;

el.scheduleContainer.addEventListener('touchstart', e => {
  touchStartX = e.changedTouches[0].screenX;
  touchStartY = e.changedTouches[0].screenY;
}, { passive: true });

el.scheduleContainer.addEventListener('touchend', e => {
  const diffX = e.changedTouches[0].screenX - touchStartX;
  const diffY = e.changedTouches[0].screenY - touchStartY;

  if (Math.abs(diffX) > Math.abs(diffY) && Math.abs(diffX) > 50) {
    if (diffX < 0) {
      if (state.currentDay < 6) {
        setDay(state.currentDay + 1);
      } else if (state.currentDay === 6) {
        state.currentWeek = state.currentWeek === 1 ? 2 : 1;
        setDay(1);
      }
    } else {
      if (state.currentDay > 1) {
        setDay(state.currentDay - 1);
      } else if (state.currentDay === 1) {
        state.currentWeek = state.currentWeek === 1 ? 2 : 1;
        setDay(6);
      }
    }
  }
}, { passive: true });

// Обработчики событий
el.groupSelectBtn.addEventListener('click', openGroupModal);
el.closeModalBtn.addEventListener('click', closeGroupModal);
el.groupModal.addEventListener('click', e => {
  if (e.target === el.groupModal) closeGroupModal();
});

el.groupSearchInput.addEventListener('input', e => {
  renderGroupsList(e.target.value);
});

el.week1Btn.addEventListener('click', () => setWeek(1));
el.week2Btn.addEventListener('click', () => setWeek(2));

el.daysNav.addEventListener('click', e => {
  const btn = e.target.closest('.day-chip');
  if (btn) setDay(parseInt(btn.dataset.day));
});

el.subgroupBtns.forEach(btn => {
  btn.addEventListener('click', () => {
    triggerHaptic();
    state.subgroup = parseInt(btn.dataset.sg);
    localStorage.setItem('selected_subgroup', state.subgroup);
    updateSubgroupButtonsUI();
    syncUserWithBot(state.currentGroupId, state.currentGroupName, state.subgroup);
    renderSchedule();
  });
});

// Регистрация Service Worker для PWA и офлайн-режима
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').catch(err => {
      console.warn('SW registration failed:', err);
    });
  });
}

// Установка PWA в браузере вне Telegram
let deferredPrompt = null;
const pwaBanner = document.getElementById('pwaInstallBanner');
const pwaBtn = document.getElementById('pwaInstallBtn');

window.addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault();
  deferredPrompt = e;
  // Показываем только в браузере, если открыто не внутри Telegram WebApp
  if (!tg?.initData) {
    pwaBanner?.classList.remove('hidden');
  }
});

pwaBtn?.addEventListener('click', async () => {
  if (deferredPrompt) {
    deferredPrompt.prompt();
    const { outcome } = await deferredPrompt.userChoice;
    if (outcome === 'accepted') {
      pwaBanner?.classList.add('hidden');
    }
    deferredPrompt = null;
  }
});

window.addEventListener('appinstalled', () => {
  pwaBanner?.classList.add('hidden');
  deferredPrompt = null;
});

// Запуск приложения
initApp();
