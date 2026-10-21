// Three is the cap because a place that is about everything is about nothing,
// and the wheel offers one theme at a time.
const MAX_THEMES = 3

// The model is schema-constrained, but its output is still untrusted input to
// a database column, so we re-validate rather than trust the enum.
export function cleanThemes(raw: unknown, allowed: string[]): string[] {
  if (!Array.isArray(raw)) return []
  const out: string[] = []
  for (const item of raw) {
    if (typeof item !== 'string' || !allowed.includes(item) || out.includes(item)) continue
    out.push(item)
    if (out.length === MAX_THEMES) break
  }
  return out
}
