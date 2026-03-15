-- lib/ui.lua
-- boljolin: 6 pages with E1 param scroll + PERFORM macros

local UI = {}
local C
local W, H = 128, 64

function UI.init(c) C = c end

function UI.draw()
  screen.clear()
  UI.draw_header()
  local fn = {UI.draw_patch, UI.draw_rung, UI.draw_filters,
              UI.draw_fx, UI.draw_scope, UI.draw_perform}
  fn[C.page]()
  if C.page ~= 6 then UI.draw_footer() end
  screen.update()
end

function UI.draw_header()
  for i=1,C.NUM_PAGES do
    screen.level(i==C.page and 15 or 3)
    screen.rect(2+(i-1)*5,1,3,3)
    if i==C.page then screen.fill() else screen.stroke() end
  end
  screen.level(10); screen.font_size(8)
  screen.move(34,7); screen.text(C.PAGE_NAMES[C.page])
  local aw=math.floor(C.anim.poll_amp*18)
  if aw>0 then
    screen.level(math.floor(3+C.anim.poll_amp*10))
    screen.rect(W-36,2,aw,2); screen.fill()
  end
  screen.level(C.anim.gate_open and 15 or 2)
  screen.rect(W-14,2,3,3)
  if C.anim.gate_open then screen.fill() else screen.stroke() end
  screen.level(1); screen.move(0,9); screen.line(W,9); screen.stroke()
end

function UI.draw_footer()
  screen.level(1); screen.move(0,52); screen.line(W,52); screen.stroke()
  screen.font_size(8)
  local pid = C.get_sel_param()
  if pid then
    screen.level(10); screen.move(2,59); screen.text("E2:"..C.get_sel_name())
    screen.level(15); screen.move(2,64); screen.text(params:string(pid))
  end
  local npid = C.get_next_param()
  if npid then
    screen.level(5); screen.move(68,59); screen.text("E3:"..C.get_next_name())
    screen.level(10); screen.move(68,64); screen.text(params:string(npid))
  end
end

-- ── PATCH ───────────────────────────────────────────────
function UI.draw_patch()
  local t=C.anim.t; local ids={"a","b","c","d"}
  local ow,oh=28,22; local gap=3; local oy=11
  for i,id in ipairs(ids) do
    local ox=(i-1)*(ow+gap)+2
    local freq=params:get("freq_"..id)
    local wave=params:get("wave_"..id)
    local run=params:get("run_"..id)
    local is_d=(params:get("data_src")==i)
    local is_c=(params:get("clock_src")==i)
    screen.level(run>0.01 and 5 or 3)
    screen.rect(ox,oy,ow,oh); screen.stroke()
    if is_d then screen.level(15); screen.move(ox+1,oy+6); screen.text("D") end
    if is_c then screen.level(10); screen.move(ox+ow-7,oy+6); screen.text("C") end
    screen.level(4); screen.move(ox+10,oy+6); screen.text(C.WAVE_NAMES[wave])
    screen.level(run>0.01 and 10 or 6)
    for j=0,ow-4 do
      local x=ox+2+j
      local ph=((t*0.015+j*0.12)*math.max(freq/80,0.01))%1
      local v=0
      if wave==1 then v=math.sin(ph*6.28)
      elseif wave==2 then v=ph<0.5 and (ph*4-1) or (3-ph*4)
      elseif wave==3 then v=ph*2-1 else v=ph<0.5 and 1 or -1 end
      v=v*(1+run*C.anim.poll_rung*0.3)
      local y=oy+oh*0.55+v*(oh*0.3)
      if j>0 then screen.line(x,y) else screen.move(x,y) end
    end
    screen.stroke()
    screen.level(5); screen.font_size(8); screen.move(ox+1,oy+oh+6)
    if freq>=1000 then screen.text(string.format("%.0fk",freq/1000))
    elseif freq>=1 then screen.text(string.format("%.0f",freq))
    else screen.text(string.format("%.2f",freq)) end
    if run>0.01 then
      screen.level(7); screen.rect(ox,oy+oh+8,math.floor(run*ow*0.5),1); screen.fill()
    end
  end
  screen.level(4); screen.font_size(8)
  screen.move(2,48); screen.text("F1:")
  screen.move(66,48); screen.text("F2:")
  for i,id in ipairs(ids) do
    if params:get(id.."_to_f1") > 0.05 then
      screen.level(math.floor(3+params:get(id.."_to_f1")*8))
      screen.move(14+(i-1)*10,48); screen.text(string.upper(id))
    end
    if params:get(id.."_to_f2") > 0.05 then
      screen.level(math.floor(3+params:get(id.."_to_f2")*8))
      screen.move(78+(i-1)*10,48); screen.text(string.upper(id))
    end
  end
end

