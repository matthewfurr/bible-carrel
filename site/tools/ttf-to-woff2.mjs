// One-off converter: TrueType (.ttf) to WOFF2, with Node's built-in Brotli.
// No dependency. Tables are stored untransformed (the glyf/loca null transform,
// WOFF2 spec section 5.1), which is valid and decodes in every browser.
//
//   node site/tools/ttf-to-woff2.mjs <font.ttf> <font.woff2>
//
// Not part of the build: the WOFF2 files are committed.
import { readFileSync, writeFileSync } from 'node:fs'
import { brotliCompressSync, constants } from 'node:zlib'

const KNOWN_TAGS = ['cmap', 'head', 'hhea', 'hmtx', 'maxp', 'name', 'OS/2', 'post', 'cvt ', 'fpgm', 'glyf', 'loca', 'prep', 'CFF ', 'VORG', 'EBDT', 'EBLC', 'gasp', 'hdmx', 'kern', 'LTSH', 'PCLT', 'VDMX', 'vhea', 'vmtx', 'BASE', 'GDEF', 'GPOS', 'GSUB', 'EBSC', 'JSTF', 'MATH', 'CBDT', 'CBLC', 'COLR', 'CPAL', 'SVG ', 'sbix', 'acnt', 'avar', 'bdat', 'bloc', 'bsln', 'cvar', 'fdsc', 'feat', 'fmtx', 'fvar', 'gvar', 'hsty', 'just', 'lcar', 'mort', 'morx', 'opbd', 'prop', 'trak', 'Zapf', 'Silf', 'Glat', 'Gloc', 'Feat', 'Sill']

const [input, output] = process.argv.slice(2)
if (!input || !output) {
  console.error('usage: node ttf-to-woff2.mjs <font.ttf> <font.woff2>')
  process.exit(2)
}

const ttf = readFileSync(input)
const flavor = ttf.readUInt32BE(0)
const numTables = ttf.readUInt16BE(4)
const tables = []
for (let i = 0; i < numTables; i++) {
  const entry = 12 + i * 16
  const tag = ttf.toString('latin1', entry, entry + 4)
  const offset = ttf.readUInt32BE(entry + 8)
  const length = ttf.readUInt32BE(entry + 12)
  tables.push({ tag, data: ttf.subarray(offset, offset + length) })
}
tables.sort((a, b) => (a.tag < b.tag ? -1 : 1))

const base128 = (value) => {
  const bytes = []
  do { bytes.unshift(value & 0x7f); value = Math.floor(value / 128) } while (value > 0)
  return Buffer.from(bytes.map((byte, i) => (i < bytes.length - 1 ? byte | 0x80 : byte)))
}

const pad4 = (n) => (n + 3) & ~3
let sfntSize = 12 + 16 * tables.length
const directory = []
for (const { tag, data } of tables) {
  sfntSize += pad4(data.length)
  const index = KNOWN_TAGS.indexOf(tag)
  const transform = tag === 'glyf' || tag === 'loca' ? 3 : 0
  const head = index >= 0 ? Buffer.from([(transform << 6) | index]) : Buffer.concat([Buffer.from([(transform << 6) | 63]), Buffer.from(tag, 'latin1')])
  directory.push(head, base128(data.length))
}
const compressed = brotliCompressSync(Buffer.concat(tables.map((t) => t.data)), {
  params: { [constants.BROTLI_PARAM_QUALITY]: 11, [constants.BROTLI_PARAM_MODE]: constants.BROTLI_MODE_FONT },
})

const dir = Buffer.concat(directory)
const header = Buffer.alloc(48)
header.write('wOF2', 0, 'latin1')
header.writeUInt32BE(flavor, 4)
header.writeUInt32BE(pad4(48 + dir.length + compressed.length), 8)
header.writeUInt16BE(tables.length, 12)
header.writeUInt32BE(sfntSize, 16)
header.writeUInt32BE(compressed.length, 20)
const body = Buffer.concat([header, dir, compressed])
writeFileSync(output, Buffer.concat([body, Buffer.alloc(pad4(body.length) - body.length)]))
console.log(`${input} -> ${output}: ${ttf.length} -> ${body.length} bytes`)
