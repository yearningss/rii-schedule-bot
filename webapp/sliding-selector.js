// Перемещаем общую плашку к выбранной кнопке, не меняя логику переключателей.
function moveSelectionIndicator(container) {
  const selected = container.querySelector('button.active');
  if (!selected) return;
  container.style.setProperty('--selection-left', `${selected.offsetLeft}px`);
  container.style.setProperty('--selection-width', `${selected.getBoundingClientRect().width}px`);
  container.querySelectorAll('button').forEach(button => {
    button.setAttribute('aria-pressed', String(button === selected));
  });
}

function setupSlidingIndicators() {
  document.querySelectorAll('.week-toggle, .subgroup-selector, .kiosk-week-toggle, .kiosk-subgroups-strip').forEach(container => {
    container.classList.add('has-sliding-indicator');
    moveSelectionIndicator(container);
    // Начальное выделение появляется на месте; последующие перемещения плавные.
    requestAnimationFrame(() => requestAnimationFrame(() => {
      container.classList.add('indicator-ready');
    }));
    if (typeof ResizeObserver !== 'undefined') {
      const observer = new ResizeObserver(() => moveSelectionIndicator(container));
      observer.observe(container);
      container.querySelectorAll('button').forEach(button => observer.observe(button));
    } else {
      window.addEventListener('resize', () => moveSelectionIndicator(container));
    }
    document.fonts?.ready.then(() => moveSelectionIndicator(container));
  });
}