-- ── RUNGLER ─────────────────────────────────────────────
function UI.draw_rung()
  local ll=params:get("loop_len"); local chaos=params:get("chaos")
  local bw,gap=12,2; local sx=math.floor((W-8*(bw+gap))/2); local ry=11
  for i=1,8 do
    local x=sx+(i-1)*(bw+gap)
    screen.level(i<=ll and 6 or 2); screen.rect(x,ry,bw,8); screen.stroke()
  end
  screen.level(math.floor(4+chaos*8))
  local lx=sx+7*(bw+gap)+bw
  screen.move(lx,ry+8); screen.line(lx,ry+12)
  screen.line(sx,ry+12); screen.line(sx,ry+8); screen.stroke()
  screen.level(chaos>0.5 and 12 or 5); screen.font_size(8)
  screen.move(W/2-6,ry+18); screen.text(chaos>0.5 and "XOR" or "LOOP")
  local cv_w=math.max(0,math.min(W-8,math.floor(util.linlin(-1,1,0,W-8,C.anim.poll_rung))))
  screen.level(C.anim.gate_open and 12 or 5)
  screen.rect(4,34,cv_w,3); screen.fill()
  local tx=math.floor(util.linlin(-1,1,4,W-4,params:get("gate_thresh")))
  screen.level(8); screen.move(tx,33); screen.line(tx,38); screen.stroke()
  screen.level(5); screen.font_size(8)
  screen.move(4,46); screen.text("D:"..C.OSC_NAMES[params:get("data_src")])
  screen.move(30,46); screen.text("C:"..C.OSC_NAMES[params:get("clock_src")])
  screen.move(4,50)
  screen.text("A:"..string.format("%.0f",params:get("run_a")*100))
  screen.move(26,50); screen.text("B:"..string.format("%.0f",params:get("run_b")*100))
  screen.move(48,50); screen.text("C:"..string.format("%.0f",params:get("run_c")*100))
  screen.move(70,50); screen.text("D:"..string.format("%.0f",params:get("run_d")*100))
end

-- ── FILTERS ─────────────────────────────────────────────
function UI.draw_filters()
  for fi=1,2 do
    local freq=params:get("f"..fi.."_freq")
    local res=params:get("f"..fi.."_res")
    local ft=params:get("f"..fi.."_type")
    local p2=params:get("f"..fi.."_peak2")
    local run=params:get("run_f"..fi)
    local tn={"LP","BP","HP","TP"}
    local by=fi==1 and 30 or 50; local ch=14; local oy=fi==1 and 10 or 36
    screen.level(8); screen.font_size(8)
    screen.move(2,oy+6); screen.text("F"..fi.." "..tn[ft])
    local mf=math.max(20,math.min(20000,freq*(1+C.anim.poll_rung*run*0.5)))
    screen.level(5); screen.move(28,oy+6)
    screen.text(mf>=1000 and string.format("%.1fk",mf/1000) or string.format("%.0f",mf))
    screen.move(60,oy+6); screen.text("R:"..string.format("%.0f%%",run*100))
    screen.level(2); screen.move(4,by); screen.line(W-4,by); screen.stroke()
    screen.level(10)
    for i=0,W-8 do
      local x=i+4; local fl=util.linlin(0,W-8,math.log(20),math.log(20000),i)
      local d=math.abs(fl-math.log(mf))
      local r=(ft==2 or ft==4) and math.exp(-(d^2)*4) or (1/(1+(d*2.5)^2))
      r=math.min(r+res*1.5*math.exp(-(d^2)*8),1.5)
      if i>0 then screen.line(x,by-r*ch) else screen.move(x,by-r*ch) end
    end
    screen.stroke()
    if ft==4 then
      local f2=math.max(20,math.min(20000,mf*p2))
      screen.level(6)
      for i=0,W-8 do
        local x=i+4; local fl=util.linlin(0,W-8,math.log(20),math.log(20000),i)
        local d2=math.abs(fl-math.log(f2))
        local r2=math.exp(-(d2^2)*4)
        r2=math.min(r2+res*1.5*math.exp(-(d2^2)*8),1.5)
        if i>0 then screen.line(x,by-r2*ch) else screen.move(x,by-r2*ch) end
      end
      screen.stroke()
    end
    local fx=math.floor(util.linlin(math.log(20),math.log(20000),4,W-4,math.log(mf)))
    screen.level(15); screen.move(fx,by-ch); screen.line(fx,by+2); screen.stroke()
  end
end

