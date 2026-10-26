import unittest
from pathlib import Path

import lupa.lua54 as lupa
from luaparser import ast

SCRIPTS = Path(__file__).resolve().parent.parent / 'mod' / 'GothicLockpicking' / 'Scripts'


def load():
    """Returns (lua runtime, Policy module, cfg table from config.lua)."""
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(f'package.path = "{SCRIPTS.as_posix()}/?.lua;" .. package.path')
    return lua, lua.eval('(require("policy"))'), lua.eval('(require("config"))')


def to_list(t):
    return [t[i] for i in range(1, len(t) + 1)]


class LoadTest(unittest.TestCase):
    def test_lua_syntax(self):
        files = sorted(SCRIPTS.glob('*.lua'))
        self.assertTrue(files)
        for f in files:
            with self.subTest(f.name):
                ast.parse(f.read_text(encoding='utf-8'))


class SequenceTest(unittest.TestCase):
    def setUp(self):
        self.lua, self.P, self.cfg = load()

    def seq(self, key, difficulty):
        return to_list(self.P.sequence(key, difficulty, self.cfg))

    def test_hash_known_value(self):
        self.assertEqual(self.P.hash(''), 0x811C9DC5)
        self.assertEqual(self.P.hash('a'), 0xE40C292C)

    def test_sequence_deterministic(self):
        self.assertEqual(self.seq('BP_Chest_C@1,2,3', 1), self.seq('BP_Chest_C@1,2,3', 1))

    def test_sequence_lengths(self):
        for difficulty, (lo, hi) in enumerate([(3, 5), (6, 7), (8, 12)]):
            seen = set()
            for i in range(200):
                s = self.seq(f'k{i}', difficulty)
                self.assertTrue(lo <= len(s) <= hi, (difficulty, s))
                self.assertTrue(set(s) <= {0, 1})
                seen.add(len(s))
            self.assertEqual(seen, set(range(lo, hi + 1)), difficulty)

    def test_unknown_difficulty_is_hard(self):
        self.assertTrue(8 <= len(self.seq('x', 7)) <= 12)


class PressTest(unittest.TestCase):
    def setUp(self):
        self.lua, self.P, self.cfg = load()
        self.p = self.P.new(self.cfg)

    def start(self, key, difficulty=2):
        self.p.start(self.p, key, difficulty)
        return to_list(self.p.seq)

    def press(self, d):
        return self.p.press(self.p, d)

    def test_press_flow(self):
        seq = self.start('door')
        results = [self.press(d) for d in seq]
        self.assertEqual(results, ['ok'] * (len(seq) - 1) + ['open'])
        self.assertEqual(self.press(seq[0]), 'ignored')

    def test_press_without_start_is_ignored(self):
        self.assertEqual(self.press(0), 'ignored')

    def test_wrong_resets(self):
        seq = self.start('door')
        self.press(seq[0]); self.press(seq[1])
        self.assertEqual(self.press(1 - seq[2]), 'wrong')
        self.assertEqual(self.p.pos, 0)
        self.assertEqual(self.p.best['door'], 2)
        self.assertEqual(self.press(seq[0]), 'ok')
        self.assertEqual(self.p.pos, 1)

    def test_best_is_max_not_last(self):
        seq = self.start('door')
        for d in seq[:4]:
            self.press(d)
        self.press(1 - seq[4])
        self.press(seq[0])
        self.press(1 - seq[1])
        self.assertEqual(to_list(self.p.progress(self.p, 'door')), seq[:4])

    def test_progress_unknown_key_is_empty(self):
        self.assertEqual(to_list(self.p.progress(self.p, 'nope')), [])

    def test_keys_are_independent(self):
        a = self.start('A')
        for d in a[:3]:
            self.press(d)
        self.start('B')
        self.assertEqual(to_list(self.p.progress(self.p, 'B')), [])
        self.assertEqual(to_list(self.p.progress(self.p, 'A')), a[:3])


class BreakChanceTest(unittest.TestCase):
    def setUp(self):
        self.lua, self.P, self.cfg = load()

    def chance(self, dex, perk=False):
        return self.P.breakChance(dex, perk, self.cfg)

    def test_break_chance(self):
        lo, hi = self.cfg.dexLow, self.cfg.dexHigh
        self.assertAlmostEqual(self.chance(lo - 5), 0.5)
        self.assertAlmostEqual(self.chance(lo), 0.5)
        self.assertAlmostEqual(self.chance(hi), 0.1)
        self.assertAlmostEqual(self.chance(hi + 50), 0.1)
        self.assertAlmostEqual(self.chance((lo + hi) / 2), 0.3)
        self.assertAlmostEqual(self.chance(lo, True), 0.25)


if __name__ == '__main__':
    unittest.main()
