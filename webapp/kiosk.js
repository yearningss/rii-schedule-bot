// Сенсорный терминал расписания РИИ АлтГТУ на базе логики и дизайна Telegram Mini App
(function () {
  'use strict';

  // Состояние киоска
  const state = {
    currentGroupId: localStorage.getItem('kiosk_group_id') ? parseInt(localStorage.getItem('kiosk_group_id')) : null,
    currentGroupName: localStorage.getItem('kiosk_group_name') || '',
    currentWeek: 1,
    currentDay: 1,
    subgroup: 0,
    scheduleData: null,
    allGroups: [],
    allTeachers: [],
    activeKeyboardInput: null,
    idleTimer: null,
    idleCountdownTimer: null,
    idleSecondsLeft: 10
  };

  const BELLS = [
    { num: 1, s: 510, e: 600, sStr: '08:30', eStr: '10:00', br: '10 мин' },
    { num: 2, s: 610, e: 700, sStr: '10:10', eStr: '11:40', br: '30 мин' },
    { num: 3, s: 730, e: 820, sStr: '12:10', eStr: '13:40', br: '10 мин' },
    { num: 4, s: 830, e: 920, sStr: '13:50', eStr: '15:20', br: '10 мин' },
    { num: 5, s: 930, e: 1020, sStr: '15:30', eStr: '17:00', br: '10 мин' },
    { num: 6, s: 1030, e: 1120, sStr: '17:10', eStr: '18:40', br: '10 мин' },
    { num: 7, s: 1130, e: 1220, sStr: '18:50', eStr: '20:20', br: 'Конец' }
  ];

  const DAYS_RU = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];
  const MONTHS_RU = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];

  // DOM
  const el = {
    clockTime: document.getElementById('kioskClockTime'),
    clockDate: document.getElementById('kioskClockDate'),
    liveBellText: document.getElementById('kioskLiveBellText'),
    resetBtn: document.getElementById('kioskResetBtn'),

    groupSelectBtn: document.getElementById('groupSelectBtn'),
    currentGroupName: document.getElementById('currentGroupName'),
    teachersCatalogBtn: document.getElementById('teachersCatalogBtn'),
    bellsModalBtn: document.getElementById('bellsModalBtn'),
    appModalBtn: document.getElementById('appModalBtn'),
    week1Btn: document.getElementById('week1Btn'),
    week2Btn: document.getElementById('week2Btn'),
    daysNav: document.getElementById('daysNav'),

    liveStatusBar: document.getElementById('liveStatusBar'),
    liveStatusText: document.getElementById('liveStatusText'),
    scheduleCards: document.getElementById('scheduleCards'),
    emptyState: document.getElementById('emptyState'),
    loadingState: document.getElementById('loadingState'),
    subgroupBtns: document.querySelectorAll('.sg-btn'),

    // Модалка групп
    groupModal: document.getElementById('groupModal'),
    closeModalBtn: document.getElementById('closeModalBtn'),
    groupSearchInput: document.getElementById('groupSearchInput'),
    groupsListContainer: document.getElementById('groupsListContainer'),
    kbGroupBtn: document.getElementById('kbGroupBtn'),

    // Модалка каталога преподавателей
    teachersCatalogModal: document.getElementById('teachersCatalogModal'),
    closeTeachersCatalogBtn: document.getElementById('closeTeachersCatalogBtn'),
    teacherSearchInput: document.getElementById('teacherSearchInput'),
    teachersListContainer: document.getElementById('teachersListContainer'),
    kbTeacherBtn: document.getElementById('kbTeacherBtn'),

    // Модалка преподавателя
    teacherModal: document.getElementById('teacherModal'),
    closeTeacherModalBtn: document.getElementById('closeTeacherModalBtn'),
    closeTeacherBottomBtn: document.getElementById('closeTeacherBottomBtn'),
    teacherLoading: document.getElementById('teacherLoading'),
    teacherContent: document.getElementById('teacherContent'),
    teacherFullName: document.getElementById('teacherFullName'),
    teacherPost: document.getElementById('teacherPost'),
    teacherDeptBadge: document.getElementById('teacherDeptBadge'),
    teacherRoom: document.getElementById('teacherRoom'),
    teacherRoomRow: document.getElementById('teacherRoomRow'),
    teacherDegree: document.getElementById('teacherDegree'),
    teacherDegreeRow: document.getElementById('teacherDegreeRow'),
    teacherPhone: document.getElementById('teacherPhone'),
    teacherPhoneRow: document.getElementById('teacherPhoneRow'),
    teacherEmail: document.getElementById('teacherEmail'),
    teacherEmailRow: document.getElementById('teacherEmailRow'),
    teacherDisciplines: document.getElementById('teacherDisciplines'),
    teacherDisciplinesRow: document.getElementById('teacherDisciplinesRow'),
    teacherSchedList: document.getElementById('teacherSchedList'),

    // Модалка звонков
    bellsModal: document.getElementById('bellsModal'),
    closeBellsModalBtn: document.getElementById('closeBellsModalBtn'),
    appBellsTableBody: document.getElementById('appBellsTableBody'),

    // Модалка промо
    appPromoModal: document.getElementById('appPromoModal'),
    closeAppPromoModalBtn: document.getElementById('closeAppPromoModalBtn'),

    // Экранная клавиатура
    keyboardDrawer: document.getElementById('kioskKeyboardDrawer'),
    kioskKbLabel: document.getElementById('kioskKbLabel'),
    kioskKbHideBtn: document.getElementById('kioskKbHideBtn'),
    kbKeyBackspace: document.getElementById('kbKeyBackspace'),
    kbKeySpace: document.getElementById('kbKeySpace'),
    kbKeyClear: document.getElementById('kbKeyClear'),

    // Диалог бездействия
    idleDialog: document.getElementById('kioskIdleDialog'),
    idleSeconds: document.getElementById('kioskIdleSeconds'),
    continueBtn: document.getElementById('kioskContinueBtn')
  };

  function getRubtsovskDate() {
    const now = new Date();
    const utc = now.getTime() + now.getTimezoneOffset() * 60000;
    return new Date(utc + 7 * 3600000);
  }

  function escapeHtml(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  function escapeAttr(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/'/g, '&#39;')
      .replace(/"/g, '&quot;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
  }

  function tickClock() {
    const rNow = getRubtsovskDate();
    const h = String(rNow.getHours()).padStart(2, '0');
    const m = String(rNow.getMinutes()).padStart(2, '0');
    if (el.clockTime) el.clockTime.textContent = `${h}:${m}`;

    if (el.clockDate) {
      const d = rNow.getDate();
      const mStr = MONTHS_RU[rNow.getMonth()];
      el.clockDate.textContent = `${d} ${mStr}`;
    }

    updateLiveBellBadge(rNow);
  }

  function updateLiveBellBadge(rNow) {
    const curMins = rNow.getHours() * 60 + rNow.getMinutes();
    const dayOfWeek = (rNow.getDay() + 6) % 7 + 1; // 1 = Пн ... 7 = Вс

    if (dayOfWeek === 7) {
      if (el.liveBellText) el.liveBellText.textContent = 'Воскресенье: выходной';
      return;
    }

    if (curMins < BELLS[0].s) {
      const rem = BELLS[0].s - curMins;
      if (el.liveBellText) el.liveBellText.textContent = `1 пара в 08:30 (через ${rem} мин)`;
      return;
    }

    for (let i = 0; i < BELLS.length; i++) {
      const b = BELLS[i];
      if (curMins >= b.s && curMins < b.e) {
        const rem = b.e - curMins;
        if (el.liveBellText) el.liveBellText.textContent = `Идет ${b.num} пара (до ${b.eStr}, осталось ${rem} мин)`;
        return;
      }
      if (i + 1 < BELLS.length) {
        const nxt = BELLS[i + 1];
        if (curMins >= b.e && curMins < nxt.s) {
          const rem = nxt.s - curMins;
          if (el.liveBellText) el.liveBellText.textContent = `Перемена (до ${nxt.sStr}, осталось ${rem} мин)`;
          return;
        }
      }
    }

    if (el.liveBellText) el.liveBellText.textContent = 'Занятия на сегодня завершены';
  }

  // ЗАГРУЗКА ДАННЫХ
  async function init() {
    tickClock();
    setInterval(tickClock, 1000);

    setupEventListeners();
    setupKeyboard();
    resetIdleTimer();

    await loadGroups();
    loadTeachersList();

    renderBellsTable();

    if (state.currentGroupId) {
      loadSchedule();
    } else if (state.allGroups.length > 0) {
      selectGroup(state.allGroups[0].id, state.allGroups[0].name);
    }
  }

  async function loadGroups() {
    try {
      const res = await fetch('/api/groups');
      if (!res.ok) throw new Error('Ошибка сети');
      state.allGroups = await res.json();
      renderGroupsList();
    } catch (err) {
      console.error('Ошибка групп:', err);
    }
  }

  function renderGroupsList(filterText = '') {
    if (!el.groupsListContainer) return;
    el.groupsListContainer.innerHTML = '';

    const query = filterText.toLowerCase().trim();
    const courses = {};

    state.allGroups.forEach(g => {
      if (query && !g.name.toLowerCase().includes(query)) return;
      if (!courses[g.course]) courses[g.course] = [];
      courses[g.course].push(g);
    });

    const courseKeys = Object.keys(courses).sort((a, b) => parseInt(a) - parseInt(b));

    if (courseKeys.length === 0) {
      el.groupsListContainer.innerHTML = '<div style="text-align:center; padding: 20px; color: var(--hint-color);">Группы не найдены</div>';
      return;
    }

    courseKeys.forEach(c => {
      const header = document.createElement('div');
      header.className = 'course-section-title';
      header.textContent = `${c} КУРС`;
      el.groupsListContainer.appendChild(header);

      courses[c].forEach(g => {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'group-item-btn';
        btn.textContent = g.name;
        btn.addEventListener('click', () => {
          resetIdleTimer();
          selectGroup(g.id, g.name);
          closeModal();
        });
        el.groupsListContainer.appendChild(btn);
      });
    });
  }

  function selectGroup(groupId, groupName) {
    state.currentGroupId = groupId;
    state.currentGroupName = groupName;
    el.currentGroupName.textContent = groupName;

    localStorage.setItem('kiosk_group_id', groupId);
    localStorage.setItem('kiosk_group_name', groupName);

    loadSchedule();
  }

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
      let rDay = (rDate.getDay() + 6) % 7 + 1;
      if (rDay > 6) rDay = 1;

      state.currentWeek = siteWeek;
      state.currentDay = rDay;

      updateWeekUI();
      updateDaysUI();
      renderSchedule();
    } catch (err) {
      console.error('Ошибка расписания:', err);
      el.loadingState.classList.add('hidden');
      el.emptyState.classList.remove('hidden');
    }
  }

  function updateWeekUI() {
    el.week1Btn.classList.toggle('active', state.currentWeek === 1);
    el.week2Btn.classList.toggle('active', state.currentWeek === 2);
  }

  function updateDaysUI() {
    const rDate = getRubtsovskDate();
    const todayNum = (rDate.getDay() + 6) % 7 + 1;

    document.querySelectorAll('.day-chip').forEach(chip => {
      const d = parseInt(chip.getAttribute('data-day'));
      chip.classList.toggle('active', d === state.currentDay);
      chip.classList.toggle('today-badge', d === todayNum);
    });
  }

  function renderTeacherHtml(teacher, post) {
    if (!teacher) return '';
    const cleanTeacher = teacher.trim();
    const cleanPost = (post || '').trim();
    const postDisplay = cleanPost ? ` (${cleanPost})` : '';
    return `<button type="button" class="teacher-btn-chip" data-teacher="${escapeAttr(cleanTeacher)}" data-post="${escapeAttr(cleanPost)}" title="Профиль преподавателя">
      <svg class="teacher-icon" viewBox="0 0 24 24" width="13" height="13"><path fill="currentColor" d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>
      <span class="teacher-name">${escapeHtml(cleanTeacher)}</span>${postDisplay ? `<span class="teacher-post-hint">${escapeHtml(postDisplay)}</span>` : ''}
      <svg class="teacher-arrow" viewBox="0 0 24 24" width="12" height="12"><path fill="currentColor" d="M8.59 16.59L13.17 12 8.59 7.41 10 6l6 6-6 6-1.41-1.41z"/></svg>
    </button>`;
  }

  // Отрисовка расписания (в точности как в Telegram Mini App)
  function renderSchedule() {
    el.loadingState.classList.add('hidden');
    if (!state.scheduleData) return;

    const weekData = state.scheduleData.scheduleData?.[String(state.currentWeek)] || {};
    const dayData = weekData[String(state.currentDay)] || {};

    const rDate = getRubtsovskDate();
    const todayDay = (rDate.getDay() + 6) % 7 + 1;
    const siteWeek = parseInt(state.scheduleData.weekNumber || 1);
    const isToday = (state.currentWeek === siteWeek && state.currentDay === todayDay);

    const curMins = rDate.getHours() * 60 + rDate.getMinutes();
    const sortedParas = Object.keys(dayData).sort((a, b) => parseInt(a) - parseInt(b));

    if (sortedParas.length === 0) {
      el.scheduleCards.innerHTML = '';
      el.emptyState.classList.remove('hidden');
      el.liveStatusBar.classList.add('hidden');
      return;
    }

    el.emptyState.classList.add('hidden');

    // Расчет статуса дня
    if (isToday) {
      let ongoing = null;
      let nextP = null;

      for (const pStr of sortedParas) {
        const pN = parseInt(pStr);
        const b = BELLS.find(x => x.num === pN);
        if (b) {
          if (b.s <= curMins && curMins < b.e) {
            ongoing = { pN, rem: b.e - curMins, eStr: b.eStr };
            break;
          } else if (curMins < b.s && !nextP) {
            nextP = { pN, rem: b.s - curMins, sStr: b.sStr };
          }
        }
      }

      if (ongoing) {
        el.liveStatusText.textContent = `Идет ${ongoing.pN} пара (до ${ongoing.eStr}, осталось ${ongoing.rem} мин)`;
        el.liveStatusBar.classList.remove('hidden');
      } else if (nextP) {
        const firstB = BELLS.find(x => x.num === parseInt(sortedParas[0]));
        if (firstB && curMins < firstB.s) {
          el.liveStatusText.textContent = `Занятия не начались. 1 пара в ${firstB.sStr} (через ${firstB.s - curMins} мин)`;
        } else {
          el.liveStatusText.textContent = `Перемена (до ${nextP.sStr}, осталось ${nextP.rem} мин). Следующая: ${nextP.pN} пара`;
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
      const b = BELLS.find(x => x.num === pN) || { s: 0, e: 0, sStr: '', eStr: '' };
      const timeDisplay = b.sStr ? `${b.sStr} - ${b.eStr}` : '';

      let statusClass = '';
      let badgeHtml = '';

      if (isToday) {
        if (curMins >= b.s && curMins < b.e) {
          statusClass = 'is-ongoing';
          badgeHtml = '<span class="para-badge badge-ongoing">Идет сейчас</span>';
        } else if (curMins < b.s && !foundNext) {
          statusClass = 'is-next';
          badgeHtml = '<span class="para-badge badge-next">Следующая</span>';
          foundNext = true;
        } else if (curMins >= b.e) {
          badgeHtml = '<span class="para-badge badge-completed">Завершена</span>';
        }
      }

      const isDouble = item.isDouble;
      let bodyHtml = '';

      if (!isDouble) {
        const subj = item.subj || item.subj1 || '';
        const type = item.type || item.type1 || '';
        const aud = item.aud || item.aud1 || '';
        const teacher = item.teacher || item.teacher1 || '';
        const teachPost = item.teachPost || item.teachPost1 || '';

        bodyHtml = `
          <div class="para-subject">${escapeHtml(subj)}</div>
          <div class="para-meta">
            ${aud ? `<span class="aud-pill">ауд. ${escapeHtml(aud)}</span>` : ''}
            ${type ? `<span class="type-pill">${escapeHtml(type)}</span>` : ''}
            ${renderTeacherHtml(teacher, teachPost)}
          </div>
        `;
      } else {
        // Двойная пара
        let sub1Html = '';
        let sub2Html = '';

        if (state.subgroup === 0 || state.subgroup === 1) {
          const s1 = item.subj1 || '';
          const t1 = item.type1 || '';
          const a1 = item.aud1 || '';
          const tch1 = item.teacher1 || '';
          const pst1 = item.teachPost1 || '';
          if (s1) {
            sub1Html = `
              <div class="subgroup-block">
                <div class="subgroup-label">1 подгруппа:</div>
                <div class="para-subject">${escapeHtml(s1)}</div>
                <div class="para-meta">
                  ${a1 ? `<span class="aud-pill">ауд. ${escapeHtml(a1)}</span>` : ''}
                  ${t1 ? `<span class="type-pill">${escapeHtml(t1)}</span>` : ''}
                  ${renderTeacherHtml(tch1, pst1)}
                </div>
              </div>
            `;
          }
        }

        if (state.subgroup === 0 || state.subgroup === 2) {
          const s2 = item.subj2 || '';
          const t2 = item.type2 || '';
          const a2 = item.aud2 || '';
          const tch2 = item.teacher2 || '';
          const pst2 = item.teachPost2 || '';
          if (s2) {
            sub2Html = `
              <div class="subgroup-block">
                <div class="subgroup-label">2 подгруппа:</div>
                <div class="para-subject">${escapeHtml(s2)}</div>
                <div class="para-meta">
                  ${a2 ? `<span class="aud-pill">ауд. ${escapeHtml(a2)}</span>` : ''}
                  ${t2 ? `<span class="type-pill">${escapeHtml(t2)}</span>` : ''}
                  ${renderTeacherHtml(tch2, pst2)}
                </div>
              </div>
            `;
          }
        }

        bodyHtml = sub1Html + sub2Html;
      }

      html += `
        <article class="para-card ${statusClass}">
          <div class="para-header">
            <div class="para-num-time">
              <span class="para-num">${pN} пара</span>
              <span>${timeDisplay}</span>
            </div>
            ${badgeHtml}
          </div>
          ${bodyHtml}
        </article>
      `;
    }

    el.scheduleCards.innerHTML = html;

    // Навешиваем клики на чипы преподавателей
    el.scheduleCards.querySelectorAll('.teacher-btn-chip').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        resetIdleTimer();
        const tName = btn.getAttribute('data-teacher');
        const tPost = btn.getAttribute('data-post');
        openTeacherModal(tName, tPost);
      });
    });
  }

  // КАТАЛОГ ПРЕПОДАВАТЕЛЕЙ
  async function loadTeachersList() {
    try {
      const res = await fetch('/api/teachers');
      if (res.ok) {
        state.allTeachers = await res.json();
        renderTeachersCatalog();
      }
    } catch (e) {
      console.warn('Ошибка загрузки преподавателей:', e);
    }
  }

  function renderTeachersCatalog(filterText = '') {
    if (!el.teachersListContainer) return;
    el.teachersListContainer.innerHTML = '';
    const q = filterText.toLowerCase().trim();

    const filtered = state.allTeachers.filter(t => {
      if (!q) return true;
      return (t.full_name && t.full_name.toLowerCase().includes(q)) ||
             (t.short_name && t.short_name.toLowerCase().includes(q)) ||
             (t.department && t.department.toLowerCase().includes(q)) ||
             (t.disciplines && t.disciplines.toLowerCase().includes(q));
    });

    if (filtered.length === 0) {
      el.teachersListContainer.innerHTML = '<div style="text-align:center; padding: 24px; color: var(--hint-color);">Преподаватели не найдены</div>';
      return;
    }

    filtered.forEach(t => {
      const item = document.createElement('div');
      item.className = 'teachers-catalog-item';
      item.innerHTML = `
        <div class="teachers-catalog-avatar">
          <svg viewBox="0 0 24 24" width="22" height="22"><path fill="currentColor" d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>
        </div>
        <div class="teachers-catalog-info">
          <div class="teachers-catalog-name">${escapeHtml(t.full_name || t.short_name)}</div>
          <div class="teachers-catalog-meta">${escapeHtml(t.post || 'Преподаватель')} ${t.department ? `- ${escapeHtml(t.department)}` : ''}</div>
        </div>
      `;
      item.addEventListener('click', () => {
        resetIdleTimer();
        el.teachersCatalogModal.classList.add('hidden');
        openTeacherModal(t.full_name || t.short_name, t.post);
      });
      el.teachersListContainer.appendChild(item);
    });
  }

  // МОДАЛКА ПРЕПОДАВАТЕЛЯ С РАСПИСАНИЕМ
  async function openTeacherModal(name, postHint = '') {
    el.teacherModal.classList.remove('hidden');
    el.teacherLoading.classList.remove('hidden');
    el.teacherContent.classList.add('hidden');

    try {
      const [infoRes, schedRes] = await Promise.all([
        fetch(`/api/teacher?name=${encodeURIComponent(name)}&post=${encodeURIComponent(postHint)}`),
        fetch(`/api/kiosk/teacher-schedule?name=${encodeURIComponent(name)}`)
      ]);

      const info = infoRes.ok ? await infoRes.json() : {};
      const sched = schedRes.ok ? await schedRes.json() : {};

      el.teacherFullName.textContent = info.full_name || name;
      el.teacherPost.textContent = info.post || postHint || 'Преподаватель';

      if (info.department) {
        el.teacherDeptBadge.textContent = info.department;
        el.teacherDeptBadge.classList.remove('hidden');
      } else {
        el.teacherDeptBadge.classList.add('hidden');
      }

      setRow(el.teacherRoomRow, el.teacherRoom, info.room);
      setRow(el.teacherDegreeRow, el.teacherDegree, info.degree);
      setRow(el.teacherPhoneRow, el.teacherPhone, info.phone);
      setRow(el.teacherEmailRow, el.teacherEmail, info.email);
      setRow(el.teacherDisciplinesRow, el.teacherDisciplines, info.disciplines);

      // Расписание преподавателя
      renderTeacherSchedule(sched.schedule);

      el.teacherLoading.classList.add('hidden');
      el.teacherContent.classList.remove('hidden');
    } catch (e) {
      console.error('Ошибка преподавателя:', e);
      el.teacherLoading.classList.add('hidden');
    }
  }

  function setRow(rowEl, valEl, val) {
    if (val && String(val).trim()) {
      valEl.textContent = val;
      rowEl.classList.remove('hidden');
    } else {
      rowEl.classList.add('hidden');
    }
  }

  function renderTeacherSchedule(sched) {
    if (!el.teacherSchedList) return;
    el.teacherSchedList.innerHTML = '';

    if (!sched) {
      el.teacherSchedList.innerHTML = '<div style="color: var(--hint-color); padding: 8px 0;">Занятия не найдены в общем расписании</div>';
      return;
    }

    const wData = sched[String(state.currentWeek)] || {};
    let blocks = '';

    for (let d = 1; d <= 6; d++) {
      const dayParas = wData[String(d)] || [];
      if (dayParas.length === 0) continue;

      let parasList = '';
      for (const p of dayParas) {
        parasList += `
          <div class="teacher-sched-item">
            <div>
              <strong>${p.num} пара (${escapeHtml(p.time)})</strong>: ${escapeHtml(p.subject)}
              <span style="color: var(--btn-color); font-weight: 700; margin-left: 6px;">Группа: ${escapeHtml(p.group)}</span>
            </div>
            ${p.aud ? `<span class="aud-pill">ауд. ${escapeHtml(p.aud)}</span>` : ''}
          </div>
        `;
      }

      blocks += `
        <div class="teacher-sched-day-block">
          <div class="teacher-sched-day-title">${DAYS_RU[d-1]}</div>
          ${parasList}
        </div>
      `;
    }

    el.teacherSchedList.innerHTML = blocks || '<div style="color: var(--hint-color); padding: 8px 0;">На этой неделе занятий нет</div>';
  }

  // ТАБЛИЦА ЗВОНКОВ
  function renderBellsTable() {
    if (!el.appBellsTableBody) return;
    const rNow = getRubtsovskDate();
    const curMins = rNow.getHours() * 60 + rNow.getMinutes();

    let rows = '';
    for (const b of BELLS) {
      const isCur = (curMins >= b.s && curMins < b.e);
      const rowClass = isCur ? 'active-bell' : '';
      const statusStr = isCur ? 'Идет сейчас' : '';

      rows += `
        <tr class="${rowClass}">
          <td><strong>${b.num} пара</strong></td>
          <td>${b.sStr} - ${b.eStr}</td>
          <td>${b.br}</td>
          <td><strong style="color: var(--ongoing-color);">${statusStr}</strong></td>
        </tr>
      `;
    }

    el.appBellsTableBody.innerHTML = rows;
  }

  // ЭКРАННАЯ КЛАВИАТУРА
  function setupKeyboard() {
    if (el.kioskKbHideBtn) {
      el.kioskKbHideBtn.addEventListener('click', hideKeyboard);
    }

    document.querySelectorAll('.kb-key[data-k]').forEach(btn => {
      btn.addEventListener('click', () => {
        resetIdleTimer();
        if (!state.activeKeyboardInput) return;
        state.activeKeyboardInput.value += btn.getAttribute('data-k');
        triggerSearchInput(state.activeKeyboardInput);
      });
    });

    if (el.kbKeyBackspace) {
      el.kbKeyBackspace.addEventListener('click', () => {
        resetIdleTimer();
        if (!state.activeKeyboardInput) return;
        state.activeKeyboardInput.value = state.activeKeyboardInput.value.slice(0, -1);
        triggerSearchInput(state.activeKeyboardInput);
      });
    }

    if (el.kbKeySpace) {
      el.kbKeySpace.addEventListener('click', () => {
        resetIdleTimer();
        if (!state.activeKeyboardInput) return;
        state.activeKeyboardInput.value += ' ';
        triggerSearchInput(state.activeKeyboardInput);
      });
    }

    if (el.kbKeyClear) {
      el.kbKeyClear.addEventListener('click', () => {
        resetIdleTimer();
        if (!state.activeKeyboardInput) return;
        state.activeKeyboardInput.value = '';
        triggerSearchInput(state.activeKeyboardInput);
      });
    }
  }

  function showKeyboard(inputEl, label) {
    state.activeKeyboardInput = inputEl;
    if (el.kioskKbLabel) el.kioskKbLabel.textContent = label || 'Ввод текста';
    if (el.keyboardDrawer) el.keyboardDrawer.classList.remove('hidden');
  }

  function hideKeyboard() {
    state.activeKeyboardInput = null;
    if (el.keyboardDrawer) el.keyboardDrawer.classList.add('hidden');
  }

  function triggerSearchInput(inputEl) {
    if (inputEl === el.groupSearchInput) {
      renderGroupsList(inputEl.value);
    } else if (inputEl === el.teacherSearchInput) {
      renderTeachersCatalog(inputEl.value);
    }
  }

  // ТАЙМЕР БЕЗДЕЙСТВИЯ (60 СЕК)
  function resetIdleTimer() {
    if (state.idleTimer) clearTimeout(state.idleTimer);
    if (state.idleCountdownTimer) clearInterval(state.idleCountdownTimer);

    if (el.idleDialog && !el.idleDialog.classList.contains('hidden')) {
      el.idleDialog.classList.add('hidden');
    }

    state.idleTimer = setTimeout(() => {
      startIdleWarning();
    }, 60000);
  }

  function startIdleWarning() {
    state.idleSecondsLeft = 10;
    if (el.idleSeconds) el.idleSeconds.textContent = state.idleSecondsLeft;
    if (el.idleDialog) el.idleDialog.classList.remove('hidden');

    state.idleCountdownTimer = setInterval(() => {
      state.idleSecondsLeft -= 1;
      if (el.idleSeconds) el.idleSeconds.textContent = state.idleSecondsLeft;
      if (state.idleSecondsLeft <= 0) {
        clearInterval(state.idleCountdownTimer);
        resetToDefault();
      }
    }, 1000);
  }

  function resetToDefault() {
    closeModal();
    hideKeyboard();
    if (el.teacherModal) el.teacherModal.classList.add('hidden');
    if (el.teachersCatalogModal) el.teachersCatalogModal.classList.add('hidden');
    if (el.bellsModal) el.bellsModal.classList.add('hidden');
    if (el.appPromoModal) el.appPromoModal.classList.add('hidden');
    if (el.idleDialog) el.idleDialog.classList.add('hidden');

    if (state.allGroups.length > 0) {
      selectGroup(state.allGroups[0].id, state.allGroups[0].name);
    }
    resetIdleTimer();
  }

  function closeModal() {
    el.groupModal.classList.add('hidden');
    hideKeyboard();
  }

  // НАВЕШИВАНИЕ ОБРАБОТЧИКОВ
  function setupEventListeners() {
    // Сброс по клику "На главную"
    if (el.resetBtn) el.resetBtn.addEventListener('click', resetToDefault);

    // Выбор группы
    el.groupSelectBtn.addEventListener('click', () => {
      resetIdleTimer();
      el.groupSearchInput.value = '';
      renderGroupsList();
      el.groupModal.classList.remove('hidden');
    });

    el.closeModalBtn.addEventListener('click', closeModal);

    el.kbGroupBtn.addEventListener('click', () => {
      showKeyboard(el.groupSearchInput, 'Поиск учебной группы');
    });

    el.groupSearchInput.addEventListener('click', () => {
      showKeyboard(el.groupSearchInput, 'Поиск учебной группы');
    });

    // Каталог преподавателей
    el.teachersCatalogBtn.addEventListener('click', () => {
      resetIdleTimer();
      el.teacherSearchInput.value = '';
      renderTeachersCatalog();
      el.teachersCatalogModal.classList.remove('hidden');
    });

    el.closeTeachersCatalogBtn.addEventListener('click', () => {
      el.teachersCatalogModal.classList.add('hidden');
      hideKeyboard();
    });

    el.kbTeacherBtn.addEventListener('click', () => {
      showKeyboard(el.teacherSearchInput, 'Поиск преподавателя');
    });

    el.teacherSearchInput.addEventListener('click', () => {
      showKeyboard(el.teacherSearchInput, 'Поиск преподавателя');
    });

    // Модалка преподавателя
    el.closeTeacherModalBtn.addEventListener('click', () => {
      el.teacherModal.classList.add('hidden');
    });
    el.closeTeacherBottomBtn.addEventListener('click', () => {
      el.teacherModal.classList.add('hidden');
    });

    // Модалка звонков
    el.bellsModalBtn.addEventListener('click', () => {
      resetIdleTimer();
      renderBellsTable();
      el.bellsModal.classList.remove('hidden');
    });
    el.closeBellsModalBtn.addEventListener('click', () => {
      el.bellsModal.classList.add('hidden');
    });

    // Модалка приложения
    el.appModalBtn.addEventListener('click', () => {
      resetIdleTimer();
      el.appPromoModal.classList.remove('hidden');
    });
    el.closeAppPromoModalBtn.addEventListener('click', () => {
      el.appPromoModal.classList.add('hidden');
    });

    // Переключение недель
    el.week1Btn.addEventListener('click', () => {
      resetIdleTimer();
      state.currentWeek = 1;
      updateWeekUI();
      renderSchedule();
    });

    el.week2Btn.addEventListener('click', () => {
      resetIdleTimer();
      state.currentWeek = 2;
      updateWeekUI();
      renderSchedule();
    });

    // Переключение дней
    document.querySelectorAll('.day-chip').forEach(chip => {
      chip.addEventListener('click', () => {
        resetIdleTimer();
        state.currentDay = parseInt(chip.getAttribute('data-day'));
        updateDaysUI();
        renderSchedule();
      });
    });

    // Переключение подгрупп
    el.subgroupBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        resetIdleTimer();
        el.subgroupBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        state.subgroup = parseInt(btn.getAttribute('data-sg'));
        renderSchedule();
      });
    });

    // Кнопка продолжения в диалоге бездействия
    if (el.continueBtn) {
      el.continueBtn.addEventListener('click', resetIdleTimer);
    }

    // Слушатель касаний для сброса таймера
    ['touchstart', 'mousedown', 'pointerdown'].forEach(evt => {
      window.addEventListener(evt, resetIdleTimer, { passive: true });
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