-- ── FX ──────────────────────────────────────────────────
function UI.draw_fx()
  local fold=params:get("fold_amt"); local t=C.anim.t
  screen.level(4); screen.font_size(8); screen.move(4,16); screen.text("fold:"..string.format("%.2f",fold))
  for i=0,38 do
    local x=4+i; local ph=(i/38)*6.28+t*0.02
    local v=math.sin(ph)*(1+fold*8)
    while v>1 or v<-1 do if v>1 then v=2-v end; if v<-1 then v=-2-v end end
    screen.level(math.min(math.floor(4+fold*10),15))
    if i>0 then screen.line(x,26-v*7) else screen.move(x,26-v*7) end
  end
  screen.stroke()
  screen.level(5); screen.font_size(8)
  screen.move(52,16); screen.text("dly:"..string.format("%.2f",params:get("delay_time")))
  screen.move(52,24); screen.text("fb:"..string.format("%.0f%%",params:get("delay_fb")*100))
  local xdt=params:get("xmod_dly_t"); local xdf=params:get("xmod_dly_fb")
  if xdt>0.01 or xdf>0.01 then
    screen.level(4); screen.move(52,32)
    screen.text("cv:"..string.format("%.0f%%",xdt*50).."/"..string.format("%.0f%%",xdf*50))
  end
  screen.level(5); screen.move(4,38)
  screen.text("LFO "..C.WAVE_NAMES[params:get("lfo_shape")].." "..string.format("%.2fHz",params:get("lfo_rate")))
  screen.level(8)
  for i=0,34 do
    local x=4+i; local ph=(i/34)*6.28; local s=params:get("lfo_shape")
    local v=math.sin(ph)
    if s==2 then local tp=(ph/6.28)%1; v=tp<0.5 and (tp*4-1) or (3-tp*4)
    elseif s==3 then v=((ph/6.28)%1)*2-1
    elseif s==4 then v=math.sin(ph+t*0.1*i) end
    if i>0 then screen.line(x,46-v*5) else screen.move(x,46-v*5) end
  end
  screen.stroke()
  screen.level(15); screen.circle(40,46-C.anim.poll_lfo*5,1.5); screen.fill()
  screen.level(2); screen.rect(52,42,60,3); screen.stroke()
  screen.level(math.floor(4+C.anim.poll_amp*11))
  screen.rect(52,42,math.floor(C.anim.poll_amp*60),3); screen.fill()
end

-- ── SCOPE ───────────────────────────────────────────────
function UI.draw_scope()
  local p=C.plot; local px1,px2=6,122; local py1,py2=11,50
  local pcx=math.floor((px1+px2)/2); local pcy=math.floor((py1+py2)/2)
  screen.level(2)
  screen.move(pcx,py1); screen.line(pcx,py2); screen.stroke()
  screen.move(px1,pcy); screen.line(px2,pcy); screen.stroke()
  if p.len>1 then
    local cnt=math.min(p.len-1,C.PLOT_SIZE-1)
    for i=0,cnt-1 do
      local ci=((p.idx-2-i)%C.PLOT_SIZE)+1
      local ni=((p.idx-3-i)%C.PLOT_SIZE)+1
      local br=math.floor(14*(1-(i/cnt)^2))
      if br<1 then break end
      screen.level(br)
      screen.move(util.clamp(util.linlin(-1,1,px1,px2,p.x[ci]),px1,px2),
                  util.clamp(util.linlin(-1,1,py2,py1,p.y[ci]),py1,py2))
      screen.line(util.clamp(util.linlin(-1,1,px1,px2,p.x[ni]),px1,px2),
                  util.clamp(util.linlin(-1,1,py2,py1,p.y[ni]),py1,py2))
      screen.stroke()
    end
    local hx=util.clamp(util.linlin(-1,1,px1,px2,C.anim.poll_rung),px1,px2)
    local hy=util.clamp(util.linlin(-1,1,py2,py1,C.anim.poll_tria),py1,py2)
    screen.level(4); screen.circle(hx,hy,3); screen.stroke()
    screen.level(15); screen.circle(hx,hy,1.5); screen.fill()
  end
end

-- ── PERFORM (4 macros with visual feedback) ─────────────
function UI.draw_perform()
  screen.font_size(8)
  local labels={"M1","M2","M3","M4"}
  local hints={"E2","E3","K2+E2","K2+E3"}

  for m=1,4 do
    local col=(m<=2) and 0 or 1
    local row=(m-1)%2
    local ox=col*66
    local oy=11+row*22
    local w,h=60,18
    local mc=C.macros[m]

    screen.level(4); screen.rect(ox+2,oy,w,h); screen.stroke()
    screen.level(12); screen.move(ox+4,oy+7); screen.text(labels[m])
    screen.level(3); screen.move(ox+16,oy+7); screen.text(hints[m])

    -- value bar
    local bx,by2,bw=ox+4,oy+10,w-6
    screen.level(2); screen.rect(bx,by2,bw,4); screen.stroke()
    screen.level(12); screen.rect(bx,by2,math.floor(mc.value*bw),4); screen.fill()
    screen.level(5)
    screen.move(bx+math.floor(bw/2),by2-1)
    screen.line(bx+math.floor(bw/2),by2+5); screen.stroke()

    -- assigned params (tiny)
    if #mc.slots > 0 then
      screen.level(3); screen.font_size(8)
      local txt = ""
      for _, slot in ipairs(mc.slots) do
        if #txt > 0 then txt = txt .. " " end
        txt = txt .. slot[1]:sub(1,5)
      end
      screen.move(ox+4, oy+h+5); screen.text(txt:sub(1,18))
    end
  end
end

return UI
