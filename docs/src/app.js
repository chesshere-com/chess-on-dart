const menuButton = document.querySelector('.menu-button');
const navigation = document.querySelector('#main-nav');
menuButton?.addEventListener('click', () => {
  const open = menuButton.getAttribute('aria-expanded') !== 'true';
  menuButton.setAttribute('aria-expanded', String(open));
  navigation.classList.toggle('open', open);
});
document.addEventListener('keydown', event => {
  if (event.key === 'Escape' && menuButton?.getAttribute('aria-expanded') === 'true') {
    menuButton.setAttribute('aria-expanded', 'false');
    navigation.classList.remove('open');
    menuButton.focus();
  }
});

document.querySelectorAll('[data-copy]').forEach(button => {
  button.addEventListener('click', async () => {
    const target = document.getElementById(button.dataset.copy);
    if (!target) return;
    try {
      await navigator.clipboard.writeText(target.textContent);
      button.textContent = 'Copied!';
    } catch {
      // Selection still works when clipboard access is unavailable.
      const range = document.createRange();
      range.selectNodeContents(target);
      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      button.textContent = 'Selected';
    }
    clearTimeout(button.copyTimer);
    button.copyTimer = setTimeout(() => { button.textContent = 'Copy'; }, 1800);
  });
});

const sideLinks = [...document.querySelectorAll('.sidebar a[href^="#"]')];
if (sideLinks.length && 'IntersectionObserver' in window) {
  const observer = new IntersectionObserver(entries => {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        sideLinks.forEach(link => link.classList.toggle('active', link.hash === `#${entry.target.id}`));
      }
    }
  }, { rootMargin: '-15% 0px -65% 0px' });
  sideLinks.forEach(link => {
    const section = document.querySelector(link.hash);
    if (section) observer.observe(section);
  });
}

const apiSearch = document.querySelector('#api-search');
apiSearch?.addEventListener('input', () => {
  const query = apiSearch.value.trim().toLowerCase();
  let matches = 0;
  document.querySelectorAll('[data-api-group]').forEach(group => {
    let count = 0;
    group.querySelectorAll('.api-entry').forEach(entry => {
      entry.hidden = !entry.textContent.toLowerCase().includes(query);
      if (!entry.hidden) count++;
    });
    group.hidden = count === 0;
    const link = document.querySelector(`.sidebar a[href="#${group.id}"]`);
    if (link) link.hidden = group.hidden;
    matches += count;
  });
  document.querySelector('#api-empty').hidden = matches !== 0;
  document.querySelector('#api-count').textContent = `${matches} API entries`;
});

