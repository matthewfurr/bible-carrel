// node scripts/contrast.mjs
//
// Reads the palettes out of src/css/tokens.css (light and dark), reads
// scripts/contrast-pairs.json, and prints the WCAG contrast ratio of each pair in
// each palette. Exits 1 when a pair falls below its minimum, or when the two dark
// blocks (the system one and the chosen one) disagree.
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const here = path.dirname(fileURLToPath(import.meta.url))
const css = readFileSync(path.join(here, '../src/css/tokens.css'), 'utf8').replace(/\/\*[\s\S]*?\*\//g, '')
const pairs = JSON.parse(readFileSync(path.join(here, 'contrast-pairs.json'), 'utf8'))

const blocks = {}
for (const match of css.matchAll(/([^{}]+)\{([^{}]*)\}/g)) {
  const selector = match[1].trim().replace(/\s+/g, '')
  const colors = {}
  for (const declaration of match[2].matchAll(/--([a-z0-9-]+)\s*:\s*(#[0-9a-f]{6})\s*;/gi)) {
    colors[declaration[1]] = declaration[2].toUpperCase()
  }
  blocks[selector] = colors
}

const need = (selector) => {
  if (!blocks[selector]) throw new Error(`tokens.css has no block for ${selector}`)
  return blocks[selector]
}
const light = need(':root')
const darkChosen = need(':root[data-appearance="dark"]')
const darkSystem = need(':root:not([data-appearance])')
const palettes = {
  light,
  dark: darkChosen,
}

let failed = false
for (const name of new Set([...Object.keys(darkChosen), ...Object.keys(darkSystem)])) {
  if (darkChosen[name] !== darkSystem[name]) {
    console.error(`dark palette: --${name} is ${darkSystem[name]} under prefers-color-scheme but ${darkChosen[name]} when chosen`)
    failed = true
  }
}

const luminance = (hex) => {
  const channels = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
  const [r, g, b] = channels.map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4))
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
}
const ratio = (a, b) => {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x)
  return (hi + 0.05) / (lo + 0.05)
}

console.log('palette  text on surface                          ratio  min')
for (const [paletteName, palette] of Object.entries(palettes)) {
  for (const { text, on, min } of pairs) {
    if (!palette[text] || !palette[on]) {
      console.error(`${paletteName}: pair ${text} on ${on} names a token the palette does not define`)
      failed = true
      continue
    }
    const value = ratio(palette[text], palette[on])
    const ok = value >= min
    if (!ok) failed = true
    console.log(`${paletteName.padEnd(7)}  ${`${text} on ${on}`.padEnd(40)}  ${value.toFixed(2).padStart(5)}  ${String(min).padEnd(3)}  ${ok ? 'ok' : 'FAIL'}`)
  }
}

if (failed) {
  console.error('contrast: at least one pair is below its minimum')
  process.exit(1)
}
console.log('contrast: every pair meets its minimum in both palettes')
