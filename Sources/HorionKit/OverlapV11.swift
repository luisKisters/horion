import Foundation

/// Overlap layout (design/mockup-v18, rule "New", decided 2026-11-23). Pure: minutes in, fractions of the day column out.
/// Nothing is ever folded into "+N". It works in points of the column (`width`), as the blocks are drawn.
///
/// 1. Paint order: by start; starts within one title line (22 min) of the first start of a run count as together, and among
///    those the longer goes first (behind). A long event is the background, later ones sit on top of it.
/// 2. Cascade: a block sits on the top-most painted block running at its start that it does not clash with, one indent step in
///    (less if the host would get too narrow). Two blocks clash when they overlap and start less than one title line apart:
///    one on top of the other would cover its title. A block on a split block stays inside that block's span.
/// 3. Much shorter tucks in: a block at most half as long as everything it clashes with goes in the rightmost free spot right
///    of their titles, taking at most half of its host; they keep their width.
/// 4. Similar lengths share: otherwise it joins the blocks it clashes with and they split their span equally, the longer on the
///    left. Too narrow: the span grows left into the indent (the background's colour bar stays), never over another title.
/// 5. Any free spot off the clashing titles. 6. No room (4+ titles in one line): on the block that started first there.
/// There is no "5 at once: side by side" switch any more.
public enum OverlapV11 {
    /// Points of indent per cascade level.
    public static let indentStep = 12.0
    /// Minutes one title line covers (`TITLE_MIN`).
    public static let titleMinutes = 22
    /// The day column width the layout assumes when it is not told (points, inside the create strip).
    public static let defaultWidth = 160.0
    /// The narrowest block whose title still reads (52 pt), plus the gap after it. A narrow column (under 112 pt) uses half of it.
    public static let minWidth = 56.0
    static func minWidth(_ W: Double) -> Double { min(minWidth, W / 2) }
    /// The width a title takes in a column `W` wide: 60 pt, or what leaves half the column beside it.
    static func titleWidth(_ W: Double) -> Double { min(titleWidth, W / 2 - gap) }
    /// A block behind keeps this much showing on the left when the ones on top grow into the indent.
    public static let bar = 4.0
    /// The gap on the right of every block (`GridGeometry.gapRight`) and the width a title takes.
    static let gap = 4.0, titleWidth = 60.0
    static let eps = 1e-6

    private final class Group { var members: [Block]; var hosted: Bool; init(_ m: [Block], hosted: Bool) { members = m; self.hosted = hosted } }
    private final class Block {
        let id: String, order: Int, s: Int, en: Int
        var a = 0.0, b = 0.0, group: Group?
        var length: Int { en - s }
        init(id: String, order: Int, s: Int, en: Int) { self.id = id; self.order = order; self.s = s; self.en = en }
    }

    /// `placements` are in drawing order (each later one on top); `cut` is set on every block but the first of its cluster
    /// (`.ev.stk`: the 1 pt window-coloured ring). `width` is the day column in points.
    public static func layout(_ input: [V5Item], width: Double = defaultWidth) -> [V5Placement] {
        let W = max(width, 1)
        var w = input.enumerated().map { i, it in
            Block(id: it.id, order: i, s: it.startMinute,
                  en: it.isShort ? it.startMinute + OverlapV5.shortSpan : max(it.endMinute, it.startMinute + 15))
        }
        w.sort { a, b in
            if a.s != b.s { return a.s < b.s }
            if a.length != b.length { return a.length > b.length }
            return a.order < b.order
        }
        // Clusters: a block that starts at or after the end of everything before it starts a new one.
        var clusters: [[Block]] = []
        var end = -1
        for x in w {
            if clusters.isEmpty || x.s >= end { clusters.append([]); end = -1 }
            clusters[clusters.count - 1].append(x)
            end = max(end, x.en)
        }
        var out: [V5Placement] = []
        for cluster in clusters {
            let c = place(cluster, W: W)
            for (k, x) in c.enumerated() {
                out.append(V5Placement(id: x.id, left: x.a / W, width: (x.b - x.a) / W, indent: 0, level: 0, cut: k > 0,
                                       startMinute: x.s, endMinute: x.en))
            }
        }
        return out
    }

