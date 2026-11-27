import { existsSync, readFileSync } from 'node:fs'
import path from 'node:path'
import Image from '@11ty/eleventy-img'

// The prefix is set by the build (the Pages action's base path); locally it is "/".
const rawPrefix = process.env.SITE_PATH_PREFIX || '/'
const pathPrefix = `/${rawPrefix.replace(/^\/+|\/+$/g, '')}/`.replace('//', '/')

const SHOT_DIR = 'src/img/shots'
const IMAGE_WIDTHS = [800, 1600]

// The appearance script is written once: scripts/appearance-core.mjs holds the two
// pure functions (tested), src/js/appearance.js wires them to the page. The build
// strips the module's `export` keywords and inlines both in the page's head.
function appearanceScript() {
  const core = readFileSync('scripts/appearance-core.mjs', 'utf8').replace(/^export /gm, '')
  const wiring = readFileSync('src/js/appearance.js', 'utf8')
  return `(function () {\n${core}\n${wiring}\n})()`
}

// sizes tells the browser how wide the picture is shown, so a column does not fetch the
// largest file; "100vw" is the default for a picture the width of the window.
// className (optional) is added to the figure, e.g. "shot-phone" to hold a tall picture to a phone's width.
async function shot(name, alt, loading, sizes, className) {
  if (!name) throw new Error('shot: a name is required')
  if (!alt || !String(alt).trim()) throw new Error(`shot "${name}": alt text is required and must not be empty`)
  const light = path.join(SHOT_DIR, `${name}.png`)
  if (!existsSync(light)) throw new Error(`shot "${name}": ${light} does not exist`)
  const dark = path.join(SHOT_DIR, `${name}-dark.png`)
  const eager = loading === 'eager'
  const figureClass = className ? `shot ${escapeAttribute(className)}` : 'shot'
  const sizesValue = escapeAttribute(sizes || '100vw')

  // The pictures go to the build's own output folder, so `--output` is honored.
  const outputRoot = this?.eleventy?.directories?.output || '_site/'
  const imageOptions = { outputDir: path.join(outputRoot, 'img/'), urlPath: `${pathPrefix}img/` }

  // Each picture is a link to its full-size PNG (light or dark, matching the one shown), so a
  // reader can see the window at its own size with no script. The link's name says so.
  const picture = async (file, className) => {
    const stats = await Image(file, { widths: IMAGE_WIDTHS, formats: ['webp', 'png'], ...imageOptions })
    const full = await Image(file, { widths: ['auto'], formats: ['png'], ...imageOptions })
    const sources = ['webp', 'png']
      .map((format) => stats[format].map((entry) => `${entry.url} ${entry.width}w`).join(', '))
    const largest = stats.png[stats.png.length - 1]
    const img = `<picture><source type="image/webp" srcset="${sources[0]}" sizes="${sizesValue}"><img src="${largest.url}" srcset="${sources[1]}" sizes="${sizesValue}" width="${largest.width}" height="${largest.height}" alt="${escapeAttribute(alt)}"${eager ? '' : ' loading="lazy"'} decoding="async"></picture>`
    return `<a${className ? ` class="${className}"` : ''} href="${full.png[0].url}" aria-label="${escapeAttribute(`${alt} (opens the full-size picture)`)}">${img}</a>`
  }

  if (existsSync(dark)) {
    return `<figure class="${figureClass}">${await picture(light, 'shot-light')}${await picture(dark, 'shot-dark')}</figure>`
  }
  return `<figure class="${figureClass}">${await picture(light, '')}</figure>`
}

// A key chord is written as adjacent caps (<kbd>⌘</kbd><kbd>K</kbd>). HTML's own form for a
// combination is one <kbd> holding the keys, so the build wraps each run of two or more caps
// with nothing between them in an outer <kbd class="chord">, and the stylesheet draws the
// chord as one cap. Caps with a space, a comma or a word between them stay separate keys.
function wrapChords(html) {
  return html.replace(/(?:<kbd>[^<]*<\/kbd>){2,}/g, (run) => `<kbd class="chord">${run}</kbd>`)
}

function escapeAttribute(text) {
  return String(text).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;')
}

// The license texts are published under /licenses/, copied from where the app keeps them.
const LICENSES = {
  '../LICENSE': 'licenses/gpl-3.0.txt',
  '../Packages/ScriptureKit/Sources/ScriptureUI/Fonts/OFL-Literata.txt': 'licenses/OFL-Literata.txt',
  '../Packages/ScriptureKit/Sources/ScriptureUI/Fonts/OFL-SourceSerif4.txt': 'licenses/OFL-SourceSerif4.txt',
  '../Packages/ScriptureKit/Sources/ScriptureUI/Licenses/GRDB-LICENSE.txt': 'licenses/GRDB-LICENSE.txt',
  '../Packages/ScriptureKit/Sources/ScriptureUI/Licenses/holybooks-LICENSE.txt': 'licenses/holybooks-LICENSE.txt',
}

function escapeHtml(text) {
  return String(text).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
}

