# Portable PRNG Specification

## Algorithm: xorshift32

We use the standard xorshift32 algorithm (Marsaglia, 2003). It was chosen over an LCG because it uses only XOR and shift operations — no multiplication or modulo — making it trivial to implement identically across fish, zsh, bash, and PowerShell regardless of each shell's integer-width quirks.

### State
- 32-bit unsigned integer, denoted `s`.
- Must be initialized to a non-zero value (the seed). If the seed is zero, the generator produces only zeros; the seeding scheme guarantees a non-zero seed.

### Next-function

```
xorshift32(s):
  s  ← s XOR (s << 13)
  s  ← s XOR (s >> 17)
  s  ← s XOR (s << 5)
  return s
```

All intermediate left-shift operations are masked to 32 bits (`& 0xFFFFFFFF`). The right-shift is logical (zero-fill), which is the default in all four target shells on unsigned values; in signed-arithmetic shells (bash, zsh, fish), right-shift of a positive value is also logical, so this works correctly as long as `s` stays positive (which masking guarantees).

### Reference sequence (seed = 42)

Starting from seed `42`, after each call the function returns the new state. The first 20 outputs (and the state after each call):

```
  1:  352222700
  2: 3553250280  (use & 0xFFFFFFFF: 3553250280)
  ...
```

(Computed by `tests/prng_reference.py`.)

## Seeding scheme

The PRNG is seeded once per shell session. The seed is derived from hostname and date to produce a deterministic rocket that stays stable throughout a single day on a single machine but changes across days and machines.

```
seed_str = hostname + "." + date
```

Where:
- `hostname` = output of `hostname -s` (short hostname, no domain)
- `date` = output of `date +%Y.%m.%d`

The string is hashed with DJB2 to produce the 32-bit seed:

```
djb2(s):
  hash = 5381
  for each byte c in s (as unsigned char):
    hash = ((hash << 5) + hash + c) & 0xFFFFFFFF
  return hash
```

If `hash` == 0, set `hash = 1` (xorshift32 cannot produce entropy from state 0).

### Why DJB2

- Extremely simple, uses only shift, add, and XOR — implementable in all four shells.
- Well-distributed for short string inputs.
- Deterministic: same string always produces the same hash.

## Range derivation

Given a PRNG output `n` (32-bit unsigned), a random integer in `[min, max]` (inclusive) is:

```
random_int(min, max) = min + (n % (max - min + 1))
```

This introduces a small modulo bias for ranges that don't evenly divide 2³², but for the ranges used in starcommand (maximum range ~0-359, ~0-100, ~0-4) the bias is negligible (< 1 part in 10⁷). Using rejection sampling would add complexity across four shells for no practical benefit.

### Float derivation

Not needed for starcommand — all rocket parameters are integer ranges.

## PRNG lifecycle per shell session

1. Session starts.
2. Seed is computed from hostname + date via DJB2.
3. PRNG state is initialized to the seed.
4. Each call to `next()` advances the state and returns the new 32-bit value.
5. The `random_int(min, max)` helper wraps `next()` with the modulo formula above.

## Consumption order

The PRNG is advanced sequentially — each `random_int` call consumes exactly one 32-bit output. The order of calls must be identical across all four shells for the same seed to produce the same rocket. The call sequence (from `_gen_rocket_palette`) is:

1. `h_base = random_int(0, 359)`
2. `scheme = random_int(0, 4)`
3. `sat = random_int(65, 90)`
4. `light = random_int(55, 72)`

If favorites are enabled and trigger (`random_int(1, 100) <= favorite_weight`), one more PRNG call is consumed for the favorite palette index. However, since favorite palettes are user-specific data, parity testing uses fixed-palette rendering (the `_render_*.{fish,zsh}` test scripts) which bypasses `_gen_rocket_palette` entirely.

## Integer width notes per shell

| Shell        | Native width     | Signed? | Mask needed? |
|-------------|------------------|---------|--------------|
| fish        | 64-bit (math)    | signed  | `% 0x100000000` |
| zsh         | 64-bit (math)    | signed  | `& 0xFFFFFFFF`  |
| bash 3.2+   | 64-bit (math)    | signed  | `& 0xFFFFFFFF`  |
| PowerShell  | [uint32] native  | unsigned | No mask needed |

All shells can produce identical xorshift32 output with the masking noted. The `& 0xFFFFFFFF` operation keeps values in the 0–2³²−1 range, which is non-negative in all signed-arithmetic shells, so right-shift always zero-fills.