    private static func place(_ cluster: [Block], W: Double) -> [Block] {
        let minWidth = minWidth(W), titleWidth = titleWidth(W)
        // 1. Paint order. `cluster` is sorted by start.
        var run: [ObjectIdentifier: Int] = [:]
        var t0 = Int.min / 2
        for x in cluster { if x.s - t0 >= titleMinutes { t0 = x.s }; run[ObjectIdentifier(x)] = t0 }
        let c = cluster.sorted { p, q in
            let rp = run[ObjectIdentifier(p)]!, rq = run[ObjectIdentifier(q)]!
            if rp != rq { return rp < rq }
            if p.length != q.length { return p.length > q.length }
            if p.s != q.s { return p.s < q.s }
            return p.order < q.order
        }
        func meets(_ p: Block, _ q: Block) -> Bool { p.en > q.s && p.s < q.en }
        func clashes(_ p: Block, _ q: Block) -> Bool { meets(p, q) && abs(p.s - q.s) < titleMinutes }
        func box(_ o: Block) -> (Double, Double) { (o.a, o.a + min(o.b - o.a - gap, titleWidth) + gap) }
        func free(_ lo: Double, _ hi: Double, _ obs: [(Double, Double)]) -> [(Double, Double)] {
            var iv = [(lo, hi)]
            for (p, q) in obs {
                iv = iv.flatMap { u, v -> [(Double, Double)] in
                    if q <= u || p >= v { return [(u, v)] }
                    return [(u, p), (q, v)].filter { $0.1 - $0.0 > 0 }
                }
            }
            return iv
        }
        var done: [Block] = []
        var index: [ObjectIdentifier: Int] = [:]
        func commit(_ x: Block) { index[ObjectIdentifier(x)] = done.count; done.append(x) }

        for x in c {
            let under = done.filter { meets($0, x) }
            // 2. Cascade on the top-most block running at its start that it does not clash with.
            let host = under.last { $0.s <= x.s && !clashes($0, x) }
            let ha = host?.a ?? 0, hb = host?.b ?? W
            let step = host == nil ? 0 : max(bar, min(indentStep, hb - ha - minWidth))
            let a = ha + step, b = hb
            let near = under.filter { clashes($0, x) && $0.a < b && $0.b > a }
            func put(_ p: Double, _ q: Double) { x.a = p; x.b = q; x.group = Group([x], hosted: host != nil); commit(x) }
            if near.isEmpty { put(a, b); continue }
            func spot() -> (Double, Double)? { free(a, b, near.map(box)).filter { $0.1 - $0.0 >= minWidth - eps }.last }
            func take(_ f: (Double, Double)) { put(max(f.0, f.1 - max(minWidth, (hb - ha) / 2)), f.1) }
            // 3. Much shorter than everything it clashes with: tuck in right of their titles.
            let peers = near.filter { 2 * x.length > $0.length }
            if peers.isEmpty, let f = spot() { take(f); continue }
            // 4. Similar length: share the span of the blocks it clashes with (and those sharing with them, still running).
            var shared = false
            for with in peers.isEmpty ? [near] : [peers, near] {
                var g: [Block] = []
                for o in with { for m in o.group!.members where meets(m, x) && !g.contains(where: { $0 === m }) { g.append(m) } }
                let prev = g
                g.append(x)
                let lo0 = prev.map(\.a).min()!, hi = prev.map(\.b).max()!
                let obs: [(Double, Double)] = done.filter { o in !g.contains { $0 === o } && g.contains { clashes(o, $0) } }.map { o in
                    let after = prev.contains { m in index[ObjectIdentifier(o)]! > index[ObjectIdentifier(m)]! && clashes(o, m) }
                    return after ? (o.a, o.b) : box(o)
                }
                let hosted = host != nil || prev.contains { $0.group!.hosted }
                let fr = free(hosted ? bar : 0, hi, obs).first { $0.0 <= lo0 + eps && $0.1 >= hi - eps }
                let lo = fr.map { max($0.0, min(lo0, hi - minWidth * Double(g.count))) } ?? lo0
                if (hi - lo) / Double(g.count) < minWidth - eps { continue }
                g.sort { p, q in p.length != q.length ? p.length > q.length : (p.s != q.s ? p.s < q.s : p.order < q.order) }
                let group = Group(g, hosted: hosted), wd = (hi - lo) / Double(g.count)
                for (k, o) in g.enumerated() { o.a = lo + Double(k) * wd; o.b = lo + Double(k + 1) * wd; o.group = group }
                commit(x); shared = true
                break
            }
            if shared { continue }
            // 5. Any free spot off the clashing titles.
            if let f = spot() { take(f); continue }
            // 6. No room in that title line: on the block that started first there, one step in if they start together.
            let o = near.min { p, q in p.s != q.s ? p.s < q.s : p.length < q.length }!
            put(o.a + (o.s < x.s ? 0 : indentStep), o.b)
        }
        return c
    }

    /// The most spans running at one moment (a span ends before one that starts at its end).
    public static func concurrency(_ spans: [(Int, Int)]) -> Int {
        var edges: [(at: Int, d: Int)] = []
        for sp in spans { edges.append((sp.0, 1)); edges.append((sp.1, -1)) }
        edges.sort { a, b in a.at != b.at ? a.at < b.at : a.d < b.d }
        var n = 0, m = 0
        for e in edges { n += e.d; m = max(m, n) }
        return m
    }
}