// A notice with its phrases made links, each found after the one before it.
function linkNotice(notice, links) {
  let html = ''
  let from = 0
  for (const { phrase, url } of links) {
    const at = notice.indexOf(phrase, from)
    if (at < 0) throw new Error(`linkNotice: "${phrase}" is not in the notice after position ${from}`)
    html += `${escapeHtml(notice.slice(from, at))}<a href="${escapeHtml(url)}">${escapeHtml(phrase)}</a>`
    from = at + phrase.length
  }
  return html + escapeHtml(notice.slice(from))
}

// The credits grouped under their section names, in the order the sections first appear.
function bySection(credits) {
  const sections = []
  for (const credit of credits) {
    let group = sections.find((s) => s.name === credit.section)
    if (!group) sections.push((group = { name: credit.section, credits: [] }))
    group.credits.push(credit)
  }
  return sections
}

// The guide: src/_data/guide.json is the sidebar, src/guide/<slug>.md the pages. The
// collection below is the sidebar with each page's presence, and it throws when the
// two disagree: a file the sidebar does not list, a title that differs from the
// sidebar's, and (with GUIDE_COMPLETE=1) a listed page with no file. Until the guide is
// complete, a listed page with no file is shown in the sidebar as plain text.
function guideCollection(api) {
  const groups = JSON.parse(readFileSync('src/_data/guide.json', 'utf8'))
  const listed = new Map(groups.flatMap((g) => g.pages.map(([slug, title]) => [slug, title])))
  const files = new Map()
  for (const item of api.getAll()) {
    const match = /(?:^|\/)src\/guide\/([^/]+)\.md$/.exec(item.inputPath)
    if (match) files.set(match[1], item.data.title)
  }
  const problems = []
  for (const [slug, title] of files) {
    if (!listed.has(slug)) problems.push(`src/guide/${slug}.md is not in src/_data/guide.json`)
    else if (title !== listed.get(slug)) problems.push(`src/guide/${slug}.md has the title "${title}" but the sidebar says "${listed.get(slug)}"`)
  }
  if (process.env.GUIDE_COMPLETE === '1') {
    for (const slug of listed.keys()) {
      if (!files.has(slug)) problems.push(`guide.json lists "${slug}" but src/guide/${slug}.md does not exist`)
    }
  }
  if (problems.length) throw new Error(`The guide is out of step with its sidebar:\n  ${problems.join('\n  ')}`)
  return groups.map((g) => ({
    group: g.group,
    pages: g.pages.map(([slug, title]) => ({ slug, title, exists: files.has(slug), group: g.group })),
  }))
}

// The page before and after the current one, among the pages that exist.
function guideNeighbours(groups, slug) {
  const pages = groups.flatMap((g) => g.pages).filter((p) => p.exists)
  const at = pages.findIndex((p) => p.slug === slug)
  return { previous: at > 0 ? pages[at - 1] : null, next: at >= 0 && at < pages.length - 1 ? pages[at + 1] : null }
}

export default function (eleventyConfig) {
  eleventyConfig.addCollection('guide', guideCollection)
  eleventyConfig.addFilter('guideNeighbours', guideNeighbours)
  eleventyConfig.addFilter('guideGroupOf', (groups, slug) => groups.find((g) => g.pages.some((p) => p.slug === slug))?.group)

  eleventyConfig.addPassthroughCopy('src/css')
  eleventyConfig.addPassthroughCopy('src/fonts')
  eleventyConfig.addPassthroughCopy({ 'src/img/icon-*.png': 'img' })
  eleventyConfig.addPassthroughCopy(LICENSES)

  // A credit's licenseFile is a resource path in the app ("Fonts/OFL-Literata.txt"); the site keeps the file by its name.
  const licenseHref = (file) => `/licenses/${path.basename(file)}`
  eleventyConfig.addFilter('licenseHref', licenseHref)
  eleventyConfig.addFilter('linkNotice', linkNotice)
  eleventyConfig.addFilter('bySection', bySection)
  // The names of one section's credits under one license, as a list in words ("A, B and C").
  // It throws when nothing matches, so a changed license cannot leave the front page's line empty.
  eleventyConfig.addFilter('namesUnder', (credits, section, license) => {
    const names = credits.filter((c) => c.section === section && c.license === license).map((c) => c.name)
    if (!names.length) throw new Error(`namesUnder: no ${section} credit under "${license}"`)
    return names.length === 1 ? names[0] : `${names.slice(0, -1).join(', ')} and ${names[names.length - 1]}`
  })
  // One credit by its id; it throws when the id is not there, so a renamed credit cannot leave a line empty.
  eleventyConfig.addFilter('creditById', (credits, id) => {
    const credit = credits.find((c) => c.id === id)
    if (!credit) throw new Error(`creditById: no credit with the id "${id}"`)
    return credit
  })

  eleventyConfig.addGlobalData('appearanceScript', appearanceScript)
  eleventyConfig.addAsyncShortcode('shot', shot)
  eleventyConfig.addTransform('chords', function (content) {
    return (this.page.outputPath || '').endsWith('.html') ? wrapChords(content) : content
  })

  return {
    dir: { input: 'src', output: '_site', includes: '_includes', data: '_data' },
    pathPrefix,
    markdownTemplateEngine: 'njk',
    htmlTemplateEngine: 'njk',
  }
}
