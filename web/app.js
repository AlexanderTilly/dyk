/* One narration at a time, and a map that looks inhabited.
 *
 * Every play button shares a single Audio element. Two stories talking over
 * each other is the fastest way to make a page about listening feel broken,
 * and pausing the others by hand means remembering every one of them. */
(() => {
  'use strict'

  // ── the player ───────────────────────────────────────────
  const audio = new Audio()
  audio.preload = 'none' // the clips run for minutes; nobody has asked yet
  let current = null // the [data-player] that owns the audio right now

  const clock = (seconds) => {
    if (!isFinite(seconds)) return '0:00'
    const m = Math.floor(seconds / 60)
    const s = Math.floor(seconds % 60)
    return m + ':' + String(s).padStart(2, '0')
  }

  const readout = () => current && current.querySelector('[data-time]')

  const stop = () => {
    if (current) {
      current.classList.remove('is-playing')
      const t = readout()
      if (t) t.textContent = '0:00'
    }
    current = null
  }

  const start = (panel, button) => {
    stop()
    audio.src = button.dataset.src
    button.classList.add('is-loading')
    audio.play().then(
      () => {
        button.classList.remove('is-loading')
        current = panel
        panel.classList.add('is-playing')
      },
      () => {
        // Refused, offline, or the file has moved. Stay quiet and leave the
        // button ready to try again: an error dialog over a sample clip is
        // worse than the silence it would be explaining.
        button.classList.remove('is-loading')
      },
    )
  }

  document.querySelectorAll('[data-play]').forEach((button) => {
    const panel = button.closest('[data-player]')
    if (!panel) return
    button.addEventListener('click', () => {
      if (current === panel) {
        audio.pause()
        stop()
      } else {
        start(panel, button)
      }
    })
  })

  audio.addEventListener('timeupdate', () => {
    const t = readout()
    if (t) t.textContent = clock(audio.currentTime)
  })
  audio.addEventListener('ended', stop)
  audio.addEventListener('pause', () => {
    // Catches the headphone button and the OS media controls, which pause the
    // element without passing through ours.
    if (!audio.ended && audio.currentTime > 0) stop()
  })

  // ── the map's pins ───────────────────────────────────────
  // Scattered rather than real coordinates: this is a picture of a city full
  // of stories, not a map anyone navigates by. Fixed positions, because pins
  // that land somewhere new on every reload look like a bug.
  const pins = document.getElementById('map-pins')
  if (pins) {
    const spots = [
      [18, 30], [27, 52], [34, 22], [41, 68], [46, 38], [52, 18],
      [57, 58], [63, 30], [68, 74], [72, 44], [78, 26], [83, 62],
      [24, 76], [37, 44], [60, 82], [88, 40], [14, 58], [49, 60],
    ]
    pins.innerHTML = spots
      .map(([x, y]) => `<i style="left:${x}%;top:${y}%"></i>`)
      .join('')
  }

  const year = document.querySelector('[data-year]')
  if (year) year.textContent = String(new Date().getFullYear())
})()
