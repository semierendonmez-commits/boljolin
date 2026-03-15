-- lib/core.lua
-- boljolin: 4 osc + 2 filter + macros + E1 param scroll

local Core = {}

Core.page = 1
Core.NUM_PAGES = 6
Core.PAGE_NAMES = {"PATCH", "RUNGLER", "FILTERS", "FX", "SCOPE", "PERFORM"}
Core.alt_mode = false
Core.k1_held = false

-- ── macro system ────────────────────────────────────────
-- 4 macros, each can control up to 4 params with independent offsets
-- macro value is 0..1, mapped to param offset
Core.NUM_MACROS = 4
Core.macros = {}
for m = 1, 4 do
  Core.macros[m] = {
    value = 0.5,   -- current macro position
    slots = {},    -- {param_id, depth} pairs (max 4)
    -- depth: how much the macro moves the param
    -- positive = increase with macro, negative = inverse
  }
end

function Core.set_macro(m, val)
  Core.macros[m].value = util.clamp(val, 0, 1)
  for _, slot in ipairs(Core.macros[m].slots) do
    local pid = slot[1]
    local depth = slot[2]
    local p = params:lookup_param(pid)
    if p and p.t == 3 then
      -- depth * 2 so full range sweep moves param significantly
      local offset = (Core.macros[m].value - 0.5) * depth * 2
      local base = slot[3] or 0.5
      params:set_raw(pid, util.clamp(base + offset, 0, 1))
    end
  end
end

function Core.macro_assign(m, pid, depth)
  if #Core.macros[m].slots >= 4 then return end
  -- store current raw value as base
  local base = 0.5
  local p = params:lookup_param(pid)
  if p and p.t == 3 then base = params:get_raw(pid) end
  table.insert(Core.macros[m].slots, {pid, depth, base})
end

function Core.macro_clear(m)
  Core.macros[m].slots = {}
end

-- ── per-page param lists ────────────────────────────────
Core.page_params = {
  [1] = { -- PATCH
    {"freq_a","A freq"}, {"wave_a","A wave"},
    {"freq_b","B freq"}, {"wave_b","B wave"},
    {"freq_c","C freq"}, {"wave_c","C wave"},
    {"freq_d","D freq"}, {"wave_d","D wave"},
    {"run_a","Run A"}, {"run_b","Run B"}, {"run_c","Run C"}, {"run_d","Run D"},
    {"a_to_f1","A>F1"}, {"b_to_f1","B>F1"}, {"c_to_f1","C>F1"}, {"d_to_f1","D>F1"},
    {"a_to_f2","A>F2"}, {"b_to_f2","B>F2"}, {"c_to_f2","C>F2"}, {"d_to_f2","D>F2"},
    {"xmod_ab","A>B"}, {"xmod_ba","B>A"},
    {"xmod_cd","C>D"}, {"xmod_dc","D>C"},
    {"xmod_ac","A<>C"}, {"xmod_bd","B<>D"},
  },
  [2] = { -- RUNGLER
    {"chaos","chaos"}, {"loop_len","length"},
    {"data_src","data"}, {"clock_src","clock"},
    {"run_a","Run A"}, {"run_b","Run B"},
    {"run_c","Run C"}, {"run_d","Run D"},
    {"run_f1","Run F1"}, {"run_f2","Run F2"},
    {"gate_mode","gate"}, {"gate_thresh","thresh"},
  },
  [3] = { -- FILTERS
    {"f1_freq","F1 freq"}, {"f1_res","F1 res"}, {"f1_type","F1 type"}, {"f1_peak2","F1 pk2"},
    {"f2_freq","F2 freq"}, {"f2_res","F2 res"}, {"f2_type","F2 type"}, {"f2_peak2","F2 pk2"},
    {"run_f1","Run F1"}, {"run_f2","Run F2"},
    {"f1_level","F1 lvl"}, {"f2_level","F2 lvl"},
    {"dry_level","dry"}, {"rung_level","rung"},
  },
  [4] = { -- FX
    {"fold_amt","fold"}, {"delay_time","dly t"}, {"delay_fb","dly fb"},
    {"xmod_dly_t","cv>dly"}, {"xmod_dly_fb","cv>fb"},
    {"lfo_rate","LFO Hz"}, {"lfo_shape","LFO wav"},
    {"lfo_to_a","L>A"}, {"lfo_to_b","L>B"},
    {"lfo_to_c","L>C"}, {"lfo_to_d","L>D"},
    {"lfo_to_f1","L>F1"}, {"lfo_to_f2","L>F2"},
    {"amp","vol"}, {"pan","pan"},
    {"stereo_mode","stereo"}, {"stereo_width","width"},
  },
  [5] = { -- SCOPE
    {"chaos","chaos"}, {"loop_len","length"}, {"amp","vol"},
  },
  [6] = { -- PERFORM (macros controlled directly, not via param scroll)
    {"amp","vol"}, {"chaos","chaos"},
  },
}

