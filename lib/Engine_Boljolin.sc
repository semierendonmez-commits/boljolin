// lib/Engine_Boljolin.sc
// v5.1: 4 osc + 2 parallel filters + open routing
// + per-osc waveform, data/clock OFF, delay modulation

Engine_Boljolin : CroneEngine {
  var <synth;
  var rungBus, triABus, lfoBus, ampBus;

  *new { |context, doneCallback| ^super.new(context, doneCallback) }

  alloc {
    rungBus = Bus.control(context.server, 1);
    triABus = Bus.control(context.server, 1);
    lfoBus  = Bus.control(context.server, 1);
    ampBus  = Bus.control(context.server, 1);

    SynthDef(\boljolin_voice, {
      arg freq_a=80, freq_b=3, freq_c=220, freq_d=0.2,
          wave_a=1, wave_b=1, wave_c=1, wave_d=1, // 0=sin,1=tri,2=saw,3=pulse
          run_a=0, run_b=0, run_c=0, run_d=0,
          run_f1=0, run_f2=0,
          chaos=0.5, loop_len=8,
          data_src=0, clock_src=1, // 0-3=osc A-D, 4=OFF
          xmod_ab=0, xmod_ba=0, xmod_cd=0, xmod_dc=0,
          xmod_ac=0, xmod_bd=0,
          gate_mode=0, gate_thresh=0.3,
          gate_attack=0.005, gate_release=0.3,
          f1_freq=1200, f1_res=0.5, f1_type=0, f1_peak2=1.5,
          f2_freq=800, f2_res=0.5, f2_type=0, f2_peak2=1.5,
          a_to_f1=1, b_to_f1=0, c_to_f1=0, d_to_f1=0,
          a_to_f2=0, b_to_f2=0, c_to_f2=1, d_to_f2=0,
          f1_level=0.5, f2_level=0.5,
          dry_level=0, rung_level=0,
          fold_amt=0,
          delay_time=0, delay_fb=0,
          xmod_dly_t=0, xmod_dly_fb=0, // rungler mod on delay
          lfo_rate=1, lfo_shape=0,
          lfo_to_a=0, lfo_to_b=0, lfo_to_c=0, lfo_to_d=0,
          lfo_to_f1=0, lfo_to_f2=0,
          amp=0.5, pan=0,
          stereo_mode=0, stereo_width=0,
          rung_bus=0, tria_bus=0, lfo_bus=0, amp_bus=0;

      var osc_a, osc_b, osc_c, osc_d;
      var pulse_a, pulse_b, pulse_c, pulse_d;
      var fa, fb, fc, fd;
      var sh0, sh1, sh2, sh3, sh4, sh5, sh6, sh7;
      var data_bit, xor_bit, rungler_cv, rung, trig;
      var fb_sig, prev_rung, prev_last;
      var gate_sig, gate_env;
      var lfo, lfo_raw;
      var f1_in, f1_out, f1_freq_mod;
      var f1_lp, f1_bp, f1_hp, f1_tp;
      var f2_in, f2_out, f2_freq_mod;
      var f2_lp, f2_bp, f2_hp, f2_tp;
      var mix, folded, mono;
      var pan_sig, panned, del_l, del_r, out_sig;
      var data_sel, clock_sel;
      var dly_t_mod, dly_fb_mod;

      // ── LFO ──────────────────────────────────────────
      lfo = Select.ar(lfo_shape.round.clip(0,3), [
        SinOsc.ar(lfo_rate), LFTri.ar(lfo_rate),
        LFSaw.ar(lfo_rate), Latch.ar(WhiteNoise.ar, Impulse.ar(lfo_rate))
      ]);
      Out.kr(lfo_bus, A2K.kr(lfo));

      // ── feedback ─────────────────────────────────────
      fb_sig    = LocalIn.ar(2, 0);
      prev_rung = fb_sig[0];
      prev_last = fb_sig[1];

      // ── 4 oscillators ────────────────────────────────
      // helper: freq mod from rungler + LFO + xmod
      fa = (freq_a + (prev_rung*run_a*freq_a) + (lfo*lfo_to_a*freq_a)
        + (LFTri.ar(freq_b)*xmod_ba*freq_a*0.5)
        + (LFTri.ar(freq_c)*xmod_ac*freq_a*0.3)).clip(0.1, 20000);
      fb = (freq_b + (prev_rung*run_b*freq_b) + (lfo*lfo_to_b*freq_b)
        + (LFTri.ar(freq_a)*xmod_ab*freq_b*0.5)
        + (LFTri.ar(freq_d)*xmod_bd*freq_b*0.3)).clip(0.1, 20000);
      fc = (freq_c + (prev_rung*run_c*freq_c) + (lfo*lfo_to_c*freq_c)
        + (LFTri.ar(freq_d)*xmod_dc*freq_c*0.5)
        + (LFTri.ar(freq_a)*xmod_ac*freq_c*0.3)).clip(0.1, 20000);
      fd = (freq_d + (prev_rung*run_d*freq_d) + (lfo*lfo_to_d*freq_d)
        + (LFTri.ar(freq_c)*xmod_cd*freq_d*0.5)
        + (LFTri.ar(freq_b)*xmod_bd*freq_d*0.3)).clip(0.1, 20000);

      // waveform select per osc: 0=sin,1=tri,2=saw,3=pulse
      osc_a = Select.ar(wave_a.round.clip(0,3), [
        SinOsc.ar(fa), LFTri.ar(fa), LFSaw.ar(fa), LFPulse.ar(fa,0,0.5)*2-1]);
      osc_b = Select.ar(wave_b.round.clip(0,3), [
        SinOsc.ar(fb), LFTri.ar(fb), LFSaw.ar(fb), LFPulse.ar(fb,0,0.5)*2-1]);
      osc_c = Select.ar(wave_c.round.clip(0,3), [
        SinOsc.ar(fc), LFTri.ar(fc), LFSaw.ar(fc), LFPulse.ar(fc,0,0.5)*2-1]);
      osc_d = Select.ar(wave_d.round.clip(0,3), [
        SinOsc.ar(fd), LFTri.ar(fd), LFSaw.ar(fd), LFPulse.ar(fd,0,0.5)*2-1]);

      // pulse waves always needed for rungler
      pulse_a = LFPulse.ar(fa, 0, 0.5);
      pulse_b = LFPulse.ar(fb, 0, 0.5);
      pulse_c = LFPulse.ar(fc, 0, 0.5);
      pulse_d = LFPulse.ar(fd, 0, 0.5);

      // ── rungler (data/clock: 0-3=osc, 4=OFF) ────────
      data_sel = Select.ar(data_src.round.clip(0,4),
        [pulse_a, pulse_b, pulse_c, pulse_d, DC.ar(0)]);
      clock_sel = Select.ar(clock_src.round.clip(0,4),
        [pulse_a, pulse_b, pulse_c, pulse_d, DC.ar(0)]);

      trig     = Trig1.ar(clock_sel - 0.5, SampleDur.ir);
      data_bit = data_sel;
      xor_bit  = (data_bit + prev_last) - (2 * data_bit * prev_last);
      sh0 = ((1-chaos)*data_bit) + (chaos*xor_bit);
      sh0 = (sh0 > 0.5);

      sh1 = Latch.ar(sh0,            trig);
      sh2 = Latch.ar(Delay1.ar(sh1), trig);
      sh3 = Latch.ar(Delay1.ar(sh2), trig);
      sh4 = Latch.ar(Delay1.ar(sh3), trig);
      sh5 = Latch.ar(Delay1.ar(sh4), trig);
      sh6 = Latch.ar(Delay1.ar(sh5), trig);
      sh7 = Latch.ar(Delay1.ar(sh6), trig);

      rungler_cv = Select.ar(loop_len.clip(3,8).round - 3, [
        (sh1*0.25)+(sh2*0.5)+(sh3*1.0),
        (sh2*0.25)+(sh3*0.5)+(sh4*1.0),
        (sh3*0.25)+(sh4*0.5)+(sh5*1.0),
        (sh4*0.25)+(sh5*0.5)+(sh6*1.0),
        (sh5*0.25)+(sh6*0.5)+(sh7*1.0),
        (sh6*0.25)+(sh7*0.5)+(sh1*1.0),
      ]);
      rung = (rungler_cv / 1.75) * 2 - 1;
      LocalOut.ar([rung, sh7]);
      Out.kr(rung_bus, A2K.kr(rung));
      Out.kr(tria_bus, A2K.kr(osc_a));

      // ── gate ─────────────────────────────────────────
      gate_sig = (rung > gate_thresh);
      gate_env = Select.ar(gate_mode.clip(0,1).round, [
        DC.ar(1.0),
        EnvGen.ar(Env.asr(gate_attack.max(0.001),1,gate_release.max(0.01),-4), gate_sig)
      ]);

      // ── filter 1 ─────────────────────────────────────
      f1_in = (osc_a*a_to_f1)+(osc_b*b_to_f1)+(osc_c*c_to_f1)+(osc_d*d_to_f1);
      f1_freq_mod = (f1_freq + (rung*run_f1*f1_freq) + (lfo*lfo_to_f1*f1_freq)).clip(20,20000);
      f1_lp = RLPF.ar(f1_in, f1_freq_mod, f1_res.clip(0.05,2));
      f1_bp = BPF.ar(f1_in, f1_freq_mod, f1_res.clip(0.05,2));
      f1_hp = HPF.ar(f1_in, f1_freq_mod);
      f1_tp = (BPF.ar(f1_in, f1_freq_mod, f1_res.clip(0.05,2))
             + BPF.ar(f1_in, (f1_freq_mod*f1_peak2).clip(20,20000), f1_res.clip(0.05,2)))*0.7;
      f1_out = Select.ar(f1_type.round.clip(0,3), [f1_lp, f1_bp, f1_hp, f1_tp]);

      // ── filter 2 ─────────────────────────────────────
      f2_in = (osc_a*a_to_f2)+(osc_b*b_to_f2)+(osc_c*c_to_f2)+(osc_d*d_to_f2);
      f2_freq_mod = (f2_freq + (rung*run_f2*f2_freq) + (lfo*lfo_to_f2*f2_freq)).clip(20,20000);
      f2_lp = RLPF.ar(f2_in, f2_freq_mod, f2_res.clip(0.05,2));
      f2_bp = BPF.ar(f2_in, f2_freq_mod, f2_res.clip(0.05,2));
      f2_hp = HPF.ar(f2_in, f2_freq_mod);
      f2_tp = (BPF.ar(f2_in, f2_freq_mod, f2_res.clip(0.05,2))
             + BPF.ar(f2_in, (f2_freq_mod*f2_peak2).clip(20,20000), f2_res.clip(0.05,2)))*0.7;
      f2_out = Select.ar(f2_type.round.clip(0,3), [f2_lp, f2_bp, f2_hp, f2_tp]);

      // ── mix ──────────────────────────────────────────
      mix = (f1_out*f1_level) + (f2_out*f2_level)
          + ((osc_a+osc_c)*dry_level*0.25)
          + (rung*rung_level*0.5);

      folded = Select.ar((fold_amt > 0.01), [
        mix, (mix*(1+(fold_amt*10))).fold(-1,1)]);
      mono = folded * gate_env;

      // ── stereo ───────────────────────────────────────
      pan_sig = Select.ar(stereo_mode.round.clip(0,2), [
        DC.ar(pan), (rung*stereo_width).clip(-1,1),
        (LFNoise1.ar(2.5)*stereo_width).clip(-1,1)]);
      panned = Pan2.ar(mono, pan_sig);

      // ── delay (rungler-modulated) ────────────────────
      dly_t_mod = Lag.kr(
        (delay_time + (A2K.kr(rung) * xmod_dly_t * delay_time)).clip(0.001, 2.0),
        0.05);
      dly_fb_mod = (delay_fb + (A2K.kr(rung) * xmod_dly_fb * 0.5)).clip(0, 0.95);

      del_l = CombC.ar(panned[0], 2.0,
        (dly_t_mod * (1 + stereo_width.abs*0.18)).clip(0.001,2),
        dly_fb_mod*6) * 0.35;
      del_r = CombC.ar(panned[1], 2.0,
        (dly_t_mod * (1 - stereo_width.abs*0.18)).clip(0.001,2),
        dly_fb_mod*6) * 0.35;

      out_sig = [panned[0]+del_l, panned[1]+del_r];
      out_sig = LeakDC.ar(out_sig);
      out_sig = Limiter.ar(out_sig * amp, 0.95, 0.01);
      Out.kr(amp_bus, Amplitude.kr(Mix.ar(out_sig), 0.01, 0.1));
      Out.ar(0, out_sig);
    }).add;

    context.server.sync;
    synth = Synth.new(\boljolin_voice, [
      \rung_bus, rungBus.index, \tria_bus, triABus.index,
      \lfo_bus, lfoBus.index, \amp_bus, ampBus.index,
    ], target: context.xg);

    // ── float commands ─────────────────────────────────
    [\freq_a,\freq_b,\freq_c,\freq_d,
     \run_a,\run_b,\run_c,\run_d,\run_f1,\run_f2,
     \chaos,
     \xmod_ab,\xmod_ba,\xmod_cd,\xmod_dc,\xmod_ac,\xmod_bd,
     \gate_thresh,\gate_attack,\gate_release,
     \f1_freq,\f1_res,\f1_peak2,
     \f2_freq,\f2_res,\f2_peak2,
     \a_to_f1,\b_to_f1,\c_to_f1,\d_to_f1,
     \a_to_f2,\b_to_f2,\c_to_f2,\d_to_f2,
     \f1_level,\f2_level,\dry_level,\rung_level,
     \fold_amt,\delay_time,\delay_fb,
     \xmod_dly_t,\xmod_dly_fb,
     \lfo_rate,
     \lfo_to_a,\lfo_to_b,\lfo_to_c,\lfo_to_d,
     \lfo_to_f1,\lfo_to_f2,
     \amp,\pan,\stereo_width
    ].do({ |key|
      this.addCommand(key, "f", { |msg| synth.set(key, msg[1]) });
    });

    [\loop_len,\data_src,\clock_src,
     \gate_mode,\f1_type,\f2_type,
     \stereo_mode,\lfo_shape,
     \wave_a,\wave_b,\wave_c,\wave_d
    ].do({ |key|
      this.addCommand(key, "i", { |msg| synth.set(key, msg[1]) });
    });

    this.addPoll(\poll_rung, { rungBus.getSynchronous });
    this.addPoll(\poll_tria, { triABus.getSynchronous });
    this.addPoll(\poll_lfo,  { lfoBus.getSynchronous });
    this.addPoll(\poll_amp,  { ampBus.getSynchronous });
  }

  free {
    if(synth.notNil){synth.free};
    if(rungBus.notNil){rungBus.free};
    if(triABus.notNil){triABus.free};
    if(lfoBus.notNil){lfoBus.free};
    if(ampBus.notNil){ampBus.free};
  }
}
