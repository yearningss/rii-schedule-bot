// Скрипт информационного табло расписания РИИ АлтГТУ (ТВ-киоск 10-foot UI)
(function () {
  'use strict';

  // Состояние приложения ТВ-табло
  const state = {
    groups: [],
    bellStatus: null,
    dateStr: '',
    dayName: '',
    weekNum: 1,
    weekName: 'Числитель',
    serverTimeSecs: 0,
    clientBaseTime: Date.now(),
    currentPage: 0,
    pageSize: 9,
    totalPages: 1,
    isOnline: true,
    isPaused: false,
    carouselInterval: null,
    carouselTimer: 12000, // 12 секунд на страницу
    remainingBellSeconds: 0
  };

  // DOM Элементы
  const dom = {
    onlineBadge: document.getElementById('tvOnlineBadge'),
    onlineText: document.getElementById('tvOnlineText'),
    clock: document.getElementById('tvClock'),
    dayName: document.getElementById('tvDayName'),
    dateVal: document.getElementById('tvDateVal'),
    weekBadge: document.getElementById('tvWeekBadge'),
    bellCard: document.getElementById('tvBellCard'),
    bellTitle: document.getElementById('tvBellTitle'),
    bellTimer: document.getElementById('tvBellTimer'),
    bellProgressBar: document.getElementById('tvBellProgressBar'),
    pageInfo: document.getElementById('tvPageInfo'),
    carouselProgressBar: document.getElementById('tvCarouselProgressBar'),
    pageDots: document.getElementById('tvPageDots'),
    grid: document.getElementById('tvGrid')
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

  function formatTime(totalSecs) {
    if (totalSecs < 0) totalSecs = 0;
    const m = Math.floor(totalSecs / 60);
    const s = Math.floor(totalSecs % 60);
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  }

  // Локальное вычисление времени Рубцовска (UTC+7)
  function getRubtsovskNow() {
    const now = new Date();
    const utc = now.getTime() + now.getTimezoneOffset() * 60000;
    return new Date(utc + 7 * 3600000);
  }

  // Обновление локальных часов каждую секунду
  function tickClock() {
    const rNow = getRubtsovskNow();
    const h = String(rNow.getHours()).padStart(2, '0');
    const m = String(rNow.getMinutes()).padStart(2, '0');
    const s = String(rNow.getSeconds()).padStart(2, '0');
    if (dom.clock) {
      dom.clock.textContent = `${h}:${m}:${s}`;
    }

    // Декремент таймера звонка
    if (state.remainingBellSeconds > 0) {
      state.remainingBellSeconds -= 1;
      if (dom.bellTimer) {
        dom.bellTimer.textContent = formatTime(state.remainingBellSeconds);
      }
    }

    // Подсветка активной пары в строке звонков футера
    updateBellsStripHighlight(rNow);
  }

  function updateBellsStripHighlight(rNow) {
    const curMins = rNow.getHours() * 60 + rNow.getMinutes();
    const bellRanges = [
      { num: 1, s: 510, e: 600 },
      { num: 2, s: 610, e: 700 },
      { num: 3, s: 730, e: 820 },
      { num: 4, s: 830, e: 920 },
      { num: 5, s: 930, e: 1020 },
      { num: 6, s: 1030, e: 1120 },
      { num: 7, s: 1130, e: 1220 },
    ];

    for (const b of bellRanges) {
      const el = document.getElementById(`bellItem${b.num}`);
      if (el) {
        if (curMins >= b.s && curMins < b.e) {
          el.classList.add('active');
        } else {
          el.classList.remove('active');
        }
      }
    }
  }

  // Загрузка данных с сервера
  async function fetchLiveBoard() {
    try {
      const res = await fetch('/api/kiosk/live-board');
      if (!res.ok) throw new Error(`HTTP error ${res.status}`);
      const data = await res.json();
      if (data && data.status === 'ok') {
        processBoardData(data);
        setOnlineStatus(true);
      }
    } catch (err) {
      console.warn('Сбой обновления данных табло:', err);
      setOnlineStatus(false);
    }
  }

  function setOnlineStatus(online) {
    state.isOnline = online;
    if (!dom.onlineBadge) return;
    if (online) {
      dom.onlineBadge.classList.remove('offline');
      dom.onlineText.textContent = 'ОНЛАЙН';
    } else {
      dom.onlineBadge.classList.add('offline');
      dom.onlineText.textContent = 'КЭШ (ОФЛАЙН)';
    }
  }

  function processBoardData(data) {
    state.groups = data.groups || [];
    state.bellStatus = data.bell_status || null;
    state.dateStr = data.date || '';
    state.dayName = data.day_name || '';
    state.weekNum = data.week_number || 1;
    state.weekName = data.week_name || 'Числитель';

    // Обновляем шапку
    if (dom.dayName) dom.dayName.textContent = state.dayName;
    if (dom.dateVal) dom.dateVal.textContent = state.dateStr;
    if (dom.weekBadge) {
      dom.weekBadge.textContent = `${state.weekNum} неделя (${state.weekName})`;
    }

    // Обновляем плашку звонка
    if (state.bellStatus) {
      const bs = state.bellStatus;
      state.remainingBellSeconds = bs.remaining_seconds || 0;
      if (dom.bellTitle) dom.bellTitle.textContent = bs.label || 'Учебный процесс';
      if (dom.bellTimer) dom.bellTimer.textContent = bs.remaining_str || '--:--';
      if (dom.bellProgressBar) {
        dom.bellProgressBar.style.width = `${bs.progress_percent || 0}%`;
      }
    }

    // Обновляем погоду в Рубцовске
    if (data.weather) {
      const w = data.weather;
      const wTemp = document.getElementById('tvWeatherTemp');
      const wDesc = document.getElementById('tvWeatherDesc');
      const wIcon = document.getElementById('tvWeatherIcon');
      if (wTemp) wTemp.textContent = w.temp || '--°C';
      if (wDesc) wDesc.textContent = `Рубцовск: ${w.description || 'Ясно'}`;
      if (wIcon && w.icon) {
        if (w.icon === 'cloud' || w.icon === 'cloud-sun') {
          wIcon.innerHTML = '<svg viewBox="0 0 24 24" width="22" height="22"><path fill="currentColor" d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96z"/></svg>';
        } else if (w.icon === 'rain') {
          wIcon.innerHTML = '<svg viewBox="0 0 24 24" width="22" height="22"><path fill="currentColor" d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM10 21v2h-2v-2h2zm4 0v2h-2v-2h2zm4 0v2h-2v-2h2z"/></svg>';
        } else if (w.icon === 'snow') {
          wIcon.innerHTML = '<svg viewBox="0 0 24 24" width="22" height="22"><path fill="currentColor" d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM8 21h2v2H8v-2zm6 0h2v2h-2v-2z"/></svg>';
        } else {
          wIcon.innerHTML = '<svg viewBox="0 0 24 24" width="22" height="22"><path fill="currentColor" d="M12 7c-2.76 0-5 2.24-5 5s2.24 5 5 5 5-2.24 5-5-2.24-5-5-5zM2 13h2c.55 0 1-.45 1-1s-.45-1-1-1H2c-.55 0-1 .45-1 1s.45 1 1 1zm18 0h2c.55 0 1-.45 1-1s-.45-1-1-1h-2c-.55 0-1 .45-1 1s.45 1 1 1zM11 2v2c0 .55.45 1 1 1s1-.45 1-1V2c0-.55-.45-1-1-1s-1 .45-1 1zm0 18v2c0 .55.45 1 1 1s1-.45 1-1v-2c0-.55-.45-1-1-1s-1 .45-1 1zM5.99 4.58a.996.996 0 00-1.41 0 .996.996 0 000 1.41l1.06 1.06c.39.39 1.03.39 1.41 0s.39-1.03 0-1.41L5.99 4.58zm12.37 12.37a.996.996 0 00-1.41 0 .996.996 0 000 1.41l1.06 1.06c.39.39 1.03.39 1.41 0s.39-1.03 0-1.41l-1.06-1.06zm1.06-10.96a.996.996 0 000-1.41.996.996 0 00-1.41 0l-1.06 1.06c-.39.39-.39 1.03 0 1.41s1.03.39 1.41 0l1.06-1.06zM7.05 18.36a.996.996 0 000-1.41.996.996 0 000 1.41l-1.06 1.06c-.39.39-.39 1.03 0 1.41s1.03.39 1.41 0l1.06-1.06z"/></svg>';
        }
      }
    }

    // Расчет пагинации
    state.totalPages = Math.max(1, Math.ceil(state.groups.length / state.pageSize));
    if (state.currentPage >= state.totalPages) {
      state.currentPage = 0;
    }

    renderPageDots();
    renderCurrentPage();
  }

  function renderPageDots() {
    if (!dom.pageDots) return;
    dom.pageDots.innerHTML = '';
    for (let i = 0; i < state.totalPages; i++) {
      const dot = document.createElement('div');
      dot.className = `tv-dot ${i === state.currentPage ? 'active' : ''}`;
      dot.addEventListener('click', () => {
        goToPage(i);
      });
      dom.pageDots.appendChild(dot);
    }
  }

  function updatePageInfo() {
    if (!dom.pageInfo) return;
    const startIdx = state.currentPage * state.pageSize + 1;
    const endIdx = Math.min((state.currentPage + 1) * state.pageSize, state.groups.length);
    dom.pageInfo.textContent = `Группы ${startIdx}-${endIdx} из ${state.groups.length} (Страница ${state.currentPage + 1} из ${state.totalPages})`;

    if (dom.pageDots) {
      const dots = dom.pageDots.querySelectorAll('.tv-dot');
      dots.forEach((dot, idx) => {
        dot.classList.toggle('active', idx === state.currentPage);
      });
    }
  }

  function renderCurrentPage() {
    if (!dom.grid) return;
    updatePageInfo();

    const startIdx = state.currentPage * state.pageSize;
    const pageGroups = state.groups.slice(startIdx, startIdx + state.pageSize);

    if (pageGroups.length === 0) {
      dom.grid.innerHTML = '<div class="tv-empty-lesson-text" style="grid-column: 1/-1; text-align: center; padding: 40px;">Нет данных об учебных группах</div>';
      return;
    }

    let cardsHtml = '';
    for (const g of pageGroups) {
      cardsHtml += buildCardHtml(g);
    }

    dom.grid.innerHTML = cardsHtml;
  }

  function buildCardHtml(g) {
    const statusClass = `status-${g.status}`;
    const badgeColorClass = g.status_badge || 'gray';
    const statusLabel = escapeHtml(g.status_label || '');
    const courseText = g.course ? `${g.course} курс` : '';

    let currentContentHtml = '';

    if (g.current_lesson) {
      const cur = g.current_lesson;
      if (!cur.is_double) {
        const aud = cur.aud ? `<span class="tv-aud-badge large">ауд. ${escapeHtml(cur.aud)}</span>` : '';
        const typeBadge = cur.type ? `<span class="tv-lesson-type">${escapeHtml(cur.type)}</span>` : '';
        const teacherText = cur.teacher ? `${escapeHtml(cur.teacher)}${cur.teach_post ? ` (${escapeHtml(cur.teach_post)})` : ''}` : '';

        currentContentHtml = `
          <div class="tv-lesson-title-row">
            <span class="tv-lesson-label">${cur.num} ПАРА (${escapeHtml(cur.time)})</span>
            ${aud}
          </div>
          <div class="tv-subject-name">${escapeHtml(cur.subject)}</div>
          <div class="tv-teacher-row">
            ${typeBadge}
            <span>${teacherText}</span>
          </div>
        `;
      } else {
        // Две подгруппы
        let sg1Html = '';
        let sg2Html = '';
        if (cur.subgroup1) {
          const s1 = cur.subgroup1;
          const a1 = s1.aud ? `<span class="tv-aud-badge">ауд. ${escapeHtml(s1.aud)}</span>` : '';
          sg1Html = `
            <div class="tv-double-row">
              <div><span class="tv-subgroup-tag">1 п/г:</span> ${escapeHtml(s1.subject)} (${escapeHtml(s1.type || '')})</div>
              ${a1}
            </div>
          `;
        }
        if (cur.subgroup2) {
          const s2 = cur.subgroup2;
          const a2 = s2.aud ? `<span class="tv-aud-badge">ауд. ${escapeHtml(s2.aud)}</span>` : '';
          sg2Html = `
            <div class="tv-double-row">
              <div><span class="tv-subgroup-tag">2 п/г:</span> ${escapeHtml(s2.subject)} (${escapeHtml(s2.type || '')})</div>
              ${a2}
            </div>
          `;
        }

        currentContentHtml = `
          <div class="tv-lesson-title-row">
            <span class="tv-lesson-label">${cur.num} ПАРА (${escapeHtml(cur.time)})</span>
          </div>
          <div class="tv-double-box">
            ${sg1Html}
            ${sg2Html}
          </div>
        `;
      }
    } else {
      // Нет текущей пары
      let message = 'Занятия еще не начались';
      if (g.status === 'window') {
        message = 'Свободное окно между парами';
      } else if (g.status === 'done') {
        message = 'Все пары на сегодня завершены';
      } else if (g.status === 'free') {
        message = 'Сегодня нет пар по расписанию';
      } else if (g.status === 'break') {
        message = 'Перемена';
      }

      currentContentHtml = `
        <div class="tv-empty-lesson-text">${escapeHtml(message)}</div>
      `;
    }

    // Блок следующей пары
    let nextContentHtml = '';
    if (g.next_lesson) {
      const nxt = g.next_lesson;
      const nAud = nxt.aud ? `<span class="tv-next-aud">ауд. ${escapeHtml(nxt.aud)}</span>` : '';
      nextContentHtml = `
        <div class="tv-card-next">
          <span class="tv-next-label">СЛЕДУЮЩАЯ (${nxt.num} пара):</span>
          <div class="tv-next-content">
            <span class="tv-next-subj" title="${escapeHtml(nxt.subject)}">${escapeHtml(nxt.subject)}</span>
            ${nAud}
          </div>
        </div>
      `;
    }

    return `
      <div class="tv-card ${statusClass}">
        <div class="tv-card-header">
          <div class="tv-card-group-row">
            <span class="tv-card-group-name">${escapeHtml(g.group_name)}</span>
            <span class="tv-card-course">${escapeHtml(courseText)}</span>
          </div>
          <span class="tv-card-status-badge ${badgeColorClass}">${statusLabel}</span>
        </div>
        <div class="tv-card-current">
          ${currentContentHtml}
        </div>
        ${nextContentHtml}
      </div>
    `;
  }

  function goToPage(pageIdx) {
    if (pageIdx < 0) pageIdx = state.totalPages - 1;
    if (pageIdx >= state.totalPages) pageIdx = 0;
    state.currentPage = pageIdx;

    if (dom.grid) {
      dom.grid.classList.add('fade-out');
      setTimeout(() => {
        renderCurrentPage();
        dom.grid.classList.remove('fade-out');
      }, 350);
    } else {
      renderCurrentPage();
    }
    resetCarouselProgressBar();
  }

  function nextPage() {
    goToPage(state.currentPage + 1);
  }

  function prevPage() {
    goToPage(state.currentPage - 1);
  }

  function resetCarouselProgressBar() {
    if (!dom.carouselProgressBar) return;
    dom.carouselProgressBar.classList.remove('animate');
    dom.carouselProgressBar.style.width = '0%';
    // Форсируем reflow браузера для перезапуска transition
    void dom.carouselProgressBar.offsetWidth;
    if (!state.isPaused) {
      dom.carouselProgressBar.classList.add('animate');
    }
  }

  function startCarousel() {
    if (state.carouselInterval) clearInterval(state.carouselInterval);
    resetCarouselProgressBar();

    state.carouselInterval = setInterval(() => {
      if (!state.isPaused && state.totalPages > 1) {
        nextPage();
      }
    }, state.carouselTimer);
  }

  // Поддержка горячих клавиш (стрелки, пробел)
  document.addEventListener('keydown', (e) => {
    if (e.code === 'ArrowRight' || e.code === 'KeyD') {
      nextPage();
    } else if (e.code === 'ArrowLeft' || e.code === 'KeyA') {
      prevPage();
    } else if (e.code === 'Space') {
      state.isPaused = !state.isPaused;
      if (state.isPaused) {
        if (dom.carouselProgressBar) dom.carouselProgressBar.classList.remove('animate');
      } else {
        resetCarouselProgressBar();
      }
    }
  });

  // Инициализация
  function init() {
    tickClock();
    setInterval(tickClock, 1000);

    fetchLiveBoard();
    setInterval(fetchLiveBoard, 20000); // Опрос бэкенда каждые 20 секунд

    startCarousel();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
