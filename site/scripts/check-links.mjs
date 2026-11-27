// node scripts/check-links.mjs <dir> <prefix>
//
// Checks a built site. Every href, src, srcset entry and CSS url() in the built
// files must resolve to a file under <dir> once <prefix> is stripped. An internal
// link that does not begin with the prefix is an error. An http(s) address is
// allowed only in <a href>, never in src, srcset, <link>, <script> or CSS.
// Exit 1 lists each problem.
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs'
import path from 'node:path'

const [dirArg, prefixArg = '/'] = process.argv.slice(2)
if (!dirArg) {
  console.error('usage: node scripts/check-links.mjs <dir> <prefix>')
  process.exit(2)
}
const root = path.resolve(dirArg)
const prefix = `/${prefixArg.replace(/^\/+|\/+$/g, '')}/`.replace('//', '/')

const problems = []
const report = (file, what, target, why) => problems.push(`${path.relative(root, file)}: ${what} "${target}" ${why}`)

function walk(dir) {
  return readdirSync(dir).flatMap((name) => {
    const full = path.join(dir, name)
    return statSync(full).isDirectory() ? walk(full) : [full]
  })
}

const isExternal = (target) => /^(?:[a-z][a-z0-9+.-]*:|\/\/)/i.test(target)
const isWeb = (target) => /^(?:https?:)?\/\//i.test(target)
const isIgnored = (target) => /^(?:#|mailto:|tel:|data:|javascript:)/i.test(target)

// Where a reference points inside <dir>, or null (with a reason) when it cannot.
function resolve(file, target) {
  const clean = decodeURI(target.split('#')[0].split('?')[0])
  let relative
  if (clean.startsWith('/')) {
    if (!clean.startsWith(prefix)) return { error: `does not begin with the path prefix ${prefix}` }
    relative = clean.slice(prefix.length)
  } else {
    // Relative: resolved from the URL of the file that holds it.
    const here = `/${path.relative(root, path.dirname(file)).split(path.sep).join('/')}/`.replace('//', '/')
    const joined = path.posix.normalize(here + clean)
    if (joined.startsWith('/../') || joined === '/..') return { error: 'climbs above the site root' }
    relative = joined.slice(1)
  }
  let candidate = path.join(root, relative)
  if (clean === '' ) candidate = file
  if (existsSync(candidate) && statSync(candidate).isDirectory()) candidate = path.join(candidate, 'index.html')
  return existsSync(candidate) ? { ok: true } : { error: 'does not resolve to a file' }
}

function check(file, what, target, { allowWeb }) {
  target = target.trim()
  if (!target || isIgnored(target)) return
  if (isWeb(target)) {
    if (!allowWeb) report(file, what, target, 'is an external address; only <a href> may leave the site')
    return
  }
  if (isExternal(target)) return report(file, what, target, 'uses a scheme this check does not allow')
  const result = resolve(file, target)
  if (result.error) report(file, what, target, result.error)
}

function checkCss(file, css) {
  const urls = css.replace(/\/\*[\s\S]*?\*\//g, '')
  for (const match of urls.matchAll(/url\(\s*(?:"([^"]*)"|'([^']*)'|([^)"'\s][^)]*?))\s*\)/gi)) {
    check(file, 'CSS url()', match[1] ?? match[2] ?? match[3], { allowWeb: false })
  }
}

function checkHtml(file, html) {
  // Inline <style> contents are CSS; inline <script> contents are not markup.
  const body = html.replace(/<style\b[^>]*>([\s\S]*?)<\/style>/gi, (all, css) => { checkCss(file, css); return '' })
    .replace(/<script\b([^>]*)>[\s\S]*?<\/script>/gi, '<script$1></script>')
    .replace(/<!--[\s\S]*?-->/g, '')
  for (const tag of body.matchAll(/<([a-z][a-z0-9-]*)\b([^>]*)>/gi)) {
    const name = tag[1].toLowerCase()
    const attrs = {}
    for (const attr of tag[2].matchAll(/([a-z][a-z0-9:_-]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))/gi)) {
      attrs[attr[1].toLowerCase()] = attr[2] ?? attr[3] ?? attr[4]
    }
    if (attrs.href !== undefined) check(file, `<${name} href>`, attrs.href, { allowWeb: name === 'a' })
    if (attrs.src !== undefined) check(file, `<${name} src>`, attrs.src, { allowWeb: false })
    for (const attrName of ['srcset', 'imagesrcset']) {
      if (attrs[attrName] === undefined) continue
      for (const entry of attrs[attrName].split(',')) {
        check(file, `<${name} ${attrName}>`, entry.trim().split(/\s+/)[0] ?? '', { allowWeb: false })
      }
    }
    if (attrs.style) checkCss(file, attrs.style)
  }
}

if (!existsSync(root)) {
  console.error(`check-links: ${root} does not exist; build first`)
  process.exit(2)
}
let count = 0
for (const file of walk(root)) {
  if (file.endsWith('.html')) { count++; checkHtml(file, readFileSync(file, 'utf8')) }
  else if (file.endsWith('.css')) { count++; checkCss(file, readFileSync(file, 'utf8')) }
}

if (problems.length > 0) {
  console.error(`check-links (${prefix}): ${problems.length} problem${problems.length === 1 ? '' : 's'}`)
  for (const problem of problems) console.error(`  ${problem}`)
  process.exit(1)
}
console.log(`check-links (${prefix}): ${count} files, every link resolves`)
