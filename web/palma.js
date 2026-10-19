/* The Palma map.
 *
 * 148 real places, where they really are. The reference artwork underneath is
 * a picture of a city rather than a map of one, and dropping true coordinates
 * onto it would put the cathedral in the wrong street — which is a strange lie
 * for a page whose whole promise is that the story finds you in the right
 * place. So the artwork is the backdrop while Mapbox loads, and Mapbox is what
 * you actually get.
 */
(() => {
  'use strict'

  // Public Mapbox token. Public is what these are for, but this one is shared
  // with the app and the admin panel: a separate, URL-restricted token for
  // passimexplore.com would mean a scraped website token cannot spend the
  // app's quota. Worth doing before this page gets any traffic.
  const TOKEN =
    'pk.eyJ1IjoibGl0dGxld2h5IiwiYSI6ImNtZHJnMjc2bzBoM2EybHNmMWtpNW4xd24ifQ.NMHAZQhN_eP_3wxFUfNhdw'

  const AMBER = '#FFC21A'
  const INK = '#071A2F'
  const CATEGORY_LABEL = {
    history: 'History',
    otium: 'Leisure',
    headline: 'Stories & Legends',
    hotdeal: 'Offers',
  }
  const PIN = {
    history: '/assets/pin-history.webp',
    otium: '/assets/pin-otium.webp',
    headline: '/assets/pin-headline.webp',
    hotdeal: '/assets/pin-hotdeal.webp',
  }

  const stage = document.querySelector('[data-map]')
  const card = document.querySelector('[data-place]')
  if (!stage || !card) return

  let map = null
  let places = []
  let filter = 'all'

  const visible = () =>
    filter === 'all' ? places : places.filter((p) => p.c === filter)

  const asGeoJSON = (list) => ({
    type: 'FeatureCollection',
    features: list.map((p) => ({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [p.lng, p.lat] },
      properties: { n: p.n, s: p.s, c: p.c, img: p.img || '', a: p.a, icon: 'pin_' + p.c },
    })),
  })

  // ── the card ──────────────────────────────────────────────
  const openCard = (props) => {
    const img = card.querySelector('[data-place-img]')
    if (props.img) {
      img.src = props.img
      img.alt = props.n
      img.hidden = false
    } else {
      img.hidden = true
    }
    card.querySelector('[data-place-name]').textContent = props.n
    card.querySelector('[data-place-cat]').textContent =
      CATEGORY_LABEL[props.c] || props.c
    card.querySelector('[data-place-icon]').src = PIN[props.c] || PIN.history
    card.querySelector('[data-place-sub]').textContent = props.s || ''

    const button = card.querySelector('[data-play]')
    button.dataset.src = props.a
    button.setAttribute('aria-label', 'Play the story of ' + props.n)
    // A card that opens still playing the previous place would be the page
    // telling you about one thing while you listen to another.
    window.passimAudio?.stop()
    card.hidden = false
    stage.classList.add('has-card')
  }

  card.querySelector('[data-close]').addEventListener('click', () => {
    window.passimAudio?.stop()
    card.hidden = true
    stage.classList.remove('has-card')
  })

  // ── filters ───────────────────────────────────────────────
  document.querySelectorAll('.pill').forEach((pill) => {
    pill.addEventListener('click', () => {
      document.querySelectorAll('.pill').forEach((p) => p.classList.remove('is-on'))
      pill.classList.add('is-on')
      filter = pill.dataset.cat
      const src = map && map.getSource('places')
      if (src) src.setData(asGeoJSON(visible()))
    })
  })

  // ── the map itself ────────────────────────────────────────
  const build = async () => {
    const [data] = await Promise.all([
      fetch('/data/palma.json').then((r) => r.json()),
      new Promise((done) => {
        // mapbox-gl is deferred; it may or may not have arrived yet.
        if (window.mapboxgl) return done()
        const wait = setInterval(() => {
          if (window.mapboxgl) { clearInterval(wait); done() }
        }, 60)
      }),
    ])
    places = data.places

    mapboxgl.accessToken = TOKEN
    map = new mapboxgl.Map({
      container: 'palma-map',
      style: 'mapbox://styles/mapbox/dark-v11',
      center: [2.6502, 39.5696],
      zoom: 12.1,
      attributionControl: true,
      cooperativeGestures: true, // the page still scrolls past the map
    })
    map.addControl(new mapboxgl.NavigationControl({ showCompass: false }), 'top-right')

    map.on('load', async () => {
      map.addSource('places', {
        type: 'geojson',
        data: asGeoJSON(visible()),
        cluster: true,
        clusterMaxZoom: 15,
        clusterRadius: 48,
      })

      await Promise.all(
        Object.entries(PIN).map(([key, url]) =>
          new Promise((done) => {
            map.loadImage(url, (err, image) => {
              const id = 'pin_' + key
              if (!err && image && !map.hasImage(id)) map.addImage(id, image)
              done()
            })
          }),
        ),
      )

      map.addLayer({
        id: 'clusters',
        type: 'circle',
        source: 'places',
        filter: ['has', 'point_count'],
        paint: {
          // Literals, never var(--amber): Mapbox parses paint with its own
          // engine, logs a rejection for anything else and silently skips the
          // layer. That has cost this project an afternoon before.
          'circle-color': AMBER,
          'circle-radius': ['step', ['get', 'point_count'], 20, 10, 28, 40, 38],
          'circle-stroke-width': 3,
          'circle-stroke-color': INK,
        },
      })
      map.addLayer({
        id: 'cluster-count',
        type: 'symbol',
        source: 'places',
        filter: ['has', 'point_count'],
        layout: {
          'text-field': ['get', 'point_count_abbreviated'],
          'text-size': 15,
          'text-font': ['DIN Pro Bold', 'Arial Unicode MS Bold'],
        },
        paint: { 'text-color': INK },
      })
      map.addLayer({
        id: 'pins',
        type: 'symbol',
        source: 'places',
        filter: ['!', ['has', 'point_count']],
        layout: {
          'icon-image': ['get', 'icon'],
          'icon-size': ['interpolate', ['linear'], ['zoom'], 11, 0.16, 15, 0.26],
          'icon-allow-overlap': true,
          'icon-anchor': 'bottom',
        },
      })

      map.on('click', 'clusters', (e) => {
        const f = e.features[0]
        map.getSource('places').getClusterExpansionZoom(
          f.properties.cluster_id,
          (err, zoom) => {
            if (err) return
            map.easeTo({ center: f.geometry.coordinates, zoom: zoom + 0.4 })
          },
        )
      })
      map.on('click', 'pins', (e) => {
        openCard(e.features[0].properties)
        map.easeTo({ center: e.features[0].geometry.coordinates, offset: [0, 80] })
      })

      for (const layer of ['clusters', 'pins']) {
        map.on('mouseenter', layer, () => { map.getCanvas().style.cursor = 'pointer' })
        map.on('mouseleave', layer, () => { map.getCanvas().style.cursor = '' })
      }

      stage.classList.add('is-ready')
    })

    map.on('error', () => stage.classList.add('map-failed'))
  }

  // Mapbox is a megabyte and a half, and most of this page is read before
  // anyone reaches the map. It loads when it is about to be looked at.
  const watcher = new IntersectionObserver(
    (entries) => {
      if (!entries.some((e) => e.isIntersecting)) return
      watcher.disconnect()
      build().catch(() => stage.classList.add('map-failed'))
    },
    { rootMargin: '300px' },
  )
  watcher.observe(stage)
})()
