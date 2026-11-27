import PDFKit
import Foundation

// ---------- 1. words with positions (per-character PDFPage.selection(for: NSRange).bounds(for:)) ----------
struct W { var t: String; var x0: Double; var x1: Double; var y: Double; var c: Double { (x0 + x1) / 2 } }

func words(_ page: PDFPage) -> [W] {
  let ns = (page.string ?? "") as NSString
  var out: [W] = []
  var cur: W? = nil
  func flush() { if let w = cur { out.append(w); cur = nil } }
  for i in 0..<ns.length {
    let c = ns.substring(with: NSRange(location: i, length: 1))
    if c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { flush(); continue }
    guard let b = page.selection(for: NSRange(location: i, length: 1))?.bounds(for: page) else { continue }
    let y = Double(b.minY), x0 = Double(b.minX), x1 = Double(b.maxX)
    if var w = cur, abs(w.y - y) < 2, x0 - w.x1 < 2.0, x0 >= w.x0 { w.t += c; w.x1 = x1; cur = w }
    else { flush(); cur = W(t: c, x0: x0, x1: x1, y: y) }
  }
  flush()
  return out
}

struct Line { var y: Double; var ws: [W]; var page: Int }
func lines(_ ws: [W], page: Int) -> [Line] {
  var ls: [Line] = []
  for w in ws.sorted(by: { $0.y > $1.y }) {
    if let l = ls.last, abs(l.y - w.y) < 2.5 { ls[ls.count - 1].ws.append(w) } else { ls.append(Line(y: w.y, ws: [w], page: page)) }
  }
  for i in ls.indices { ls[i].ws.sort { $0.x0 < $1.x0 } }
  return ls
}

// ---------- 2. load ----------
guard CommandLine.arguments.count > 1, let doc = PDFDocument(url: URL(fileURLWithPath: CommandLine.arguments[1])) else { print("usage: parse <pdf>"); exit(1) }
var pageLines: [[Line]] = []
for p in 0..<doc.pageCount { pageLines.append(lines(words(doc.page(at: p)!), page: p + 1)) }

// ---------- 3. column geometry from the page-1 header ----------
func find(_ t: String, in ws: [W]) -> [W] { ws.filter { $0.t == t } }
guard let hdr = pageLines[0].first(where: { $0.ws.contains { $0.t == "Wisdom" } }) else { print("no header row"); exit(1) }
let hWk = find("Wk", in: hdr.ws)[0], hWis = find("Wisdom", in: hdr.ws)[0]
let hChp = find("Chp", in: hdr.ws), hOT = find("OT/NT", in: hdr.ws)[0]
let hMeet = find("Meeting", in: hdr.ws).first
let hasDate = hMeet != nil
let bWk = (hWk.x1 + hWis.x0) / 2                 // Wk | Wisdom
let bWisChp = (hWis.c + hChp[0].c) / 2            // Wisdom book | Wisdom chapter (only for numeric tokens)
let bOT = (hChp[0].c + hOT.x0) / 2                // Wisdom chp | OT/NT book
let bOTChp = hChp[1].x0 - 8                       // OT/NT book | OT/NT chapter
let dateX = hasDate ? hChp[1].x1 + 8 : Double.infinity // words starting right of this are the Meeting Date cell
let expectedRows = hasDate ? 4 : 5
print(String(format: "geometry: wk<%.0f wisBook|wisChp %.0f wisdom|ot %.0f otBook|otChp %.0f dateX %.0f hasDate %@", bWk, bWisChp, bOT, bOTChp, dateX, hasDate ? "yes" : "no"))

