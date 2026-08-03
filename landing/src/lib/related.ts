/**
 * Pick sibling entries to link to from a detail page.
 *
 * Walks forward through the id-sorted list and wraps at the end, so the set
 * forms a ring: every entry hands out `count` links and receives exactly
 * `count` back. That matters more than relevance here — a ring means no page
 * in the collection is ever left without inbound internal links, which is the
 * whole point of the module.
 */
export function ringNeighbours<T extends { id: string }>(
  entries: T[],
  current: string,
  count = 3
): T[] {
  const sorted = [...entries].sort((a, b) => a.id.localeCompare(b.id));
  const start = sorted.findIndex((entry) => entry.id === current);
  if (start < 0) return [];

  const take = Math.min(count, sorted.length - 1);
  return Array.from(
    { length: take },
    (_, step) => sorted[(start + 1 + step) % sorted.length]
  );
}
