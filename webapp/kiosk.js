// ========================================================
// СЕНСОРНЫЙ ТЕРМИНАЛ РАСПИСАНИЯ РИИ АЛТГТУ (KIOSK.JS)
// Каноничный дизайн Telegram Mini App + адаптивный терминал
// ========================================================

(function () {
  'use strict';

  const SESSION_MAX_SECONDS = 120; // 2 минуты таймер сессии
  let sessionRemainingSeconds = SESSION_MAX_SECONDS;
  let sessionTimerInterval = null;
  let liveClockInterval = null;
  let liveBoardPollingInterval = null;

  // Состояние киоска
  const state = {
    currentScreen: 'welcome', // 'welcome' | 'groupSelect' | 'schedule'
    allGroups: [],
    selectedCourse: 'all', // 'all' | '1' | '2' | '3' | '4' | 'spo' | 'vo'
    selectedTag: 'all',    // 'all' | 'ИВТ' | 'ИСП' | 'ЭиЭ' | 'ЭС' | 'ЭБУ' | 'КТМ' | 'С' | 'РУП'
    searchQuery: '',
    selectedGroupId: null,
    selectedGroupName: '',
    scheduleData: null,
    selectedWeek: 1,
    selectedDay: 1,
    selectedSubgroup: 0, // 0 - все, 1 - 1 п/г, 2 - 2 п/г
    bellStatus: null
  };

  // Элементы DOM (инициализируются в initDom)
  let dom = {};

  function initDom() {
    dom = {
      // Экраны
      screenWelcome: document.getElementById('screenWelcome'),
      screenGroupSelect: document.getElementById('screenGroupSelect'),
      screenSchedule: document.getElementById('screenSchedule'),

      // Экран 1 (Заставка)
      welcomeClock: document.getElementById('welcomeClock'),
      welcomeDate: document.getElementById('welcomeDate'),
      welcomeWeatherCard: document.getElementById('welcomeWeatherCard'),
      welcomeWeatherIcon: document.getElementById('welcomeWeatherIcon'),
      welcomeWeatherTemp: document.getElementById('welcomeWeatherTemp'),
      welcomeWeatherDesc: document.getElementById('welcomeWeatherDesc'),
      welcomeBellTitle: document.getElementById('welcomeBellTitle'),
      welcomeBellCountdown: document.getElementById('welcomeBellCountdown'),
      welcomeBellProgressBar: document.getElementById('welcomeBellProgressBar'),
      welcomeWeekPill: document.getElementById('welcomeWeekPill'),
      startKioskBtn: document.getElementById('startKioskBtn'),

      // Шапка активной сессии
      btnBackToWelcome: document.getElementById('btnBackToWelcome'),
      kioskSessionTimerBadge: document.getElementById('kioskSessionTimerBadge'),
      kioskSessionTimeVal: document.getElementById('kioskSessionTimeVal'),
      btnFinishSession1: document.getElementById('btnFinishSession1'),

      kioskSessionTimerBadge2: document.getElementById('kioskSessionTimerBadge2'),
      kioskSessionTimeVal2: document.getElementById('kioskSessionTimeVal2'),
      btnFinishSession2: document.getElementById('btnFinishSession2'),
      btnBackToGroups: document.getElementById('btnBackToGroups'),
      kioskSelectedGroupName: document.getElementById('kioskSelectedGroupName'),

      // Экран 2 (Группы)
      kioskCourseTabs: document.getElementById('kioskCourseTabs'),
      kioskGroupSearch: document.getElementById('kioskGroupSearch'),
      btnClearSearch: document.getElementById('btnClearSearch'),
      kioskQuickTags: document.getElementById('kioskQuickTags'),
      kioskGroupsGrid: document.getElementById('kioskGroupsGrid'),
      kioskNoGroupsFound: document.getElementById('kioskNoGroupsFound'),

      // Экран 3 (Расписание)
      kioskWeek1Btn: document.getElementById('kioskWeek1Btn'),
      kioskWeek2Btn: document.getElementById('kioskWeek2Btn'),
      kioskDaysNav: document.getElementById('kioskDaysNav'),
      subgroupBtns: document.querySelectorAll('.kiosk-sg-btn'),
      kioskLiveStatusBar: document.getElementById('kioskLiveStatusBar'),
      kioskLiveStatusText: document.getElementById('kioskLiveStatusText'),
      kioskScheduleCards: document.getElementById('kioskScheduleCards'),
      kioskScheduleEmpty: document.getElementById('kioskScheduleEmpty'),
      kioskScheduleLoading: document.getElementById('kioskScheduleLoading'),

      // Модалка преподавателя
      kioskTeacherModal: document.getElementById('kioskTeacherModal'),
      btnCloseTeacherModal: document.getElementById('btnCloseTeacherModal'),
      btnCloseTeacherBottom: document.getElementById('btnCloseTeacherBottom'),
      kioskTeacherLoading: document.getElementById('kioskTeacherLoading'),
      kioskTeacherContent: document.getElementById('kioskTeacherContent'),
      ktPhoto: document.getElementById('ktPhoto'),
      ktAvatarFallback: document.getElementById('ktAvatarFallback'),
      ktFullName: document.getElementById('ktFullName'),
      ktPost: document.getElementById('ktPost'),
      ktDept: document.getElementById('ktDept'),
      ktRoomRow: document.getElementById('ktRoomRow'),
      ktRoom: document.getElementById('ktRoom'),
      ktDegreeRow: document.getElementById('ktDegreeRow'),
      ktDegree: document.getElementById('ktDegree'),
      ktPhoneRow: document.getElementById('ktPhoneRow'),
      ktPhone: document.getElementById('ktPhone'),
      ktEmailRow: document.getElementById('ktEmailRow'),
      ktEmail: document.getElementById('ktEmail'),
      ktDisciplinesRow: document.getElementById('ktDisciplinesRow'),
      ktDisciplines: document.getElementById('ktDisciplines')
    };
  }

  // Вспомогательная функция времени в Рубцовске (UTC+7)
  function getRubtsovskDate() {
    const now = new Date();
    const utc = now.getTime() + now.getTimezoneOffset() * 60000;
    return new Date(utc + 7 * 3600000);
  }

  function formatTime(seconds) {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
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

  // Классификация групп института (34 группы)
  function isSpoGroup(groupName) {
    if (!groupName) return false;
    const u = groupName.toUpperCase();
    return u.includes('9-') || u.includes('11-') ||
           u.startsWith('ИСП') || u.startsWith('РУП') ||
           u.startsWith('ЭБУ') || u.startsWith('ЭС');
  }

  function getGroupFacultyName(groupName) {
    if (isSpoGroup(groupName)) {
      return 'Колледж (СПО)';
    }
    return 'Высшее образование (ВО)';
  }

  function getGroupSpecialtyTag(groupName) {
    if (!groupName) return '';
    const u = groupName.toUpperCase();
    if (u.startsWith('ИВТ')) return 'ИВТ';
    if (u.startsWith('ИСП')) return 'ИСП';
    if (u.startsWith('ЭИЭ')) return 'ЭиЭ';
    if (u.startsWith('ЭС')) return 'ЭС';
    if (u.startsWith('ЭБУ')) return 'ЭБУ';
    if (u.startsWith('КТМ')) return 'КТМ';
    if (u.startsWith('С-')) return 'С';
    if (u.startsWith('РУП')) return 'РУП';
    return '';
  }

  // ========================================================
  // УПРАВЛЕНИЕ ЭКРАНАМИ И СЕССИЕЙ (2 МИНУТЫ)
  // ========================================================
  function showScreen(screenName) {
    state.currentScreen = screenName;

    dom.screenWelcome?.classList.add('hidden');
    dom.screenWelcome?.classList.remove('active');
    dom.screenGroupSelect?.classList.add('hidden');
    dom.screenGroupSelect?.classList.remove('active');
    dom.screenSchedule?.classList.add('hidden');
    dom.screenSchedule?.classList.remove('active');

    if (screenName === 'welcome') {
      dom.screenWelcome?.classList.remove('hidden');
      dom.screenWelcome?.classList.add('active');
      stopSessionTimer();
    } else if (screenName === 'groupSelect') {
      dom.screenGroupSelect?.classList.remove('hidden');
      dom.screenGroupSelect?.classList.add('active');
      startOrResetSessionTimer();
      renderGroupsList();
    } else if (screenName === 'schedule') {
      dom.screenSchedule?.classList.remove('hidden');
      dom.screenSchedule?.classList.add('active');
      startOrResetSessionTimer();
    }
  }

  function startOrResetSessionTimer() {
    sessionRemainingSeconds = SESSION_MAX_SECONDS;
    updateSessionTimerDisplay();

    if (!sessionTimerInterval) {
      sessionTimerInterval = setInterval(() => {
        sessionRemainingSeconds--;
        updateSessionTimerDisplay();

        if (sessionRemainingSeconds <= 0) {
          finishSession();
        }
      }, 1000);
    }
  }

  function updateSessionTimerDisplay() {
    const timeStr = formatTime(Math.max(0, sessionRemainingSeconds));
    if (dom.kioskSessionTimeVal) dom.kioskSessionTimeVal.textContent = timeStr;
    if (dom.kioskSessionTimeVal2) dom.kioskSessionTimeVal2.textContent = timeStr;

    const isWarning = sessionRemainingSeconds <= 20;
    if (dom.kioskSessionTimerBadge) {
      dom.kioskSessionTimerBadge.classList.toggle('warning', isWarning);
    }
    if (dom.kioskSessionTimerBadge2) {
      dom.kioskSessionTimerBadge2.classList.toggle('warning', isWarning);
    }
  }

  function stopSessionTimer() {
    if (sessionTimerInterval) {
      clearInterval(sessionTimerInterval);
      sessionTimerInterval = null;
    }
    sessionRemainingSeconds = SESSION_MAX_SECONDS;
    updateSessionTimerDisplay();
  }

  function finishSession() {
    stopSessionTimer();
    closeTeacherModal();
    state.selectedGroupId = null;
    state.selectedGroupName = '';
    state.searchQuery = '';
    if (dom.kioskGroupSearch) dom.kioskGroupSearch.value = '';
    if (dom.btnClearSearch) dom.btnClearSearch.classList.add('hidden');
    state.selectedCourse = 'all';
    state.selectedTag = 'all';
    updateCourseTabsUI();
    updateQuickTagsUI();
    showScreen('welcome');
  }

  // Любая активность пользователя на экране продлевает сессию до 2 минут
  function handleUserActivity() {
    if (state.currentScreen === 'groupSelect' || state.currentScreen === 'schedule') {
      sessionRemainingSeconds = SESSION_MAX_SECONDS;
      updateSessionTimerDisplay();
    }
  }

  window.addEventListener('pointerdown', handleUserActivity, { passive: true });
  window.addEventListener('touchstart', handleUserActivity, { passive: true });
  window.addEventListener('scroll', handleUserActivity, { passive: true });
  window.addEventListener('keydown', handleUserActivity, { passive: true });

  // ========================================================
  // ЭКРАН 1: ЖИВЫЕ ЧАСЫ, ЗВОНКИ И ПОГОДА В РУБЦОВСКЕ
  // ========================================================
  function updateLiveClock() {
    const rDate = getRubtsovskDate();
    const h = String(rDate.getHours()).padStart(2, '0');
    const m = String(rDate.getMinutes()).padStart(2, '0');
    const s = String(rDate.getSeconds()).padStart(2, '0');
    if (dom.welcomeClock) dom.welcomeClock.textContent = `${h}:${m}:${s}`;

    const days = ['Воскресенье', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];
    const months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    const dayName = days[rDate.getDay()];
    const dateFormatted = `${rDate.getDate()} ${months[rDate.getMonth()]} ${rDate.getFullYear()} г., ${dayName}`;
    if (dom.welcomeDate) dom.welcomeDate.textContent = dateFormatted;
  }

  async function fetchLiveBoardData() {
    try {
      const res = await fetch('/api/kiosk/live-board');
      if (!res.ok) return;
      const data = await res.json();

      // Статус звонка
      if (data.bell_status) {
        state.bellStatus = data.bell_status;
        if (dom.welcomeBellTitle) dom.welcomeBellTitle.textContent = data.bell_status.label || 'Учебный процесс';
        if (dom.welcomeBellCountdown) dom.welcomeBellCountdown.textContent = data.bell_status.remaining_str || '--:--';
        if (dom.welcomeBellProgressBar) {
          dom.welcomeBellProgressBar.style.width = `${data.bell_status.progress_percent || 0}%`;
        }
      }

      // Неделя
      if (dom.welcomeWeekPill && data.week_number) {
        dom.welcomeWeekPill.textContent = `${data.week_number} неделя (${data.week_name || 'числитель'})`;
      }

      // Погода в Рубцовске
      if (data.weather) {
        const w = data.weather;
        if (dom.welcomeWeatherTemp) dom.welcomeWeatherTemp.textContent = w.temp || '--°C';
        if (dom.welcomeWeatherDesc) dom.welcomeWeatherDesc.textContent = `Рубцовск: ${w.description || 'Ясно'}`;

        if (dom.welcomeWeatherIcon && w.icon) {
          if (w.icon === 'cloud' || w.icon === 'cloud-sun') {
            dom.welcomeWeatherIcon.innerHTML = '<svg viewBox="0 0 24 24" width="26" height="26"><path fill="currentColor" d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96z"/></svg>';
          } else if (w.icon === 'rain') {
            dom.welcomeWeatherIcon.innerHTML = '<svg viewBox="0 0 24 24" width="26" height="26"><path fill="currentColor" d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM10 21v2h-2v-2h2zm4 0v2h-2v-2h2zm4 0v2h-2v-2h2z"/></svg>';
          } else if (w.icon === 'snow') {
            dom.welcomeWeatherIcon.innerHTML = '<svg viewBox="0 0 24 24" width="26" height="26"><path fill="currentColor" d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM8 21h2v2H8v-2zm6 0h2v2h-2v-2z"/></svg>';
          }
        }
      }
    } catch (e) {
      console.warn('Ошибка загрузки данных live-board:', e);
    }
  }

  // ========================================================
  // ЭКРАН 2: СПИСОК ГРУПП И ПОИСК (ВСЕ 34 ГРУППЫ РИИ)
  // ========================================================
  async function loadAllGroups() {
    try {
      const res = await fetch('/api/groups');
      if (!res.ok) throw new Error('Ошибка загрузки групп');
      state.allGroups = await res.json();
      renderGroupsList();
    } catch (e) {
      console.error('Не удалось загрузить группы:', e);
      if (dom.kioskGroupsGrid) {
        dom.kioskGroupsGrid.innerHTML = '<div class="kiosk-no-data"><p class="no-data-title">Ошибка связи</p><p class="no-data-sub">Не удалось получить список групп с сервера института</p></div>';
      }
    }
  }

  function updateCourseTabsUI() {
    const tabs = dom.kioskCourseTabs?.querySelectorAll('.course-tab');
    if (!tabs) return;
    tabs.forEach(tab => {
      const c = tab.dataset.course;
      tab.classList.toggle('active', c === state.selectedCourse);
    });
  }

  function updateQuickTagsUI() {
    const tags = dom.kioskQuickTags?.querySelectorAll('.quick-tag');
    if (!tags) return;
    tags.forEach(btn => {
      const t = btn.dataset.tag;
      btn.classList.toggle('active', t === state.selectedTag);
    });
  }

  function renderGroupsList() {
    if (!dom.kioskGroupsGrid) return;

    let filtered = state.allGroups || [];

    // 1. Фильтр по курсу / уровню образования
    if (state.selectedCourse !== 'all') {
      if (state.selectedCourse === 'spo') {
        filtered = filtered.filter(g => isSpoGroup(g.name));
      } else if (state.selectedCourse === 'vo') {
        filtered = filtered.filter(g => !isSpoGroup(g.name));
      } else {
        const cNum = parseInt(state.selectedCourse);
        filtered = filtered.filter(g => parseInt(g.course || 0) === cNum);
      }
    }

    // 2. Фильтр по тегу специальности
    if (state.selectedTag !== 'all') {
      filtered = filtered.filter(g => getGroupSpecialtyTag(g.name) === state.selectedTag);
    }

    // 3. Умный поиск (без учета регистра, дефисов и пробелов)
    if (state.searchQuery.trim()) {
      const qNorm = state.searchQuery.trim().toLowerCase().replace(/[\s\-_]/g, '');
      filtered = filtered.filter(g => {
        const gNorm = (g.name || '').toLowerCase().replace(/[\s\-_]/g, '');
        return gNorm.includes(qNorm);
      });
    }

    if (filtered.length === 0) {
      dom.kioskGroupsGrid.innerHTML = '';
      if (dom.kioskNoGroupsFound) dom.kioskNoGroupsFound.classList.remove('hidden');
      return;
    }

    if (dom.kioskNoGroupsFound) dom.kioskNoGroupsFound.classList.add('hidden');

    dom.kioskGroupsGrid.innerHTML = filtered.map(group => {
      const courseStr = group.course ? `${group.course} курс` : 'ВПО / СПО';
      const facStr = getGroupFacultyName(group.name);
      return `
        <div class="kiosk-group-card" data-group-id="${group.id}" data-group-name="${escapeHtml(group.name)}">
          <div class="kgc-header">
            <span class="kgc-name">${escapeHtml(group.name)}</span>
            <span class="kgc-course-badge">${courseStr}</span>
          </div>
          <div class="kgc-meta">
            <span class="kgc-faculty">${facStr}</span>
            <span class="kgc-arrow">
              <svg viewBox="0 0 24 24" width="20" height="20"><path fill="currentColor" d="M8.59 16.59L13.17 12 8.59 7.41 10 6l6 6-6 6-1.41-1.41z"/></svg>
            </span>
          </div>
        </div>
      `;
    }).join('');

    // Обработчики сенсорного нажатия на карточку группы
    dom.kioskGroupsGrid.querySelectorAll('.kiosk-group-card').forEach(card => {
      card.addEventListener('click', () => {
        const gid = parseInt(card.dataset.groupId);
        const gname = card.dataset.groupName;
        selectGroupAndOpenSchedule(gid, gname);
      });
    });
  }

  function selectGroupAndOpenSchedule(groupId, groupName) {
    state.selectedGroupId = groupId;
    state.selectedGroupName = groupName;
    if (dom.kioskSelectedGroupName) dom.kioskSelectedGroupName.textContent = groupName;
    showScreen('schedule');
    loadGroupSchedule(groupId);
  }

  // ========================================================
  // ЭКРАН 3: РАСПИСАНИЕ И КАРТОЧКИ ПАР (КАНОНИЧНЫЙ ДИЗАЙН)
  // ========================================================
  function parseParaTime(timeStr, defaultParaNum = 1) {
    const defaultTimes = {
      1: { s: 8 * 60 + 30, e: 10 * 60 + 0, sStr: "08:30", eStr: "10:00" },
      2: { s: 10 * 60 + 10, e: 11 * 60 + 40, sStr: "10:10", eStr: "11:40" },
      3: { s: 12 * 60 + 10, e: 13 * 60 + 40, sStr: "12:10", eStr: "13:40" },
      4: { s: 13 * 60 + 50, e: 15 * 60 + 20, sStr: "13:50", eStr: "15:20" },
      5: { s: 15 * 60 + 30, e: 17 * 60 + 0, sStr: "15:30", eStr: "17:00" },
      6: { s: 17 * 60 + 10, e: 18 * 60 + 40, sStr: "17:10", eStr: "18:40" },
      7: { s: 18 * 60 + 50, e: 20 * 60 + 20, sStr: "18:50", eStr: "20:20" }
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

  function renderTeacherChipHtml(teacher, post) {
    if (!teacher) return '';
    const cleanTeacher = teacher.trim();
    const cleanPost = (post || '').trim();
    const postDisplay = cleanPost ? ` (${cleanPost})` : '';
    return `<button type="button" class="teacher-btn-chip" data-teacher="${escapeAttr(cleanTeacher)}" data-post="${escapeAttr(cleanPost)}" title="Информация о преподавателе">
      <svg class="teacher-icon" viewBox="0 0 24 24" width="16" height="16"><path fill="currentColor" d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>
      <span class="teacher-name">${escapeHtml(cleanTeacher)}</span>${postDisplay ? `<span class="teacher-post-hint">${escapeHtml(postDisplay)}</span>` : ''}
      <svg class="teacher-arrow" viewBox="0 0 24 24" width="14" height="14"><path fill="currentColor" d="M8.59 16.59L13.17 12 8.59 7.41 10 6l6 6-6 6-1.41-1.41z"/></svg>
    </button>`;
  }

  async function loadGroupSchedule(groupId) {
    if (!groupId) return;

    if (dom.kioskScheduleLoading) dom.kioskScheduleLoading.classList.remove('hidden');
    if (dom.kioskScheduleEmpty) dom.kioskScheduleEmpty.classList.add('hidden');
    if (dom.kioskScheduleCards) dom.kioskScheduleCards.innerHTML = '';
    if (dom.kioskLiveStatusBar) dom.kioskLiveStatusBar.classList.add('hidden');

    try {
      const res = await fetch(`/api/schedule?group_id=${groupId}`);
      if (!res.ok) throw new Error('Ошибка сети');
      state.scheduleData = await res.json();

      const siteWeek = parseInt(state.scheduleData.weekNumber || 1);
      state.selectedWeek = siteWeek;

      const rDate = getRubtsovskDate();
      let rDay = rDate.getDay();
      if (rDay === 0) rDay = 7;
      state.selectedDay = rDay > 6 ? 1 : rDay;

      updateScheduleControlsUI();
      renderScheduleCards();
    } catch (e) {
      console.error('Ошибка загрузки расписания группы:', e);
      if (dom.kioskScheduleLoading) dom.kioskScheduleLoading.classList.add('hidden');
      if (dom.kioskScheduleEmpty) dom.kioskScheduleEmpty.classList.remove('hidden');
    }
  }

  function updateScheduleControlsUI() {
    // Кнопки недели
    if (dom.kioskWeek1Btn) dom.kioskWeek1Btn.classList.toggle('active', state.selectedWeek === 1);
    if (dom.kioskWeek2Btn) dom.kioskWeek2Btn.classList.toggle('active', state.selectedWeek === 2);

    // Кнопки дней
    const dayChips = dom.kioskDaysNav?.querySelectorAll('.kiosk-day-chip');
    if (dayChips) {
      dayChips.forEach(chip => {
        const d = parseInt(chip.dataset.day);
        chip.classList.toggle('active', d === state.selectedDay);
      });
    }

    // Кнопки подгруппы
    dom.subgroupBtns?.forEach(btn => {
      const sg = parseInt(btn.dataset.sg);
      btn.classList.toggle('active', sg === state.selectedSubgroup);
    });

    // Даты на кнопках дней
    calculateAndSetDayDates();
  }

  function calculateAndSetDayDates() {
    const rDate = getRubtsovskDate();
    const currentDayOfWeek = rDate.getDay() === 0 ? 7 : rDate.getDay();
    const monday = new Date(rDate);
    monday.setDate(rDate.getDate() - (currentDayOfWeek - 1));

    for (let i = 1; i <= 6; i++) {
      const d = new Date(monday);
      d.setDate(monday.getDate() + (i - 1));
      const el = document.getElementById(`kdcDate${i}`);
      if (el) {
        const dayStr = String(d.getDate()).padStart(2, '0');
        const mStr = String(d.getMonth() + 1).padStart(2, '0');
        el.textContent = `${dayStr}.${mStr}`;
      }
    }
  }

  function renderScheduleCards() {
    if (!dom.kioskScheduleCards) return;

    if (dom.kioskScheduleLoading) dom.kioskScheduleLoading.classList.add('hidden');

    if (!state.scheduleData || !state.scheduleData.scheduleData) {
      if (dom.kioskScheduleEmpty) dom.kioskScheduleEmpty.classList.remove('hidden');
      if (dom.kioskLiveStatusBar) dom.kioskLiveStatusBar.classList.add('hidden');
      return;
    }

    const weekData = state.scheduleData.scheduleData[String(state.selectedWeek)] || {};
    const dayData = weekData[String(state.selectedDay)] || {};
    const paraTimes = state.scheduleData.paraTimes || {};

    const rDate = getRubtsovskDate();
    let rDay = rDate.getDay();
    if (rDay === 0) rDay = 7;
    const siteWeek = parseInt(state.scheduleData.weekNumber || 1);
    const isToday = (state.selectedWeek === siteWeek && state.selectedDay === rDay);
    const curMins = rDate.getHours() * 60 + rDate.getMinutes();

    const sortedParas = Object.keys(dayData).sort((a, b) => parseInt(a) - parseInt(b));

    // Фильтрация пар с учетом подгрупп
    const visibleParas = [];
    for (const pStr of sortedParas) {
      const item = dayData[pStr];
      if (!item) continue;
      if (item.isDouble) {
        const hasSub1 = (state.selectedSubgroup === 0 || state.selectedSubgroup === 1) && (item.subj1 || item.aud1);
        const hasSub2 = (state.selectedSubgroup === 0 || state.selectedSubgroup === 2) && (item.subj2 || item.aud2);
        if (hasSub1 || hasSub2) {
          visibleParas.push(pStr);
        }
      } else {
        if (item.subj1 || item.aud1 || item.teacher1) {
          visibleParas.push(pStr);
        }
      }
    }

    if (visibleParas.length === 0) {
      dom.kioskScheduleCards.innerHTML = '';
      if (dom.kioskScheduleEmpty) dom.kioskScheduleEmpty.classList.remove('hidden');
      if (dom.kioskLiveStatusBar) dom.kioskLiveStatusBar.classList.add('hidden');
      return;
    }

    if (dom.kioskScheduleEmpty) dom.kioskScheduleEmpty.classList.add('hidden');

    // Расчет статусной строки для сегодняшнего дня
    if (isToday) {
      let ongoingPara = null;
      let nextPara = null;

      for (const pStr of visibleParas) {
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
        dom.kioskLiveStatusText.textContent = `Идет ${ongoingPara.pN} пара (до ${ongoingPara.eStr}, осталось ${ongoingPara.rem} мин)`;
        dom.kioskLiveStatusBar.classList.remove('hidden');
      } else if (nextPara) {
        const firstPN = parseInt(visibleParas[0]);
        const firstTInfo = parseParaTime(paraTimes[String(firstPN)], firstPN);
        if (curMins < firstTInfo.s) {
          dom.kioskLiveStatusText.textContent = `Занятия не начались. ${firstPN} пара начнется в ${firstTInfo.sStr} (через ${firstTInfo.s - curMins} мин)`;
        } else {
          dom.kioskLiveStatusText.textContent = `Перемена (до ${nextPara.sStr}, осталось ${nextPara.rem} мин). Следующая: ${nextPara.pN} пара`;
        }
        dom.kioskLiveStatusBar.classList.remove('hidden');
      } else {
        dom.kioskLiveStatusText.textContent = 'Все пары на сегодня завершены';
        dom.kioskLiveStatusBar.classList.remove('hidden');
      }
    } else {
      dom.kioskLiveStatusBar?.classList.add('hidden');
    }

    // Генерация карточек пар в едином стиле Telegram Mini App
    let html = '';
    let foundNext = false;

    for (const pStr of visibleParas) {
      const item = dayData[pStr];
      const pN = parseInt(pStr);
      const tInfo = parseParaTime(paraTimes[pStr], pN);
      const timeDisplay = tInfo.sStr ? `${tInfo.sStr} - ${tInfo.eStr}` : '';

      let statusClass = '';
      let badgeHtml = '';

      if (isToday) {
        if (curMins > tInfo.e) {
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
        if ((state.selectedSubgroup === 0 || state.selectedSubgroup === 1) && (item.subj1 || item.aud1)) {
          partsHtml += `
            <div class="subgroup-block">
              <div class="subgroup-label">1 подгруппа</div>
              <div class="para-subject">${escapeHtml(item.subj1 || 'Предмет')} <span class="type-pill">${item.type1 ? `(${escapeHtml(item.type1)})` : ''}</span></div>
              <div class="para-meta">
                ${item.aud1 ? `<span class="aud-pill">ауд. ${escapeHtml(item.aud1)}</span>` : ''}
                ${renderTeacherChipHtml(item.teacher1, item.teachPost1)}
              </div>
            </div>`;
        }
        if ((state.selectedSubgroup === 0 || state.selectedSubgroup === 2) && (item.subj2 || item.aud2)) {
          partsHtml += `
            <div class="subgroup-block">
              <div class="subgroup-label">2 подгруппа</div>
              <div class="para-subject">${escapeHtml(item.subj2 || 'Предмет')} <span class="type-pill">${item.type2 ? `(${escapeHtml(item.type2)})` : ''}</span></div>
              <div class="para-meta">
                ${item.aud2 ? `<span class="aud-pill">ауд. ${escapeHtml(item.aud2)}</span>` : ''}
                ${renderTeacherChipHtml(item.teacher2, item.teachPost2)}
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
            <div class="para-subject">${escapeHtml(item.subj1 || 'Предмет')} <span class="type-pill">${item.type1 ? `(${escapeHtml(item.type1)})` : ''}</span></div>
            <div class="para-meta">
              ${item.aud1 ? `<span class="aud-pill">ауд. ${escapeHtml(item.aud1)}</span>` : ''}
              ${renderTeacherChipHtml(item.teacher1, item.teachPost1)}
            </div>
          </div>`;
      }
    }

    dom.kioskScheduleCards.innerHTML = html;

    // Навешиваем клики на кнопки преподавателей
    dom.kioskScheduleCards.querySelectorAll('.teacher-btn-chip').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const tName = btn.dataset.teacher;
        openTeacherModal(tName);
      });
    });
  }

  // ========================================================
  // МОДАЛЬНОЕ ОКНО ПРЕПОДАВАТЕЛЯ
  // ========================================================
  async function openTeacherModal(teacherName) {
    if (!teacherName) return;
    if (dom.kioskTeacherModal) dom.kioskTeacherModal.classList.remove('hidden');
    if (dom.kioskTeacherLoading) dom.kioskTeacherLoading.classList.remove('hidden');
    if (dom.kioskTeacherContent) dom.kioskTeacherContent.classList.add('hidden');

    try {
      const res = await fetch(`/api/teacher?name=${encodeURIComponent(teacherName)}`);
      if (!res.ok) throw new Error('Ошибка загрузки преподавателя');
      const data = await res.json();

      if (dom.ktFullName) dom.ktFullName.textContent = data.full_name || teacherName;
      if (dom.ktPost) dom.ktPost.textContent = data.post || 'Преподаватель кафедры';
      if (dom.ktDept) dom.ktDept.textContent = data.department || 'Рубцовский индустриальный институт';

      // Фото
      if (data.photo_url && dom.ktPhoto && dom.ktAvatarFallback) {
        dom.ktPhoto.src = data.photo_url;
        dom.ktPhoto.classList.remove('hidden');
        dom.ktAvatarFallback.classList.add('hidden');
      } else if (dom.ktPhoto && dom.ktAvatarFallback) {
        dom.ktPhoto.classList.add('hidden');
        dom.ktAvatarFallback.classList.remove('hidden');
      }

      // Дополнительные строки
      setRow(dom.ktRoomRow, dom.ktRoom, data.room);
      setRow(dom.ktDegreeRow, dom.ktDegree, data.degree);
      setRow(dom.ktPhoneRow, dom.ktPhone, data.phone);
      setRow(dom.ktEmailRow, dom.ktEmail, data.email);
      setRow(dom.ktDisciplinesRow, dom.ktDisciplines, data.disciplines);

      if (dom.kioskTeacherLoading) dom.kioskTeacherLoading.classList.add('hidden');
      if (dom.kioskTeacherContent) dom.kioskTeacherContent.classList.remove('hidden');
    } catch (e) {
      console.error('Ошибка загрузки преподавателя:', e);
      if (dom.ktFullName) dom.ktFullName.textContent = teacherName;
      if (dom.ktPost) dom.ktPost.textContent = 'Преподаватель РИИ';
      if (dom.kioskTeacherLoading) dom.kioskTeacherLoading.classList.add('hidden');
      if (dom.kioskTeacherContent) dom.kioskTeacherContent.classList.remove('hidden');
    }
  }

  function setRow(rowEl, valEl, value) {
    if (!rowEl || !valEl) return;
    if (value && String(value).trim()) {
      valEl.textContent = value;
      rowEl.classList.remove('hidden');
    } else {
      rowEl.classList.add('hidden');
    }
  }

  function closeTeacherModal() {
    if (dom.kioskTeacherModal) dom.kioskTeacherModal.classList.add('hidden');
  }

  // ========================================================
  // ИНИЦИАЛИЗАЦИЯ И СЛУШАТЕЛИ СОБЫТИЙ
  // ========================================================
  function initEventListeners() {
    // Кнопка НАЧАТЬ РАБОТУ на заставке
    dom.startKioskBtn?.addEventListener('click', () => {
      showScreen('groupSelect');
    });

    // Кнопки возврата и завершения
    dom.btnBackToWelcome?.addEventListener('click', () => {
      finishSession();
    });

    dom.btnFinishSession1?.addEventListener('click', () => {
      finishSession();
    });

    dom.btnFinishSession2?.addEventListener('click', () => {
      finishSession();
    });

    dom.btnBackToGroups?.addEventListener('click', () => {
      showScreen('groupSelect');
    });

    // Курсовые вкладки
    dom.kioskCourseTabs?.querySelectorAll('.course-tab').forEach(tab => {
      tab.addEventListener('click', () => {
        state.selectedCourse = tab.dataset.course;
        updateCourseTabsUI();
        renderGroupsList();
      });
    });

    // Быстрые теги специальностей
    dom.kioskQuickTags?.querySelectorAll('.quick-tag').forEach(tagBtn => {
      tagBtn.addEventListener('click', () => {
        const tag = tagBtn.dataset.tag;
        state.selectedTag = tag;
        updateQuickTagsUI();
        renderGroupsList();
      });
    });

    // Поиск групп
    dom.kioskGroupSearch?.addEventListener('input', (e) => {
      state.searchQuery = e.target.value;
      if (dom.btnClearSearch) {
        dom.btnClearSearch.classList.toggle('hidden', !state.searchQuery);
      }
      renderGroupsList();
    });

    dom.btnClearSearch?.addEventListener('click', () => {
      state.searchQuery = '';
      if (dom.kioskGroupSearch) dom.kioskGroupSearch.value = '';
      dom.btnClearSearch.classList.add('hidden');
      renderGroupsList();
    });

    // Переключатель недели
    dom.kioskWeek1Btn?.addEventListener('click', () => {
      state.selectedWeek = 1;
      updateScheduleControlsUI();
      renderScheduleCards();
    });

    dom.kioskWeek2Btn?.addEventListener('click', () => {
      state.selectedWeek = 2;
      updateScheduleControlsUI();
      renderScheduleCards();
    });

    // Дни недели
    dom.kioskDaysNav?.querySelectorAll('.kiosk-day-chip').forEach(chip => {
      chip.addEventListener('click', () => {
        state.selectedDay = parseInt(chip.dataset.day);
        updateScheduleControlsUI();
        renderScheduleCards();
      });
    });

    // Подгруппы
    dom.subgroupBtns?.forEach(btn => {
      btn.addEventListener('click', () => {
        state.selectedSubgroup = parseInt(btn.dataset.sg);
        updateScheduleControlsUI();
        renderScheduleCards();
      });
    });

    // Закрытие модалки преподавателя
    dom.btnCloseTeacherModal?.addEventListener('click', closeTeacherModal);
    dom.btnCloseTeacherBottom?.addEventListener('click', closeTeacherModal);
    dom.kioskTeacherModal?.addEventListener('click', (e) => {
      if (e.target === dom.kioskTeacherModal) closeTeacherModal();
    });
  }

  function init() {
    initDom();
    initEventListeners();
    updateLiveClock();
    liveClockInterval = setInterval(updateLiveClock, 1000);

    fetchLiveBoardData();
    liveBoardPollingInterval = setInterval(fetchLiveBoardData, 25000);

    loadAllGroups();
    showScreen('welcome');
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