// ---------- 4. classify lines ----------
func isNum(_ s: String) -> Bool { s.range(of: #"^\d+([:\-–,]\d+)*$"#, options: .regularExpression) != nil }
func join(_ a: String, _ b: String) -> String {
  if a.isEmpty { return b }; if b.isEmpty { return a }
  if let f = b.unicodeScalars.first, CharacterSet.lowercaseLetters.contains(f), b.count <= 2 { return a + b }
  return a + " " + b
}
func cap(_ s: String) -> String { s }

struct Row {
  var y: Double; var page: Int
  var wk = ""; var wisBook = ""; var wisChp = ""; var otBook = ""; var otChp = ""; var date = ""
  var isDate: Bool { !date.isEmpty && wisBook.isEmpty && wisChp.isEmpty && otBook.isEmpty && otChp.isEmpty }
  var isReading: Bool { !otChp.isEmpty }
  var isFragment: Bool { !isDate && otChp.isEmpty && wisChp.isEmpty && (!wisBook.isEmpty || !otBook.isEmpty) }
}
func parse(_ l: Line) -> Row {
  var r = Row(y: l.y, page: l.page)
  for w in l.ws {
    if hasDate && w.x0 >= dateX { r.date = r.date.isEmpty ? w.t : r.date + " " + w.t; continue }
    if w.c < bWk { r.wk = join(r.wk, w.t) }
    else if w.c < bOT {
      if isNum(w.t) && w.c >= bWisChp { r.wisChp = join(r.wisChp, w.t) } else { r.wisBook = join(r.wisBook, w.t) }
    }
    else if w.c < bOTChp { r.otBook = join(r.otBook, w.t) }
    else { r.otChp = join(r.otChp, w.t) }
  }
  return r
}

struct Item { var row: Row; var gapBefore: Bool; var pageStart: Bool }
var items: [Item] = []
var unplaced: [String] = []
for (pi, ls) in pageLines.enumerated() {
  var rows: [Row] = []
  for l in ls {
    if pi == 0 && l.y >= hdr.y - 1 { continue }   // title + header row
    rows.append(parse(l))
  }
  // raw gaps (measured between consecutive text lines, wrapped fragments included)
  var rawGap: [Bool] = rows.indices.map { $0 > 0 ? rows[$0 - 1].y - rows[$0].y > 28 : false }
  // attach wrapped fragments (no chapter anywhere on the line) to the nearest reading row within 16pt
  var consumed = Set<Int>()
  for (i, r) in rows.enumerated() where r.isFragment {
    var best: Int? = nil; var bd = 17.0
    for (j, o) in rows.enumerated() where o.isReading && abs(o.y - r.y) < bd { best = j; bd = abs(o.y - r.y) }
    guard let b = best else { unplaced.append("p\(r.page) y\(Int(r.y)) \(r.wisBook) | \(r.otBook)"); continue }
    let above = rows[b].y < r.y   // fragment printed above the row => its text comes first
    rows[b].wisBook = above ? join(r.wisBook, rows[b].wisBook) : join(rows[b].wisBook, r.wisBook)
    rows[b].otBook = above ? join(r.otBook, rows[b].otBook) : join(rows[b].otBook, r.otBook)
    consumed.insert(i)
  }
  var pendingGap = false
  var first = true
  for (i, r) in rows.enumerated() {
    pendingGap = pendingGap || rawGap[i]
    if consumed.contains(i) || r.isFragment { continue }
    items.append(Item(row: r, gapBefore: pendingGap, pageStart: first))
    pendingGap = false; first = false
  }
}

// ---------- 5. weeks ----------
struct Week { var rows: [Row] = []; var date = ""; var wkNum: Int? = nil; var pages: Set<Int> = []; var hadDateRow = false }
var weeks: [Week] = []
var cur = Week()
func close() { if !cur.rows.isEmpty || !cur.date.isEmpty { weeks.append(cur) }; cur = Week() }
for it in items {
  if it.gapBefore { close() }
  if it.pageStart && cur.rows.count >= expectedRows { close() }
  let r = it.row
  if r.isDate {
    if cur.rows.isEmpty, !weeks.isEmpty, !weeks[weeks.count - 1].hadDateRow { weeks[weeks.count - 1].date = r.date; weeks[weeks.count - 1].hadDateRow = true }  // date row opened a new page
    else { cur.date = r.date; cur.hadDateRow = true; close() }
    continue
  }
  cur.rows.append(r); cur.pages.insert(r.page)
  if let n = Int(r.wk) { cur.wkNum = n }
}
close()

// ---------- 6. output ----------
let known: Set<String> = ["Genesis","Exodus","Leviticus","Numbers","Deuteronomy","Joshua","Judges","Ruth","1 Samuel","2 Samuel","1 Kings","2 Kings","1 Chronicles","2 Chronicles","Ezra","Nehemiah","Esther","Job","Psalms","Proverbs","Ecclesiastes","Song","Isaiah","Jeremiah","Lamentations","Ezekiel","Daniel","Hosea","Joel","Amos","Obadiah","Jonah","Micah","Nahum","Habakkuk","Zephaniah","Haggai","Zechariah","Malachi","Matthew","Mark","Luke","John","Acts","Romans","1 Corinthians","2 Corinthians","Galatians","Ephesians","Philippians","Colossians","1 Thessalonians","2 Thessalonians","1 Timothy","2 Timothy","Titus","Philemon","Hebrews","James","1 Peter","2 Peter","1 John","2,3 John, Jude","Jude","Revelation"]
let labels: Set<String> = ["NT Focus", "NT Focus Week", "Holidays"]
var warnings: [String] = []
var prev = 0
var countBad: [String] = []
var totalReadings = 0
var inherited = 0
var blank: [String] = []
for (i, w) in weeks.enumerated() {
  let n = w.wkNum ?? (prev + 1)
  if w.wkNum == nil { warnings.append("week index \(i + 1): no Wk number found, assumed \(n)") }
  else if n != prev + 1 { warnings.append("week sequence: \(prev) -> \(n)") }
  prev = n
  if w.rows.count != expectedRows { countBad.append("W\(n): \(w.rows.count) rows") }
  if hasDate && !w.hadDateRow { warnings.append("W\(n): no date row") }
  totalReadings += w.rows.count
  // a vertically merged label ("Holidays", "NT Focus Week") is printed once, mid-span: give it to the label-less rows of the same week
  var wrows = w.rows
  let lab = Set(wrows.filter { $0.wisChp.isEmpty && !$0.wisBook.isEmpty }.map { $0.wisBook })
  if lab.count == 1, let l = lab.first {
    for j in wrows.indices where wrows[j].wisBook.isEmpty && wrows[j].wisChp.isEmpty { wrows[j].wisBook = l; inherited += 1 }
  }
  for (k, r) in wrows.enumerated() {
    let wis: String
    if r.wisChp.isEmpty && !r.wisBook.isEmpty { wis = "none[\(r.wisBook)]" ; if !labels.contains(r.wisBook) { warnings.append("W\(n) r\(k + 1): odd wisdom cell '\(r.wisBook)'") } }
    else if r.wisBook.isEmpty && r.wisChp.isEmpty { wis = "none[blank]"; blank.append("W\(n)r\(k + 1)") }
    else {
      wis = "\(r.wisBook == "Song" ? "Song of Solomon" : r.wisBook) \(r.wisChp)"
      if !known.contains(r.wisBook) { warnings.append("W\(n) r\(k + 1): unknown wisdom book '\(r.wisBook)'") }
      if r.wisChp.isEmpty { warnings.append("W\(n) r\(k + 1): wisdom book without chapter") }
    }
    if !known.contains(r.otBook) { warnings.append("W\(n) r\(k + 1): unknown OT/NT book '\(r.otBook)'") }
    if r.otChp.isEmpty { warnings.append("W\(n) r\(k + 1): OT/NT without chapter") }
    let d = hasDate ? "  | meeting: \(w.date.isEmpty ? "-" : w.date)" : ""
    print("W\(n) r\(k + 1)  wisdom: \(wis)  | ot/nt: \(r.otBook) \(r.otChp)\(d)  [p\(r.page)]")
  }
}
print("---- SUMMARY")
print("weeks: \(weeks.count)  readings: \(totalReadings)  expected rows/week: \(expectedRows)")
print("week row-count mismatches: \(countBad.isEmpty ? "none" : countBad.joined(separator: "; "))")
print("rows given a vertically-merged label by inheritance: \(inherited)")
print("blank wisdom cells (no text at all, no label): \(blank.count): \(blank.joined(separator: " "))")
print("unplaced fragments: \(unplaced.isEmpty ? "none" : unplaced.joined(separator: "; "))")
print("warnings (\(warnings.count)):"); warnings.forEach { print("  " + $0) }
if hasDate {
  print("---- DATE CELLS")
  for (i, w) in weeks.enumerated() { print("W\(w.wkNum ?? i + 1): \(w.date.isEmpty ? "-" : w.date)") }
}
