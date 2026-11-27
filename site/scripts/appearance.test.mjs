import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readChoice, apply, effective, toggled } from './appearance-core.mjs'

const stub = (values) => ({ getItem: (key) => (key in values ? values[key] : null) })
const root = (appearance) => ({ dataset: appearance ? { appearance } : {} })

test('a stored light is read', () => assert.equal(readChoice(stub({ appearance: 'light' })), 'light'))
test('a stored dark is read', () => assert.equal(readChoice(stub({ appearance: 'dark' })), 'dark'))
test('nothing stored is system', () => assert.equal(readChoice(stub({})), 'system'))
test('a stale sepia counts as nothing stored', () => assert.equal(readChoice(stub({ appearance: 'sepia' })), 'system'))
test('a stored system counts as nothing stored', () => assert.equal(readChoice(stub({ appearance: 'system' })), 'system'))
test('junk counts as nothing stored', () => assert.equal(readChoice(stub({ appearance: 'neon' })), 'system'))
test('storage that throws is system', () => assert.equal(readChoice({ getItem() { throw new Error('denied') } }), 'system'))
test('no storage at all is system', () => assert.equal(readChoice(undefined), 'system'))

test('system removes the attribute', () => { const r = root('dark'); apply('system', r); assert.equal(r.dataset.appearance, undefined) })
test('light sets the attribute', () => { const r = root(); apply('light', r); assert.equal(r.dataset.appearance, 'light') })
test('dark sets the attribute', () => { const r = root(); apply('dark', r); assert.equal(r.dataset.appearance, 'dark') })
test('a value that is not an appearance removes the attribute', () => { const r = root('dark'); apply('sepia', r); assert.equal(r.dataset.appearance, undefined) })

test('nothing stored on a light system shows light', () => assert.equal(effective('system', false), 'light'))
test('nothing stored on a dark system shows dark', () => assert.equal(effective('system', true), 'dark'))
test('a stored light shows light on a dark system', () => assert.equal(effective('light', true), 'light'))
test('a stored dark shows dark on a light system', () => assert.equal(effective('dark', false), 'dark'))

test('a press with nothing stored on a light system goes dark', () => assert.equal(toggled('system', false), 'dark'))
test('a press with nothing stored on a dark system goes light', () => assert.equal(toggled('system', true), 'light'))
test('a press on a stored light goes dark', () => assert.equal(toggled('light', true), 'dark'))
test('a press on a stored dark goes light', () => assert.equal(toggled('dark', false), 'light'))
test('a stale sepia read from storage toggles as nothing stored', () => {
  assert.equal(toggled(readChoice(stub({ appearance: 'sepia' })), false), 'dark')
  assert.equal(toggled(readChoice(stub({ appearance: 'sepia' })), true), 'light')
})
test('storage that throws toggles by the system', () => {
  const broken = { getItem() { throw new Error('denied') } }
  assert.equal(toggled(readChoice(broken), false), 'dark')
  assert.equal(toggled(readChoice(broken), true), 'light')
})
