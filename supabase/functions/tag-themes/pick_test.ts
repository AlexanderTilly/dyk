import { assertEquals } from 'jsr:@std/assert'
import { cleanThemes } from './pick.ts'

const allowed = ['food_drink', 'churches', 'ghosts', 'the_sea']

Deno.test('keeps allowed keys in order', () => {
  assertEquals(cleanThemes(['churches', 'ghosts'], allowed), ['churches', 'ghosts'])
})
Deno.test('drops unknown keys and non-string entries', () => {
  assertEquals(cleanThemes(['pizza', 'churches', 7, null], allowed), ['churches'])
})
Deno.test('de-duplicates', () => {
  assertEquals(cleanThemes(['ghosts', 'ghosts', 'churches'], allowed), ['ghosts', 'churches'])
})
Deno.test('caps at three', () => {
  assertEquals(cleanThemes(['food_drink', 'churches', 'ghosts', 'the_sea'], allowed), [
    'food_drink', 'churches', 'ghosts',
  ])
})
Deno.test('cap counts only valid keys', () => {
  assertEquals(cleanThemes(['x', 'y', 'z', 'ghosts'], allowed), ['ghosts'])
})
Deno.test('non-arrays give empty list', () => {
  assertEquals(cleanThemes(null, allowed), [])
  assertEquals(cleanThemes('churches', allowed), [])
  assertEquals(cleanThemes(3, allowed), [])
})
