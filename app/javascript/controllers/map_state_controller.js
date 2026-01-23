import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    key: String
  }

  connect() {
    // Store reference to this controller globally so initMap can access it
    window.mapStateController = this

    // Listen for Turbo navigation to save state before leaving
    this.boundSaveOnNavigate = this.saveOnNavigate.bind(this)
    document.addEventListener('turbo:before-visit', this.boundSaveOnNavigate)
    document.addEventListener('turbo:submit-start', this.boundSaveOnNavigate)
  }

  disconnect() {
    // Clean up event listeners
    document.removeEventListener('turbo:before-visit', this.boundSaveOnNavigate)
    document.removeEventListener('turbo:submit-start', this.boundSaveOnNavigate)

    // Remove global reference
    delete window.mapStateController
  }

  saveOnNavigate() {
    // Save state before navigating away
    if (window.currentMap) {
      this.saveState(window.currentMap)
    }
  }

  getStorageKey() {
    // Use provided key or fallback to default
    return this.hasKeyValue ? `mapState_${this.keyValue}` : 'mapState_default'
  }

  getSavedState() {
    try {
      const key = this.getStorageKey()
      const saved = sessionStorage.getItem(key)

      if (!saved) {
        return null
      }

      const state = JSON.parse(saved)

      // Check if state is stale (older than 1 hour)
      const oneHour = 60 * 60 * 1000
      if (state.timestamp && (Date.now() - state.timestamp > oneHour)) {
        sessionStorage.removeItem(key)
        return null
      }

      return state
    } catch (error) {
      console.error('Error retrieving map state:', error)
      return null
    }
  }

  saveState(map) {
    try {
      if (!map) {
        return
      }

      const center = map.getCenter()
      const state = {
        center: {
          lat: typeof center.lat === 'function' ? center.lat() : center.lat,
          lng: typeof center.lng === 'function' ? center.lng() : center.lng
        },
        zoom: map.getZoom(),
        timestamp: Date.now()
      }

      const key = this.getStorageKey()
      sessionStorage.setItem(key, JSON.stringify(state))
    } catch (error) {
      console.error('Error saving map state:', error)
    }
  }

  // Debounced save - called when map changes
  debouncedSave(map) {
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout)
    }

    this.saveTimeout = setTimeout(() => {
      this.saveState(map)
    }, 500)
  }

  setupMapListeners(map) {
    // Save state when map stops moving or zooming
    map.addListener('idle', () => {
      this.debouncedSave(map)
    })

    // Store reference to current map
    window.currentMap = map
  }

  clearState() {
    try {
      const key = this.getStorageKey()
      sessionStorage.removeItem(key)
    } catch (error) {
      console.error('Error clearing map state:', error)
    }
  }
}
