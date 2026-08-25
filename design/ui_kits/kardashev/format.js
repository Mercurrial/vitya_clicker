/* KARDASHEV number formatting — scientific notation, tabular discipline. */
(function () {
  function group(n) {
    return Math.floor(n).toLocaleString("en-US");
  }
  function parts(n) {
    if (n <= 0) return { m: "0.00", e: 0 };
    const e = Math.floor(Math.log10(n));
    let m = n / Math.pow(10, e);
    let ms = m.toFixed(2);
    if (ms === "10.00") return { m: "1.00", e: e + 1 }; // rounding carry
    return { m: ms, e: e };
  }
  // Hero: "<1000" -> grouped int; else { m, e } for "m.mm × 10ⁿ"
  function hero(n) {
    if (n < 1000) return { plain: group(n) };
    return parts(n);
  }
  // Compact: "<1000" -> grouped int; else "m.mme+n"
  function compact(n) {
    if (n < 1000) return group(n);
    const p = parts(n);
    return p.m + "e" + p.e;
  }
  window.KFmt = { group: group, parts: parts, hero: hero, compact: compact };
})();