const replayData = document.querySelector('#replay-data');
if (replayData) {
  const demos = JSON.parse(replayData.textContent);
  let demo = demos[0];
  let step = 4;
  const board = document.querySelector('#board');
  const select = document.querySelector('#demo-select');
  const moves = document.querySelector('#replay-moves');
  const status = document.querySelector('#replay-status');
  const names = { p: 'pawn', n: 'knight', b: 'bishop', r: 'rook', q: 'queen', k: 'king' };
  const render = () => {
    const frame = demo.frames[step];
    const ranks = frame.fen.split(' ')[0].split('/');
    const squares = [];
    for (let row = 0; row < 8; row++) {
      let col = 0;
      for (const char of ranks[row]) {
        const empty = /[1-8]/.test(char);
        const count = empty ? Number(char) : 1;
        for (let i = 0; i < count; i++, col++) {
          const square = `${'abcdefgh'[col]}${8 - row}`;
          const highlight = frame.uci && [frame.uci.slice(0, 2), frame.uci.slice(2, 4)].includes(square);
          const color = char === char.toUpperCase() ? 'white' : 'black';
          squares.push(`<div class="square${(row + col) % 2 ? ' dark' : ''}${highlight ? ' highlight' : ''}">${col === 0 ? `<span class="coord rank">${8 - row}</span>` : ''}${row === 7 ? `<span class="coord file">${'abcdefgh'[col]}</span>` : ''}${empty ? '' : `<svg viewBox="0 0 64 64" class="piece-${color}" aria-hidden="true"><use href="#piece-${names[char.toLowerCase()]}"></use></svg>`}</div>`);
        }
      }
    }
    board.innerHTML = squares.join('');
    board.setAttribute('aria-label', `${demo.title}, ${step ? `after ${frame.san}` : 'starting position'}. ${frame.turn} to move. FEN: ${frame.fen}`);
    status.replaceChildren();
    const label = document.createElement('strong');
    label.textContent = frame.finished ? 'Variant win' : `${frame.turn} to move`;
    status.append(label, document.createTextNode(` · ${frame.finished ? frame.san : `${frame.legalMoves} legal moves`}`));
    document.querySelector('#replay-first').disabled = step === 0;
    document.querySelector('#replay-prev').disabled = step === 0;
    document.querySelector('#replay-next').disabled = step === demo.frames.length - 1;
    document.querySelector('#replay-last').disabled = step === demo.frames.length - 1;
    moves.querySelectorAll('button').forEach((button, i) => button.setAttribute('aria-pressed', String(i === step)));
    document.querySelector('#replay-fen').textContent = frame.fen;
  };
  const buildMoves = () => {
    moves.replaceChildren();
    demo.frames.forEach((frame, index) => {
      const button = document.createElement('button');
      button.className = 'move-chip';
      const previous = index ? demo.frames[index - 1].fen.split(' ') : null;
      const prefix = previous?.[1] === 'w' ? `${previous[5]}. ` : index === 1 ? `${previous[5]}… ` : '';
      button.textContent = index === 0 ? 'Start' : `${prefix}${frame.san}`;
      button.setAttribute('aria-label', index ? `Go to move ${index}: ${frame.san}` : 'Go to starting position');
      button.addEventListener('click', () => { step = index; render(); });
      moves.append(button);
    });
  };
  select.addEventListener('change', () => {
    demo = demos.find(item => item.id === select.value);
    step = 0;
    buildMoves();
    render();
  });
  document.querySelector('#replay-first').addEventListener('click', () => { step = 0; render(); });
  document.querySelector('#replay-prev').addEventListener('click', () => { if (step > 0) step--; render(); });
  document.querySelector('#replay-next').addEventListener('click', () => { if (step < demo.frames.length - 1) step++; render(); });
  document.querySelector('#replay-last').addEventListener('click', () => { step = demo.frames.length - 1; render(); });
  buildMoves();
  render();
  document.querySelector('#replay-controls').hidden = false;
  select.disabled = false;
}

const benchmarkData = document.querySelector('#benchmark-data');
if (benchmarkData) {
  const data = JSON.parse(benchmarkData.textContent);
  const median = values => [...values].sort((a, b) => a - b)[Math.floor(values.length / 2)];
  document.querySelectorAll('[data-metric]').forEach(button => {
    button.addEventListener('click', () => {
      const key = button.dataset.metric;
      const cpu = key === 'cpu';
      const values = cpu ? [data.median_baseline_cpu_seconds, data.median_improved_cpu_seconds] : ['baseline', 'improved'].map(build => median(data.runs.filter(run => run.build === build).map(run => run.benchmark.results[Number(key)].median_us)) / 1000);
      const unit = cpu ? 's' : 'ms';
      document.querySelectorAll('[data-metric]').forEach(tab => tab.setAttribute('aria-pressed', String(tab === button)));
      document.querySelector('#chart-title').textContent = cpu ? 'Less CPU time. Same verified work.' : `${data.runs[0].benchmark.results[Number(key)].position} · wall time`;
      document.querySelector('#chart-description').textContent = cpu ? 'Whole-process user CPU · lower is better' : 'Median of three per-process medians · lower is better';
      document.querySelector('#baseline-bar').style.width = '100%';
      document.querySelector('#improved-bar').style.width = `${values[1] / values[0] * 100}%`;
      document.querySelector('#baseline-value').textContent = `${values[0].toFixed(cpu ? 3 : 1)} ${unit}`;
      document.querySelector('#improved-value').textContent = `${values[1].toFixed(cpu ? 3 : 1)} ${unit}`;
      document.querySelector('#chart-caption').textContent = cpu
        ? 'Three alternating AOT processes per build. Each process includes setup, two warmups and five measured traversals for all three positions. CPU time is measured for the entire process.'
        : 'Each process reports the median of five timed traversals after two warmups. This view takes the median of those three process medians. Shared-machine wall times were noisy; use the CPU comparison for the headline result.';
    });
  });
}
