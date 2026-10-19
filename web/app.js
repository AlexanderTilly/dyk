/* One narration at a time.
 *
 * Several players share a single Audio element. Two stories talking over each
 * other is the fastest way to make a page about listening feel broken, and
 * pausing the others by hand means remembering every one of them. */
(() => {
  'use strict'

  const audio = new Audio()
  audio.preload = 'none' // nobody has asked to hear anything yet
  let current = null // the <div data-player> that owns the audio right now

  const stop = () => {
    if (current) current.classList.remove('is-playing')
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
        // Refused, offline, or the file has gone. Say nothing and leave the
        // button ready to try again — an error dialog over a sample clip is
        // worse than the silence it is explaining.
        button.classList.remove('is-loading')
      },
    )
  }

  document.querySelectorAll('[data-play]').forEach((button) => {
    const panel = button.closest('[data-player]')
    button.addEventListener('click', () => {
      if (current === panel) {
        audio.pause()
        stop()
      } else {
        start(panel, button)
      }
    })
  })

  audio.addEventListener('ended', stop)
  audio.addEventListener('pause', () => {
    // Covers the headphone button and the OS media controls, which pause the
    // element without going through ours.
    if (!audio.ended && audio.currentTime > 0) stop()
  })

  const year = document.querySelector('[data-year]')
  if (year) year.textContent = String(new Date().getFullYear())
})()
