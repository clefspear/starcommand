#!/usr/bin/env python3
"""Reference implementation of portable PRNG for starcommand.

Generates the test fixture prng_reference.txt with known sequences
that every shell implementation must reproduce exactly.

Algorithm: xorshift32 (Marsaglia 2003)
Seeding: DJB2 hash of hostname + "." + date
"""

import struct
import sys


def xorshift32(state: int) -> int:
    """Advance xorshift32 state, return next output."""
    state &= 0xFFFFFFFF
    state ^= (state << 13) & 0xFFFFFFFF
    state ^= state >> 17
    state ^= (state << 5) & 0xFFFFFFFF
    return state & 0xFFFFFFFF


def djb2(s: str) -> int:
    """DJB2 hash of a string, returns 32-bit unsigned."""
    h = 5381
    for c in s:
        h = ((h << 5) + h + ord(c)) & 0xFFFFFFFF
    if h == 0:
        h = 1
    return h


def random_int(state: int, lo: int, hi: int) -> tuple[int, int]:
    """Return (next_state, value) where value is in [lo, hi] inclusive."""
    state = xorshift32(state)
    val = lo + (state % (hi - lo + 1))
    return state, val


def sequence(seed: int, count: int = 20) -> list[int]:
    """Generate `count` raw xorshift32 outputs starting from `seed`."""
    state = seed
    out = []
    for _ in range(count):
        state = xorshift32(state)
        out.append(state)
    return out


def generate_fixture(output_path: str) -> None:
    seeds = {
        "seed=42": 42,
        "seed=12345": 12345,
        "seed=999999": 999999,
        "seed=3141592653": 3141592653 & 0xFFFFFFFF,
        "seed=1": 1,
    }
    lines = []
    for label, seed in seeds.items():
        lines.append(label)
        vals = sequence(seed, 20)
        for i, v in enumerate(vals, 1):
            lines.append(f"  {i:2d}: {v}")
        lines.append("")

    # Also validate djb2 for a known input to help verify cross-shell
    known_input = "myhost.2026.05.18"
    d = djb2(known_input)
    lines.append("# DJB2 verification")
    lines.append(f'hostname+date: "{known_input}" -> {d}')
    lines.append("")

    text = "\n".join(lines) + "\n"
    with open(output_path, "w") as f:
        f.write(text)
    print(f"Wrote {output_path} ({len(text)} bytes)")
    print(text)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "tests/prng_reference.txt"
    generate_fixture(out)
