// Скрипт сенсорного киоска самообслуживания РИИ АлтГТУ (Touchscreen Kiosk)
(function () {
  'use strict';

  // Состояние киоска
  const state = {
    groups: [],
    teachers: [],
    selectedGroup: null,
    groupSchedule: null,
    currentWeek: 1,
    currentDay: 1,
    activeCourseFilter: 'all',
    activeKeyboardTarget: null,
    idleTimer: null,
    idleWarningTimer: null,
    idleCountdownValue: 10,
    isIdleWarningOpen: false,
    teachersCache: {},
    teacherScheduleCache: {}
  };

  // Константы регламента звонков
  const BELLS = [
    { num: 1, start: '08:30', end: '10:00', startMins: 510, endMins: 600, breakMins: 10 },
    { num: 2, start: '10:10', end: '11:40', startMins: 610, endMins: 700, breakMins: 30 },
    { num: 3, start: '12:10', end: '13:40', startMins: 730, endMins: 820, breakMins: 10 },
    { num: 4, start: '13:50', end: '15:20', startMins: 830, endMins: 920, breakMins: 10 },
    { num: 5, start: '15:30', end: '17:00', startMins: 930, endMins: 1020, breakMins: 10 },
    { num: 6, start: '17:10', end: '18:40', startMins: 1030, endMins: 1120, breakMins: 10 },
    { num: 7, start: '18:50', end: '20:20', startMins: 1130, endMins: 1220, breakMins: 0 }
  ];

  const DAYS_RU = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
  const MONTHS_RU = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];

  // DOM элементы
  const dom = {
    clock: document.getElementById('kioskClock'),
    date: document.getElementById('kioskDate'),
    bellBadge: document.getElementById('kioskBellBadge'),
    bellText: document.getElementById('kioskBellText'),
    homeBtn: document.getElementById('kioskHomeBtn'),
    tabBtns: document.querySelectorAll('.kiosk-tab-btn'),
    tabContents: document.querySelectorAll('.kiosk-tab-content'),

    // Группы
    groupsSelector: document.getElementById('kioskGroupsSelector'),
    groupsGrid: document.getElementById('kioskGroupsGrid'),
    groupSearchInput: document.getElementById('kioskGroupSearchInput'),
    clearGroupSearchBtn: document.getElementById('clearGroupSearchBtn'),
    openGroupKeyboardBtn: document.getElementById('openGroupKeyboardBtn'),
    courseChips: document.querySelectorAll('.kiosk-chip'),

    // Расписание выбранной группы
    scheduleView: document.getElementById('kioskScheduleView'),
    backToGroupsBtn: document.getElementById('kioskBackToGroupsBtn'),
    selectedGroupName: document.getElementById('kioskSelectedGroupName'),
    selectedGroupCourse: document.getElementById('kioskSelectedGroupCourse'),
    weekBtn1: document.getElementById('kioskWeekBtn1'),
    weekBtn2: document.getElementById('kioskWeekBtn2'),
    dayBtns: document.querySelectorAll('.kiosk-day-btn'),
    scheduleCards: document.getElementById('kioskScheduleCards'),

    // Преподаватели
    teacherSearchInput: document.getElementById('kioskTeacherSearchInput'),
    clearTeacherSearchBtn: document.getElementById('clearTeacherSearchBtn'),
    openTeacherKeyboardBtn: document.getElementById('openTeacherKeyboardBtn'),
    teachersGrid: document.getElementById('kioskTeachersGrid'),

    // Звонки
    bellsTableBody: document.getElementById('kioskBellsTableBody'),

    // Экранная клавиатура
    keyboardPanel: document.getElementById('kioskKeyboardPanel'),
    keyboardTargetLabel: document.getElementById('kioskKeyboardTargetLabel'),
    closeKeyboardBtn: document.getElementById('closeKeyboardBtn'),
    keyBackspace: document.getElementById('keyBackspace'),
    keySpace: document.getElementById('keySpace'),
    keyClear: document.getElementById('keyClear'),

    // Модалка преподавателя
    teacherModal: document.getElementById('kioskTeacherModal'),
    teacherModalName: document.getElementById('kioskModalTeacherName'),
    teacherModalPost: document.getElementById('kioskModalTeacherPost'),
    teacherModalBody: document.getElementById('kioskTeacherModalBody'),
    closeTeacherModalBtn: document.getElementById('closeTeacherModalBtn'),

    // Таймер бездействия
    idleOverlay: document.getElementById('kioskIdleOverlay'),
    idleCountdown: document.getElementById('kioskIdleCountdown'),
    idleContinueBtn: document.getElementById('kioskIdleContinueBtn')
  };

  function escapeHtml(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  // Получение времени Рубцовска (UTC+7)
  function getRubtsovskNow() {
    const now = new Date();
    const utc = now.getTime() + now.getTimezoneOffset() * 60000;
    return new Date(utc + 7 * 3600000);
  }

  // Обновление точных часов и звонка в шапке
  function tickClock() {
    const rNow = getRubtsovskNow();
    const h = String(rNow.getHours()).padStart(2, '0');
    const m = String(rNow.getMinutes()).padStart(2, '0');
    if (dom.clock) {
      dom.clock.textContent = `${h}:${m}`;
    }
    if (dom.date) {
      const day = rNow.getDate();
      const monthStr = MONTHS_RU[rNow.getMonth()];
      const dayName = DAYS_RU[(rNow.getDay() + 6) % 7];
      dom.date.textContent = `${day} ${monthStr}, ${dayName}`;
    }

    updateBellStatus(rNow);
  }

  function updateBellStatus(rNow) {
    const dayOfWeek = (rNow.getDay() + 6) % 7 + 1; // 1 = Пн ... 7 = Вс
    const curMins = rNow.getHours() * 60 + rNow.getMinutes();

    if (dayOfWeek === 7) {
      dom.bellBadge.className = 'kiosk-bell-badge';
      dom.bellBadge.textContent = 'ВЫХОДНОЙ';
      dom.bellText.textContent = 'Сегодня воскресенье, учебных занятий нет';
      return;
    }

    if (curMins < BELLS[0].startMins) {
      const rem = BELLS[0].startMins - curMins;
      dom.bellBadge.className = 'kiosk-bell-badge';
      dom.bellBadge.textContent = 'ДО ЗАНЯТИЙ';
      dom.bellText.textContent = `1 пара начнется в 08:30 (через ${rem} мин)`;
      return;
    }

    for (let i = 0; i < BELLS.length; i++) {
      const b = BELLS[i];
      if (curMins >= b.startMins && curMins < b.endMins) {
        const rem = b.endMins - curMins;
        dom.bellBadge.className = 'kiosk-bell-badge green';
        dom.bellBadge.textContent = `ИДЕТ ${b.num} ПАРА`;
        dom.bellText.textContent = `До конца пары: ${rem} мин (окончание в ${b.end})`;
        return;
      }

      if (i + 1 < BELLS.length) {
        const nextB = BELLS[i + 1];
        if (curMins >= b.endMins && curMins < nextB.startMins) {
          const rem = nextB.startMins - curMins;
          dom.bellBadge.className = 'kiosk-bell-badge amber';
          dom.bellBadge.textContent = 'ПЕРЕМЕНА';
          dom.bellText.textContent = `До ${nextB.num} пары: ${rem} мин (начало в ${nextB.start})`;
          return;
        }
      }
    }

    dom.bellBadge.className = 'kiosk-bell-badge';
    dom.bellBadge.textContent = 'ОКОНЧЕНЫ';
    dom.bellText.textContent = 'Все учебные занятия на сегодня завершены';
  }

  // ВКЛАДКИ
  function setupTabs() {
    dom.tabBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        resetIdleTimer();
        hideKeyboard();
        const tabId = btn.getAttribute('data-tab');
        dom.tabBtns.forEach(b => b.classList.remove('active'));
        dom.tabContents.forEach(c => c.classList.remove('active'));

        btn.classList.add('active');
        const target = document.getElementById(tabId);
        if (target) target.classList.add('active');
      });
    });

    if (dom.homeBtn) {
      dom.homeBtn.addEventListener('click', () => {
        resetToHome();
      });
    }
  }

  function resetToHome() {
    resetIdleTimer();
    hideKeyboard();
    closeTeacherModal();
    // Переход на первую вкладку
    dom.tabBtns.forEach((b, idx) => b.classList.toggle('active', idx === 0));
    dom.tabContents.forEach((c, idx) => c.classList.toggle('active', idx === 0));

    // Сброс в группах
    dom.groupsSelector.classList.remove('hidden');
    dom.scheduleView.classList.add('hidden');
    state.selectedGroup = null;

    if (dom.groupSearchInput) dom.groupSearchInput.value = '';
    if (dom.clearGroupSearchBtn) dom.clearGroupSearchBtn.classList.add('hidden');

    state.activeCourseFilter = 'all';
    dom.courseChips.forEach(chip => {
      chip.classList.toggle('active', chip.getAttribute('data-course') === 'all');
    });
    renderGroups();

    // Сброс в преподавателях
    if (dom.teacherSearchInput) dom.teacherSearchInput.value = '';
    if (dom.clearTeacherSearchBtn) dom.clearTeacherSearchBtn.classList.add('hidden');
    renderTeachers();
  }

  // ЗАГРУЗКА И РЕНДЕР ГРУПП
  async function loadGroups() {
    try {
      const res = await fetch('/api/groups');
      if (!res.ok) throw new Error('Ошибка загрузки групп');
      state.groups = await res.json();
      renderGroups();
    } catch (err) {
      console.error('Ошибка групп:', err);
      dom.groupsGrid.innerHTML = '<div class="kiosk-loading-box">Не удалось загрузить список групп</div>';
    }
  }

  function renderGroups() {
    if (!dom.groupsGrid) return;
    const query = (dom.groupSearchInput?.value || '').trim().toLowerCase();

    let filtered = state.groups;

    if (state.activeCourseFilter !== 'all') {
      if (state.activeCourseFilter === 'spo') {
        filtered = filtered.filter(g => g.name.toLowerCase().includes('с') || g.sem > 8);
      } else {
        const cNum = parseInt(state.activeCourseFilter);
        filtered = filtered.filter(g => g.course === cNum);
      }
    }

    if (query) {
      filtered = filtered.filter(g => g.name.toLowerCase().includes(query));
    }

    if (filtered.length === 0) {
      dom.groupsGrid.innerHTML = '<div class="kiosk-loading-box">Группы не найдены</div>';
      return;
    }

    let html = '';
    for (const g of filtered) {
      html += `
        <div class="kiosk-group-tile" data-group-id="${g.id}" data-group-name="${escapeHtml(g.name)}" data-course="${g.course}">
          <span class="kiosk-group-name">${escapeHtml(g.name)}</span>
          <span class="kiosk-group-sem">${g.course} курс (${g.sem} семестр)</span>
        </div>
      `;
    }

    dom.groupsGrid.innerHTML = html;

    // Навешиваем клик на плитки
    dom.groupsGrid.querySelectorAll('.kiosk-group-tile').forEach(tile => {
      tile.addEventListener('click', () => {
        resetIdleTimer();
        const gId = parseInt(tile.getAttribute('data-group-id'));
        const gName = tile.getAttribute('data-group-name');
        const gCourse = tile.getAttribute('data-course');
        openGroupSchedule(gId, gName, gCourse);
      });
    });
  }

  // ФИЛЬТРЫ КУРСОВ И ПОИСК ГРУПП
  function setupGroupFilters() {
    dom.courseChips.forEach(chip => {
      chip.addEventListener('click', () => {
        resetIdleTimer();
        dom.courseChips.forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        state.activeCourseFilter = chip.getAttribute('data-course');
        renderGroups();
      });
    });

    if (dom.clearGroupSearchBtn) {
      dom.clearGroupSearchBtn.addEventListener('click', () => {
        resetIdleTimer();
        dom.groupSearchInput.value = '';
        dom.clearGroupSearchBtn.classList.add('hidden');
        renderGroups();
      });
    }

    if (dom.openGroupKeyboardBtn) {
      dom.openGroupKeyboardBtn.addEventListener('click', () => {
        showKeyboard(dom.groupSearchInput, 'Поиск учебной группы');
      });
    }

    if (dom.groupSearchInput) {
      dom.groupSearchInput.addEventListener('click', () => {
        showKeyboard(dom.groupSearchInput, 'Поиск учебной группы');
      });
    }
  }

  // ПРОСМОТР РАСПИСАНИЯ ГРУППЫ
  async function openGroupSchedule(groupId, groupName, course) {
    state.selectedGroup = { id: groupId, name: groupName, course: course };
    dom.selectedGroupName.textContent = groupName;
    dom.selectedGroupCourse.textContent = `${course} курс`;

    dom.groupsSelector.classList.add('hidden');
    dom.scheduleView.classList.remove('hidden');
    dom.scheduleCards.innerHTML = '<div class="kiosk-loading-box"><div class="kiosk-spinner"></div><span>Загрузка расписания...</span></div>';

    try {
      const res = await fetch(`/api/schedule?group_id=${groupId}`);
      if (!res.ok) throw new Error('Ошибка сети');
      state.groupSchedule = await res.json();

      const siteWeek = parseInt(state.groupSchedule.weekNumber || 1);
      state.currentWeek = siteWeek;

      const rNow = getRubtsovskNow();
      let rDay = (rNow.getDay() + 6) % 7 + 1; // 1 = Пн ... 6 = Сб
      if (rDay > 6) rDay = 1; // Воскресенье переключаем на Понедельник
      state.currentDay = rDay;

      updateWeekButtonsUI();
      updateDaysNavUI();
      renderGroupSchedule();
    } catch (err) {
      console.error('Ошибка загрузки расписания:', err);
      dom.scheduleCards.innerHTML = '<div class="kiosk-loading-box">Не удалось получить расписание группы</div>';
    }
  }

  if (dom.backToGroupsBtn) {
    dom.backToGroupsBtn.addEventListener('click', () => {
      resetIdleTimer();
      dom.scheduleView.classList.add('hidden');
      dom.groupsSelector.classList.remove('hidden');
      state.selectedGroup = null;
    });
  }

  function updateWeekButtonsUI() {
    dom.weekBtn1.classList.toggle('active', state.currentWeek === 1);
    dom.weekBtn2.classList.toggle('active', state.currentWeek === 2);
  }

  dom.weekBtn1.addEventListener('click', () => {
    resetIdleTimer();
    state.currentWeek = 1;
    updateWeekButtonsUI();
    renderGroupSchedule();
  });

  dom.weekBtn2.addEventListener('click', () => {
    resetIdleTimer();
    state.currentWeek = 2;
    updateWeekButtonsUI();
    renderGroupSchedule();
  });

  function updateDaysNavUI() {
    const rNow = getRubtsovskNow();
    const todayDay = (rNow.getDay() + 6) % 7 + 1;

    dom.dayBtns.forEach(btn => {
      const dNum = parseInt(btn.getAttribute('data-day'));
      btn.classList.toggle('active', dNum === state.currentDay);
      btn.classList.toggle('today', dNum === todayDay);
    });
  }

  dom.dayBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      resetIdleTimer();
      state.currentDay = parseInt(btn.getAttribute('data-day'));
      updateDaysNavUI();
      renderGroupSchedule();
    });
  });

  function renderGroupSchedule() {
    if (!state.groupSchedule) return;

    const weekData = state.groupSchedule.scheduleData?.[String(state.currentWeek)] || {};
    const dayData = weekData[String(state.currentDay)] || {};
    const paraTimes = state.groupSchedule.paraTimes || {};

    const sortedParas = Object.keys(dayData).sort((a, b) => parseInt(a) - parseInt(b));

    if (sortedParas.length === 0) {
      dom.scheduleCards.innerHTML = '<div class="kiosk-loading-box">В этот день занятий по расписанию нет</div>';
      return;
    }

    const rNow = getRubtsovskNow();
    const curMins = rNow.getHours() * 60 + rNow.getMinutes();
    const isToday = (
      parseInt(state.groupSchedule.weekNumber || 1) === state.currentWeek &&
      ((rNow.getDay() + 6) % 7 + 1) === state.currentDay
    );

    let html = '';

    for (const pStr of sortedParas) {
      const item = dayData[pStr];
      const pNum = parseInt(pStr);

      // Время пары
      let timeDisplay = '';
      const bDef = BELLS.find(b => b.num === pNum);
      if (bDef) {
        timeDisplay = `${bDef.start} - ${bDef.end}`;
      }

      const isCurrentNow = isToday && bDef && (curMins >= bDef.startMins && curMins < bDef.endMins);
      const activeCardClass = isCurrentNow ? 'active-now' : '';

      if (!item.isDouble) {
        const subj = item.subj || item.subj1 || '';
        const type = item.type || item.type1 || '';
        const aud = item.aud || item.aud1 || '';
        const teacher = item.teacher || item.teacher1 || '';
        const teachPost = item.teachPost || item.teachPost1 || '';

        const typeBadge = type ? `<span class="kiosk-para-type">${escapeHtml(type)}</span>` : '';
        const audBadge = aud ? `<span class="kiosk-para-aud-badge">ауд. ${escapeHtml(aud)}</span>` : '';
        const teacherBtn = teacher ? `
          <button type="button" class="kiosk-para-teacher-chip" data-teacher="${escapeHtml(teacher)}" data-post="${escapeHtml(teachPost)}">
            <svg viewBox="0 0 24 24" width="16" height="16"><path fill="currentColor" d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>
            <span>${escapeHtml(teacher)}${teachPost ? ` (${escapeHtml(teachPost)})` : ''}</span>
          </button>
        ` : '';

        html += `
          <div class="kiosk-para-card ${activeCardClass}">
            <div class="kiosk-para-time-col">
              <span class="kiosk-para-num">${pNum} пара</span>
              <span class="kiosk-para-clock">${escapeHtml(timeDisplay)}</span>
            </div>
            <div class="kiosk-para-info-col">
              <div class="kiosk-para-subj-row">
                <span class="kiosk-para-subj">${escapeHtml(subj)}</span>
                ${typeBadge}
              </div>
              ${teacherBtn}
            </div>
            <div class="kiosk-para-aud-col">
              ${audBadge}
            </div>
          </div>
        `;
      } else {
        // Две подгруппы
        let sgHtml = '';
        for (let sg = 1; sg <= 2; sg++) {
          const subj = item[`subj${sg}`];
          if (!subj) continue;
          const type = item[`type${sg}`] || '';
          const aud = item[`aud${sg}`] || '';
          const teacher = item[`teacher${sg}`] || '';
          const teachPost = item[`teachPost${sg}`] || '';

          const typeTag = type ? `<span class="kiosk-para-type">${escapeHtml(type)}</span>` : '';
          const audTag = aud ? `<span class="kiosk-para-aud-badge" style="font-size: 1rem; padding: 4px 10px;">ауд. ${escapeHtml(aud)}</span>` : '';
          const teacherTag = teacher ? `
            <button type="button" class="kiosk-para-teacher-chip" data-teacher="${escapeHtml(teacher)}" data-post="${escapeHtml(teachPost)}">
              <span>${escapeHtml(teacher)}</span>
            </button>
          ` : '';

          sgHtml += `
            <div class="kiosk-subgroup-row">
              <div>
                <span class="kiosk-subgroup-tag">${sg} п/г:</span>
                <strong>${escapeHtml(subj)}</strong> ${typeTag}
                <div style="margin-top: 4px;">${teacherTag}</div>
              </div>
              <div>${audTag}</div>
            </div>
          `;
        }

        html += `
          <div class="kiosk-para-card ${activeCardClass}">
            <div class="kiosk-para-time-col">
              <span class="kiosk-para-num">${pNum} пара</span>
              <span class="kiosk-para-clock">${escapeHtml(timeDisplay)}</span>
            </div>
            <div class="kiosk-para-info-col">
              <div class="kiosk-subgroups-wrapper">
                ${sgHtml}
              </div>
            </div>
            <div class="kiosk-para-aud-col"></div>
          </div>
        `;
      }
    }

    dom.scheduleCards.innerHTML = html;

    // Навешиваем клик на карточки преподавателей
    dom.scheduleCards.querySelectorAll('.kiosk-para-teacher-chip').forEach(btn => {
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
  async function loadTeachers() {
    try {
      const res = await fetch('/api/teachers');
      if (!res.ok) throw new Error('Ошибка загрузки преподавателей');
      state.teachers = await res.json();
      renderTeachers();
    } catch (err) {
      console.error('Ошибка преподавателей:', err);
      dom.teachersGrid.innerHTML = '<div class="kiosk-loading-box">Не удалось загрузить список преподавателей</div>';
    }
  }

  function renderTeachers() {
    if (!dom.teachersGrid) return;
    const query = (dom.teacherSearchInput?.value || '').trim().toLowerCase();

    let filtered = state.teachers;
    if (query) {
      filtered = filtered.filter(t => 
        (t.full_name && t.full_name.toLowerCase().includes(query)) ||
        (t.short_name && t.short_name.toLowerCase().includes(query)) ||
        (t.department && t.department.toLowerCase().includes(query)) ||
        (t.disciplines && t.disciplines.toLowerCase().includes(query))
      );
    }

    if (filtered.length === 0) {
      dom.teachersGrid.innerHTML = '<div class="kiosk-loading-box">Преподаватели не найдены</div>';
      return;
    }

    let html = '';
    for (const t of filtered) {
      html += `
        <div class="kiosk-teacher-tile" data-teacher-name="${escapeHtml(t.full_name || t.short_name)}" data-post="${escapeHtml(t.post || '')}">
          <div>
            <div class="kiosk-teacher-name">${escapeHtml(t.full_name || t.short_name)}</div>
            <div class="kiosk-teacher-post">${escapeHtml(t.post || 'Преподаватель')}</div>
          </div>
          <div class="kiosk-teacher-dept">${escapeHtml(t.department || 'РИИ АлтГТУ')}</div>
        </div>
      `;
    }

    dom.teachersGrid.innerHTML = html;

    dom.teachersGrid.querySelectorAll('.kiosk-teacher-tile').forEach(tile => {
      tile.addEventListener('click', () => {
        resetIdleTimer();
        const tName = tile.getAttribute('data-teacher-name');
        const tPost = tile.getAttribute('data-post');
        openTeacherModal(tName, tPost);
      });
    });
  }

  function setupTeacherFilters() {
    if (dom.clearTeacherSearchBtn) {
      dom.clearTeacherSearchBtn.addEventListener('click', () => {
        resetIdleTimer();
        dom.teacherSearchInput.value = '';
        dom.clearTeacherSearchBtn.classList.add('hidden');
        renderTeachers();
      });
    }

    if (dom.openTeacherKeyboardBtn) {
      dom.openTeacherKeyboardBtn.addEventListener('click', () => {
        showKeyboard(dom.teacherSearchInput, 'Поиск преподавателя');
      });
    }

    if (dom.teacherSearchInput) {
      dom.teacherSearchInput.addEventListener('click', () => {
        showKeyboard(dom.teacherSearchInput, 'Поиск преподавателя');
      });
    }
  }

  // МОДАЛЬНОЕ ОКНО ПРЕПОДАВАТЕЛЯ С РАСПИСАНИЕМ
  async function openTeacherModal(teacherName, post) {
    if (!dom.teacherModal) return;
    dom.teacherModalName.textContent = teacherName;
    dom.teacherModalPost.textContent = post || 'Преподаватель';
    dom.teacherModalBody.innerHTML = '<div class="kiosk-loading-box"><div class="kiosk-spinner"></div><span>Загрузка профиля и расписания занятий...</span></div>';
    dom.teacherModal.classList.remove('hidden');

    try {
      // Параллельно загружаем информацию о преподавателе и расписание
      const [infoRes, schedRes] = await Promise.all([
        fetch(`/api/teacher?name=${encodeURIComponent(teacherName)}`),
        fetch(`/api/kiosk/teacher-schedule?name=${encodeURIComponent(teacherName)}`)
      ]);

      const infoData = infoRes.ok ? await infoRes.json() : {};
      const schedData = schedRes.ok ? await schedRes.json() : {};

      renderTeacherModalContent(infoData, schedData, teacherName, post);
    } catch (err) {
      console.error('Ошибка загрузки данных преподавателя:', err);
      dom.teacherModalBody.innerHTML = '<div class="kiosk-loading-box">Не удалось загрузить данные преподавателя</div>';
    }
  }

  function renderTeacherModalContent(info, schedObj, teacherName, post) {
    const fullName = info.full_name || teacherName;
    const finalPost = info.post || post || 'Преподаватель';
    const dept = info.department || 'Рубцовский индустриальный институт';
    const disc = info.disciplines || '';
    const email = info.email || '';
    const phone = info.phone || '';

    let detailsHtml = `
      <div style="background: rgba(255,255,255,0.04); border-radius: 12px; padding: 16px; margin-bottom: 20px;">
        <div style="font-size: 1.1rem; font-weight: 700; color: #fff; margin-bottom: 6px;">${escapeHtml(fullName)}</div>
        <div style="color: var(--accent-cyan); font-weight: 600; margin-bottom: 8px;">${escapeHtml(finalPost)} - ${escapeHtml(dept)}</div>
        ${disc ? `<div style="color: var(--text-secondary); font-size: 0.95rem; margin-bottom: 6px;"><strong>Дисциплины:</strong> ${escapeHtml(disc)}</div>` : ''}
        ${email ? `<div style="color: var(--text-secondary); font-size: 0.95rem;"><strong>Email:</strong> ${escapeHtml(email)}</div>` : ''}
        ${phone ? `<div style="color: var(--text-secondary); font-size: 0.95rem;"><strong>Телефон:</strong> ${escapeHtml(phone)}</div>` : ''}
      </div>
    `;

    // Расписание занятий преподавателя
    let schedHtml = '<h4 style="font-size: 1.2rem; font-weight: 800; color: #fff; margin-bottom: 12px;">Расписание занятий преподавателя</h4>';

    const sched = schedObj.schedule;
    if (!sched) {
      schedHtml += '<div style="color: var(--text-muted);">Занятия преподавателя не найдены в базе</div>';
    } else {
      schedHtml += `
        <div style="display: flex; gap: 8px; margin-bottom: 14px;">
          <button type="button" class="kiosk-week-btn active" id="tModalWeek1" style="background: var(--accent-cyan); color: #0b1120;">1: Числитель</button>
          <button type="button" class="kiosk-week-btn" id="tModalWeek2" style="background: rgba(255,255,255,0.06); color: var(--text-secondary);">2: Знаменатель</button>
        </div>
        <div id="tModalSchedList"></div>
      `;
    }

    dom.teacherModalBody.innerHTML = detailsHtml + schedHtml;

    if (sched) {
      let tWeek = 1;
      const renderTeacherWeek = (w) => {
        const listEl = document.getElementById('tModalSchedList');
        if (!listEl) return;
        const wData = sched[String(w)] || {};
        let dayBlocks = '';

        for (let d = 1; d <= 6; d++) {
          const dayParas = wData[String(d)] || [];
          if (dayParas.length === 0) continue;

          let parasList = '';
          for (const p of dayParas) {
            parasList += `
              <div style="display: flex; align-items: center; justify-content: space-between; background: rgba(255,255,255,0.03); padding: 8px 12px; border-radius: 8px; margin-bottom: 6px;">
                <div>
                  <strong>${p.num} пара (${escapeHtml(p.time)})</strong>: ${escapeHtml(p.subject)} (${escapeHtml(p.type || '')})
                  <span style="color: var(--accent-cyan); font-weight: 700; margin-left: 8px;">Группа: ${escapeHtml(p.group)}</span>
                </div>
                <div>
                  ${p.aud ? `<span class="kiosk-para-aud-badge" style="font-size: 0.9rem; padding: 3px 8px;">ауд. ${escapeHtml(p.aud)}</span>` : ''}
                </div>
              </div>
            `;
          }

          dayBlocks += `
            <div style="margin-bottom: 14px;">
              <div style="color: var(--accent-cyan); font-weight: 800; font-size: 1rem; margin-bottom: 6px;">${DAYS_RU[d-1]}</div>
              ${parasList}
            </div>
          `;
        }

        listEl.innerHTML = dayBlocks || '<div style="color: var(--text-muted); padding: 10px;">В эту неделю занятий нет</div>';
      };

      renderTeacherWeek(1);

      const w1Btn = document.getElementById('tModalWeek1');
      const w2Btn = document.getElementById('tModalWeek2');
      if (w1Btn && w2Btn) {
        w1Btn.addEventListener('click', () => {
          tWeek = 1;
          w1Btn.style.background = 'var(--accent-cyan)';
          w1Btn.style.color = '#0b1120';
          w2Btn.style.background = 'rgba(255,255,255,0.06)';
          w2Btn.style.color = 'var(--text-secondary)';
          renderTeacherWeek(1);
        });
        w2Btn.addEventListener('click', () => {
          tWeek = 2;
          w2Btn.style.background = 'var(--accent-cyan)';
          w2Btn.style.color = '#0b1120';
          w1Btn.style.background = 'rgba(255,255,255,0.06)';
          w1Btn.style.color = 'var(--text-secondary)';
          renderTeacherWeek(2);
        });
      }
    }
  }

  function closeTeacherModal() {
    if (dom.teacherModal) {
      dom.teacherModal.classList.add('hidden');
    }
  }

  if (dom.closeTeacherModalBtn) {
    dom.closeTeacherModalBtn.addEventListener('click', closeTeacherModal);
  }

  // ТАБЛИЦА ЗВОНКОВ
  function renderBellsTable() {
    if (!dom.bellsTableBody) return;
    const rNow = getRubtsovskNow();
    const curMins = rNow.getHours() * 60 + rNow.getMinutes();

    let rows = '';
    for (const b of BELLS) {
      const isCurrent = (curMins >= b.startMins && curMins < b.endMins);
      const activeClass = isCurrent ? 'active-row' : '';
      const statusText = isCurrent ? 'ИДЕТ СЕЙЧАС' : '';
      const breakText = b.breakMins > 0 ? `${b.breakMins} мин` : 'Окончание пар';

      rows += `
        <tr class="${activeClass}">
          <td><strong>${b.num} пара</strong></td>
          <td>${b.start} - ${b.end}</td>
          <td>${breakText}</td>
          <td><span style="color: var(--accent-green); font-weight: 800;">${statusText}</span></td>
        </tr>
      `;
    }

    dom.bellsTableBody.innerHTML = rows;
  }

  // ЭКРАННАЯ ВИРТУАЛЬНАЯ КЛАВИАТУРА
  function showKeyboard(targetInput, label) {
    state.activeKeyboardTarget = targetInput;
    if (dom.keyboardTargetLabel) dom.keyboardTargetLabel.textContent = label || 'Ввод текста';
    if (dom.keyboardPanel) dom.keyboardPanel.classList.remove('hidden');
  }

  function hideKeyboard() {
    state.activeKeyboardTarget = null;
    if (dom.keyboardPanel) dom.keyboardPanel.classList.add('hidden');
  }

  function setupKeyboard() {
    if (dom.closeKeyboardBtn) {
      dom.closeKeyboardBtn.addEventListener('click', hideKeyboard);
    }

    // Обработка клавиш букв и цифр
    document.querySelectorAll('.kiosk-key[data-char]').forEach(key => {
      key.addEventListener('click', () => {
        resetIdleTimer();
        if (!state.activeKeyboardTarget) return;
        const char = key.getAttribute('data-char');
        state.activeKeyboardTarget.value += char;
        triggerInputChange(state.activeKeyboardTarget);
      });
    });

    if (dom.keyBackspace) {
      dom.keyBackspace.addEventListener('click', () => {
        resetIdleTimer();
        if (!state.activeKeyboardTarget) return;
        state.activeKeyboardTarget.value = state.activeKeyboardTarget.value.slice(0, -1);
        triggerInputChange(state.activeKeyboardTarget);
      });
    }

    if (dom.keySpace) {
      dom.keySpace.addEventListener('click', () => {
        resetIdleTimer();
        if (!state.activeKeyboardTarget) return;
        state.activeKeyboardTarget.value += ' ';
        triggerInputChange(state.activeKeyboardTarget);
      });
    }

    if (dom.keyClear) {
      dom.keyClear.addEventListener('click', () => {
        resetIdleTimer();
        if (!state.activeKeyboardTarget) return;
        state.activeKeyboardTarget.value = '';
        triggerInputChange(state.activeKeyboardTarget);
      });
    }
  }

  function triggerInputChange(inputEl) {
    if (inputEl === dom.groupSearchInput) {
      if (dom.clearGroupSearchBtn) {
        dom.clearGroupSearchBtn.classList.toggle('hidden', !inputEl.value);
      }
      renderGroups();
    } else if (inputEl === dom.teacherSearchInput) {
      if (dom.clearTeacherSearchBtn) {
        dom.clearTeacherSearchBtn.classList.toggle('hidden', !inputEl.value);
      }
      renderTeachers();
    }
  }

  // ТАЙМЕР БЕЗДЕЙСТВИЯ (60 СЕК + 10 СЕК ПРЕДУПРЕЖДЕНИЕ)
  function resetIdleTimer() {
    if (state.idleTimer) clearTimeout(state.idleTimer);
    if (state.idleWarningTimer) clearInterval(state.idleWarningTimer);

    if (state.isIdleWarningOpen) {
      state.isIdleWarningOpen = false;
      if (dom.idleOverlay) dom.idleOverlay.classList.add('hidden');
    }

    state.idleTimer = setTimeout(() => {
      showIdleWarning();
    }, 60000); // 60 секунд бездействия
  }

  function showIdleWarning() {
    state.isIdleWarningOpen = true;
    state.idleCountdownValue = 10;
    if (dom.idleCountdown) dom.idleCountdown.textContent = state.idleCountdownValue;
    if (dom.idleOverlay) dom.idleOverlay.classList.remove('hidden');

    state.idleWarningTimer = setInterval(() => {
      state.idleCountdownValue -= 1;
      if (dom.idleCountdown) dom.idleCountdown.textContent = state.idleCountdownValue;
      if (state.idleCountdownValue <= 0) {
        clearInterval(state.idleWarningTimer);
        resetToHome();
      }
    }, 1000);
  }

  if (dom.idleContinueBtn) {
    dom.idleContinueBtn.addEventListener('click', () => {
      resetIdleTimer();
    });
  }

  // Сброс таймера при любом касании / клике на экран
  ['touchstart', 'mousedown', 'pointerdown'].forEach(evtName => {
    window.addEventListener(evtName, () => {
      resetIdleTimer();
    }, { passive: true });
  });

  // ИНИЦИАЛИЗАЦИЯ
  function init() {
    tickClock();
    setInterval(tickClock, 1000);

    setupTabs();
    setupGroupFilters();
    setupTeacherFilters();
    setupKeyboard();
    renderBellsTable();

    loadGroups();
    loadTeachers();

    resetIdleTimer();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
