-- boljolin.lua
-- ─────────────────────────────────────────────────────
-- "bol" = lots (Turkish). lots of oscillators,
-- lots of filters, lots of modulation.
-- 4 oscillators, 2 parallel filters, open routing,
-- single rungler, macro performance page.
--
-- E1: scroll params (K1+E1: change page)
-- E2: adjust selected / macro 1 (PERFORM)
-- E3: adjust next / macro 2 (PERFORM)
-- K2: alt toggle / K2+E2: macro 3 / K2+E3: macro 4
-- K3: randomize page / K1+K3: reset
--
-- v1.0.0 @semi
-- ─────────────────────────────────────────────────────

engine.name = "Boljolin"

local Core = include("boljolin/lib/core")
local UI   = include("boljolin/lib/ui")
local clocks = {}

function init()
  Core.init_params()
  UI.init(Core)

  local function sp(name, field)
    local p = poll.set(name)
    p.callback = function(val) Core.anim[field] = val end
    p.time = 1/30; p:start(); return p
  end
  clocks.polls = {
    sp("poll_rung","poll_rung"), sp("poll_tria","poll_tria"),
    sp("poll_lfo","poll_lfo"), sp("poll_amp","poll_amp"),
  }

  clocks[1] = clock.run(function()
    while true do clock.sleep(1/15); Core.update_anim(); redraw() end
  end)

  params:bang()

  -- rebuild macro assignments after bang
  Core.rebuild_macros()
end

function enc(n, d)
  if n == 1 then
    if Core.k1_held then
      Core.page = util.clamp(Core.page + d, 1, Core.NUM_PAGES)
    else
      local list = Core.page_params[Core.page]
      if list then
        Core.sel[Core.page] = util.clamp(Core.sel[Core.page] + d, 1, #list)
      end
    end

  elseif n == 2 then
    if Core.page == 6 then
      -- PERFORM: E2 = macro 1, K2+E2 = macro 3
      local m = Core.alt_mode and 3 or 1
      Core.set_macro(m, Core.macros[m].value + d * 0.02)
    else
      local pid = Core.get_sel_param()
      if pid then params:delta(pid, d) end
    end

  elseif n == 3 then
    if Core.page == 6 then
      -- PERFORM: E3 = macro 2, K2+E3 = macro 4
      local m = Core.alt_mode and 4 or 2
      Core.set_macro(m, Core.macros[m].value + d * 0.02)
    else
      local npid = Core.get_next_param()
      if npid then params:delta(npid, d) end
    end
  end
end

function key(n, z)
  if n == 1 then Core.k1_held = (z == 1)
  elseif n == 2 and z == 1 then Core.alt_mode = not Core.alt_mode
  elseif n == 3 and z == 1 then
    if Core.k1_held then reset_all() else randomize_page() end
  end
end

function randomize_page()
  local list = Core.page_params[Core.page]
  if not list then return end
  for _, e in ipairs(list) do
    local p = params:lookup_param(e[1])
    if p then
      if p.t == 3 then params:set_raw(e[1], math.random())
      elseif p.t == 2 then params:set(e[1], math.random(1, p.count))
      elseif p.t == 1 then params:set(e[1], math.floor(p.min+math.random()*(p.max-p.min))) end
    end
  end
end

function reset_all()
  params:set("freq_a",80); params:set("freq_b",3)
  params:set("freq_c",220); params:set("freq_d",0.2)
  for _,id in ipairs({"wave_a","wave_b","wave_c","wave_d"}) do params:set(id,2) end
  params:set("chaos",0.5); params:set("loop_len",8)
  params:set("data_src",1); params:set("clock_src",2)
  for _,id in ipairs({"run_a","run_b","run_c","run_d","run_f1","run_f2"}) do params:set(id,0) end
  for _,id in ipairs({"xmod_ab","xmod_ba","xmod_cd","xmod_dc","xmod_ac","xmod_bd"}) do params:set(id,0) end
  params:set("a_to_f1",1); params:set("c_to_f2",1)
  for _,id in ipairs({"b_to_f1","c_to_f1","d_to_f1","a_to_f2","b_to_f2","d_to_f2"}) do params:set(id,0) end
  params:set("f1_freq",1200); params:set("f1_res",0.5); params:set("f1_type",1)
  params:set("f2_freq",800); params:set("f2_res",0.5); params:set("f2_type",1)
  params:set("f1_level",0.5); params:set("f2_level",0.5)
  params:set("fold_amt",0); params:set("delay_time",0); params:set("delay_fb",0)
  params:set("xmod_dly_t",0); params:set("xmod_dly_fb",0)
  params:set("amp",0.5); params:set("pan",0)
  for i=1,Core.PLOT_SIZE do Core.plot.x[i]=0;Core.plot.y[i]=0 end
  Core.plot.idx=1; Core.plot.len=0
end

function redraw() UI.draw() end

function cleanup()
  for _,id in ipairs(clocks) do if id then clock.cancel(id) end end
  if clocks.polls then for _,p in ipairs(clocks.polls) do p:stop() end end
end