Core.sel = {}
for i = 1, Core.NUM_PAGES do Core.sel[i] = 1 end

function Core.get_sel_param()
  local list = Core.page_params[Core.page]
  local idx = Core.sel[Core.page]
  return list and list[idx] and list[idx][1] or nil
end
function Core.get_sel_name()
  local list = Core.page_params[Core.page]
  local idx = Core.sel[Core.page]
  return list and list[idx] and list[idx][2] or ""
end
function Core.get_next_param()
  local list = Core.page_params[Core.page]
  local idx = Core.sel[Core.page] + 1
  return list and list[idx] and list[idx][1] or nil
end
function Core.get_next_name()
  local list = Core.page_params[Core.page]
  local idx = Core.sel[Core.page] + 1
  return list and list[idx] and list[idx][2] or ""
end

-- ── anim ────────────────────────────────────────────────
Core.anim = {
  t = 0, poll_rung = 0, poll_tria = 0,
  poll_lfo = 0, poll_amp = 0, gate_open = false,
}

Core.PLOT_SIZE = 180
Core.plot = {x={}, y={}, idx=1, len=0}
for i=1,Core.PLOT_SIZE do Core.plot.x[i]=0; Core.plot.y[i]=0 end

function Core.push_plot(x, y)
  Core.plot.x[Core.plot.idx]=x; Core.plot.y[Core.plot.idx]=y
  Core.plot.idx = (Core.plot.idx%Core.PLOT_SIZE)+1
  if Core.plot.len<Core.PLOT_SIZE then Core.plot.len=Core.plot.len+1 end
end

function Core.update_anim()
  Core.anim.t = Core.anim.t+1
  Core.anim.gate_open = Core.anim.poll_rung > (params:get("gate_thresh") or 0.3)
  Core.push_plot(Core.anim.poll_rung, Core.anim.poll_tria)
end

Core.OSC_NAMES = {"A","B","C","D","OFF"}
Core.WAVE_NAMES = {"sin","tri","saw","pul"}
Core.FILT_TYPES = {"LP","BP","HP","TP"}

