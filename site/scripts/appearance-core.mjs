// The appearance choice, as pure functions. The build inlines this file (with
// `export` stripped) into every page's head, so it must stay plain ES5-style
// statements with no imports.
export const APPEARANCES = ['system', 'light', 'dark']
export const STORAGE_KEY = 'appearance'

// The stored choice ("light" or "dark"), or "system" (nothing stored) when there is
// none, it is anything else (a stale "sepia" or "system" included), storage is
// missing, or storage throws (private modes).
export function readChoice(storage) {
  try {
    const value = storage.getItem(STORAGE_KEY)
    return value === 'light' || value === 'dark' ? value : 'system'
  } catch (error) {
    return 'system'
  }
}

// What the page shows: the choice, or the system's setting while the choice is "system".
export function effective(choice, systemIsDark) {
  if (choice === 'light' || choice === 'dark') return choice
  return systemIsDark ? 'dark' : 'light'
}

// What a press switches to: the opposite of what is showing now.
export function toggled(choice, systemIsDark) {
  return effective(choice, systemIsDark) === 'dark' ? 'light' : 'dark'
}

// Sets data-appearance on the root element; "system" removes it, so the system's
// light or dark decides.
export function apply(choice, root) {
  if (choice === 'light' || choice === 'dark') {
    root.dataset.appearance = choice
  } else {
    delete root.dataset.appearance
  }
}
