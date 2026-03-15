# boljolin

*bol* (Turkish) = plenty. plenty of oscillators, plenty of filters, plenty of modulation.

a 4-oscillator chaotic synth with open routing for [norns](https://monome.org/docs/norns/). evolved from the rungler series, inspired by Rob Hordijk's Benjolin — but expanded into a fully configurable instrument.

---

## architecture

4 oscillators (A/B/C/D) with selectable waveforms (sine/tri/saw/pulse), 2 parallel state variable filters (LP/BP/HP/twin peak), a single 8-bit rungler shift register, 6 cross-modulation paths, internal LFO, and a macro performance page.

any oscillator can feed any filter. any oscillator can be the rungler's data or clock source — or both can be turned OFF for drone mode.

```
OSC A ──┐                    ┌── FILTER 1 (LP/BP/HP/TP) ──┐
OSC B ──┼── routing matrix ──┤                             ├── MIX ── fold ── delay ── OUT
OSC C ──┤                    └── FILTER 2 (LP/BP/HP/TP) ──┘
OSC D ──┘
    ↑                               ↑
    └───── RUNGLER CV ──────────────┘
           (stepped havoc)
    ↑ cross-mod: A↔B, C↔D, A↔C, B↔D
```

## controls

**navigation:**
- **E1**: scroll parameters within current page
- **K1+E1**: change page (PATCH / RUNGLER / FILTERS / FX / SCOPE / PERFORM)
- **E2**: adjust selected parameter
- **E3**: adjust next parameter
- **K2**: toggle alt mode
- **K3**: randomize current page
- **K1+K3**: reset all to defaults

performance page (page 6):

E2: macro 1/3
E3: macro 2/4
K2: change macros 1/2 and 3/4

each macro controls up to 4 parameters with independent depth. assign via params menu under "macros (performance)."

## pages

**PATCH** — 4 oscillator slots with mini waveforms, D/C indicators, wave type, freq, run depth bars, and routing summary showing which oscs feed which filters.

**RUNGLER** — shift register visualization, CV bar with gate threshold, data/clock source display, run depths for all 6 targets (A/B/C/D/F1/F2).

**FILTERS** — dual stacked filter curves with real-time cutoff modulation, twin peak second curve, resonance visualization.

**FX** — wavefold animation, delay with rungler modulation (time + feedback), LFO waveform display, output meter.

**SCOPE** — attractor plot (rungler CV vs osc A output).

**PERFORM** — 4 macro knobs with value bars and assigned parameter labels.

## features

**per-oscillator waveform:** each of the 4 oscillators independently selects sine, triangle, sawtooth, or pulse.

**open routing:** in the params menu, set each oscillator's level into each filter (0-1). route all 4 into one filter, split them, or any combination.

**data/clock OFF:** setting data or clock source to "OFF" freezes the rungler — the last CV value is held while oscillators continue. this creates sustained drone textures where you hear pure cross-modulation between oscillators.

**delay modulation:** delay time and feedback are modulated by the rungler CV, recreating the stepped-havoc-driven delay from earlier rungler versions.

**6 run depths:** Run A/B/C/D control how much the rungler modulates each oscillator's frequency. Run F1/F2 control filter cutoff modulation. these are the core performance controls.

**6 cross-modulation paths:** A↔B, C↔D, A↔C, B↔D provide FM between oscillator pairs.

**macro performance:** 4 assignable macros, each mapping up to 4 parameters with independent depth. params menu lets you pick which parameters each macro controls. on the PERFORM page, E2/E3 and K2 give you instant access to 4 macro knobs during performance.

## requirements

- norns (shield, standard, or fates)
- grid optional (not yet implemented)

## install

```
;install https://github.com/semierendonmez-commits/boljolin
```

## history

boljolin evolved from the rungler series:
- rungler v1-v3: single benjolin emulation
- rungler v4: + LFO, mod matrix
- rungler v5: 4 oscillators, 2 filters, open routing
- boljolin: renamed, + waveform select, data/clock OFF, delay modulation, macro performance page

## license

MIT