-- ── params (same as v5 but with macro assignments) ──────
function Core.init_params()
  params:add_separator("bj_h", "b o l j o l i n")

  -- oscs
  params:add_separator("bj_osc","oscillators")
  local osc_def={80,3,220,0.2}
  local ids={"a","b","c","d"}
  for i,id in ipairs(ids) do
    params:add_control("freq_"..id,"osc "..id.." freq",controlspec.new(0.1,12000,'exp',0,osc_def[i],'Hz'))
    params:set_action("freq_"..id,function(v) engine["freq_"..id](v) end)
    params:add_option("wave_"..id,"osc "..id.." wave",{"sine","tri","saw","pulse"},2)
    params:set_action("wave_"..id,function(v) engine["wave_"..id](v-1) end)
  end

  -- rungler
  params:add_separator("bj_rung","rungler")
  params:add_option("data_src","data source",{"osc A","osc B","osc C","osc D","OFF"},1)
  params:set_action("data_src",function(v) engine.data_src(v-1) end)
  params:add_option("clock_src","clock source",{"osc A","osc B","osc C","osc D","OFF"},2)
  params:set_action("clock_src",function(v) engine.clock_src(v-1) end)
  params:add_control("chaos","chaos",controlspec.new(0,1,'lin',0,0.5,''))
  params:set_action("chaos",function(v) engine.chaos(v) end)
  params:add_number("loop_len","register length",3,8,8)
  params:set_action("loop_len",function(v) engine.loop_len(v) end)

  -- run depths
  params:add_separator("bj_run","run depths")
  local rd={0.3,0.2,0.1,0,0.4,0.2}
  local ri={"run_a","run_b","run_c","run_d","run_f1","run_f2"}
  local rn={"Run A","Run B","Run C","Run D","Run F1","Run F2"}
  for i,id in ipairs(ri) do
    params:add_control(id,rn[i],controlspec.new(0,2,'lin',0,rd[i],''))
    params:set_action(id,function(v) engine[id](v) end)
  end

  -- xmod
  params:add_separator("bj_xmod","cross-modulation")
  for _,p in ipairs({{"xmod_ab","A>B FM"},{"xmod_ba","B>A FM"},{"xmod_cd","C>D FM"},
    {"xmod_dc","D>C FM"},{"xmod_ac","A<>C FM"},{"xmod_bd","B<>D FM"}}) do
    params:add_control(p[1],p[2],controlspec.new(0,1,'lin',0,0,''))
    params:set_action(p[1],function(v) engine[p[1]](v) end)
  end

  -- routing
  params:add_separator("bj_route","routing")
  local rd2={a_to_f1=1,b_to_f1=0,c_to_f1=0,d_to_f1=0,
    a_to_f2=0,b_to_f2=0,c_to_f2=1,d_to_f2=0}
  for _,fi in ipairs({"f1","f2"}) do
    for _,oid in ipairs(ids) do
      local pid=oid.."_to_"..fi
      params:add_control(pid,"osc "..oid..">"..fi:sub(2),controlspec.new(0,1,'lin',0,rd2[pid] or 0,''))
      params:set_action(pid,function(v) engine[pid](v) end)
    end
  end

  -- filters
  for fi=1,2 do
    params:add_separator("bj_f"..fi,"filter "..fi)
    local fd=fi==1 and 1200 or 800
    params:add_control("f"..fi.."_freq","cutoff",controlspec.new(20,20000,'exp',0,fd,'Hz'))
    params:set_action("f"..fi.."_freq",function(v) engine["f"..fi.."_freq"](v) end)
    params:add_control("f"..fi.."_res","res",controlspec.new(0.05,2,'lin',0,0.5,''))
    params:set_action("f"..fi.."_res",function(v) engine["f"..fi.."_res"](v) end)
    params:add_option("f"..fi.."_type","type",{"LP","BP","HP","twin peak"},1)
    params:set_action("f"..fi.."_type",function(v) engine["f"..fi.."_type"](v-1) end)
    params:add_control("f"..fi.."_peak2","peak2",controlspec.new(0.5,4,'exp',0,1.5,'x'))
    params:set_action("f"..fi.."_peak2",function(v) engine["f"..fi.."_peak2"](v) end)
  end

  -- mix
  params:add_separator("bj_mix","output")
  params:add_control("f1_level","F1 level",controlspec.new(0,1,'lin',0,0.5,''))
  params:set_action("f1_level",function(v) engine.f1_level(v) end)
  params:add_control("f2_level","F2 level",controlspec.new(0,1,'lin',0,0.5,''))
  params:set_action("f2_level",function(v) engine.f2_level(v) end)
  params:add_control("dry_level","dry osc",controlspec.new(0,1,'lin',0,0,''))
  params:set_action("dry_level",function(v) engine.dry_level(v) end)
  params:add_control("rung_level","rung direct",controlspec.new(0,1,'lin',0,0,''))
  params:set_action("rung_level",function(v) engine.rung_level(v) end)

  -- gate
  params:add_separator("bj_gate","gate")
  params:add_option("gate_mode","mode",{"continuous","gated"},1)
  params:set_action("gate_mode",function(v) engine.gate_mode(v-1) end)
  params:add_control("gate_thresh","threshold",controlspec.new(-1,1,'lin',0,0.3,''))
  params:set_action("gate_thresh",function(v) engine.gate_thresh(v) end)

  -- fx
  params:add_separator("bj_fx","effects")
  params:add_control("fold_amt","wavefold",controlspec.new(0,1,'lin',0,0,''))
  params:set_action("fold_amt",function(v) engine.fold_amt(v) end)
  params:add_control("delay_time","delay",controlspec.new(0,2,'lin',0,0,'s'))
  params:set_action("delay_time",function(v) engine.delay_time(v) end)
  params:add_control("delay_fb","dly fb",controlspec.new(0,0.95,'lin',0,0,''))
  params:set_action("delay_fb",function(v) engine.delay_fb(v) end)
  params:add_control("xmod_dly_t","cv>dly t",controlspec.new(0,2,'lin',0,0,''))
  params:set_action("xmod_dly_t",function(v) engine.xmod_dly_t(v) end)
  params:add_control("xmod_dly_fb","cv>dly fb",controlspec.new(0,2,'lin',0,0,''))
  params:set_action("xmod_dly_fb",function(v) engine.xmod_dly_fb(v) end)

  -- LFO
  params:add_separator("bj_lfo","LFO")
  params:add_control("lfo_rate","rate",controlspec.new(0.01,30,'exp',0,1,'Hz'))
  params:set_action("lfo_rate",function(v) engine.lfo_rate(v) end)
  params:add_option("lfo_shape","shape",{"sin","tri","saw","s&h"},1)
  params:set_action("lfo_shape",function(v) engine.lfo_shape(v-1) end)
  for _,p in ipairs({{"lfo_to_a","lfo>A"},{"lfo_to_b","lfo>B"},{"lfo_to_c","lfo>C"},
    {"lfo_to_d","lfo>D"},{"lfo_to_f1","lfo>F1"},{"lfo_to_f2","lfo>F2"}}) do
    params:add_control(p[1],p[2],controlspec.new(0,1,'lin',0,0,''))
    params:set_action(p[1],function(v) engine[p[1]](v) end)
  end

  -- master
  params:add_separator("bj_master","master")
  params:add_control("amp","volume",controlspec.new(0,1,'lin',0,0.5,''))
  params:set_action("amp",function(v) engine.amp(v) end)
  params:add_control("pan","pan",controlspec.new(-1,1,'lin',0,0,''))
  params:set_action("pan",function(v) engine.pan(v) end)
  params:add_option("stereo_mode","stereo",{"static","rungler","random"},1)
  params:set_action("stereo_mode",function(v) engine.stereo_mode(v-1) end)
  params:add_control("stereo_width","width",controlspec.new(0,1,'lin',0,0,''))
  params:set_action("stereo_width",function(v) engine.stereo_width(v) end)

  -- ── macro assignments (params menu) ───────────────────
  params:add_separator("bj_macro","macros (performance)")
  local all_params = {}
  -- collect all controlspec param ids
  for pg = 1, 5 do
    for _, e in ipairs(Core.page_params[pg]) do
      local p = params:lookup_param(e[1])
      if p and p.t == 3 then
        table.insert(all_params, e[1])
      end
    end
  end
  -- deduplicate
  local seen = {}
  local unique = {}
  for _, id in ipairs(all_params) do
    if not seen[id] then seen[id] = true; table.insert(unique, id) end
  end

  for m = 1, 4 do
    for s = 1, 4 do
      local opts = {"---"}
      for _, id in ipairs(unique) do table.insert(opts, id) end
      params:add_option("macro_"..m.."_slot_"..s,
        "M"..m.." slot "..s, opts, 1)
      params:add_control("macro_"..m.."_depth_"..s,
        "M"..m.." depth "..s, controlspec.new(-1, 1, 'lin', 0, 0.5, ''))
    end
  end
end

-- ── rebuild macros from params ──────────────────────────
function Core.rebuild_macros()
  for m = 1, 4 do
    Core.macros[m].slots = {}
    for s = 1, 4 do
      local opt = params:get("macro_"..m.."_slot_"..s)
      if opt > 1 then
        -- get the param id from the option list
        local opts = params:lookup_param("macro_"..m.."_slot_"..s).options
        local pid = opts[opt]
        if pid and pid ~= "---" then
          local depth = params:get("macro_"..m.."_depth_"..s)
          local base = params:get_raw(pid) or 0.5
          table.insert(Core.macros[m].slots, {pid, depth, base})
        end
      end
    end
  end
end

return Core
