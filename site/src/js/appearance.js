// Inlined in <head> by layouts/base.njk, after the functions of
// scripts/appearance-core.mjs (readChoice, effective, toggled, apply). Applies the stored
// choice before the first paint, then wires the button once the page has it.
var root = document.documentElement
var storage
try { storage = window.localStorage } catch (error) { storage = undefined }
var query = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : undefined

var choice = readChoice(storage)
apply(choice, root)

function systemIsDark() { return !!(query && query.matches) }

// The button's name says what a press does.
function label() {
  var button = document.querySelector('button.appearance')
  if (!button) return
  var text = 'Switch to ' + toggled(choice, systemIsDark()) + ' appearance'
  button.setAttribute('aria-label', text)
  button.title = text
}

document.addEventListener('DOMContentLoaded', function () {
  var button = document.querySelector('button.appearance')
  if (!button) return
  button.addEventListener('click', function () {
    choice = toggled(choice, systemIsDark())
    apply(choice, root)
    try { storage.setItem(STORAGE_KEY, choice) } catch (error) { /* the choice holds for this page */ }
    label()
  })
  label()
  button.hidden = false
})

// While nothing is stored the page follows the system, so the name follows it too.
if (query) {
  var onSystemChange = function () { label() }
  if (query.addEventListener) query.addEventListener('change', onSystemChange)
  else if (query.addListener) query.addListener(onSystemChange)
}

// A page restored from the back-forward cache keeps the choice it was left with; read it again,
// in case it was changed on another page.
window.addEventListener('pageshow', function (event) {
  if (!event.persisted) return
  choice = readChoice(storage)
  apply(choice, root)
  label()
})
