"""
render(m, out_path) — turn a finalized MatchData into a vertical (1080x1920)
post-match report MP4.

Scenes: intro -> battle control-map -> momentum -> MVP -> leaderboard ->
combat breakdown -> decisive blow -> winner card. Pure Pillow drawing; encoded
with the ffmpeg bundled by imageio-ffmpeg (no system ffmpeg needed).
"""
import math, os, numpy as np, imageio.v2 as imageio
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# ---- optional generated art (drop PNGs in assets/; see assets.py / gen_prompts.py) ----
ASSET_DIR = os.path.join(os.path.dirname(__file__), "assets")
try: from assets import emblem_id, winner_bg_id, SILHOUETTES
except Exception:
    def emblem_id(s): return None
    def winner_bg_id(s): return None
    SILHOUETTES = []
_acache = {}
def asset(aid):
    if aid in _acache: return _acache[aid]
    img = None
    try:
        from assets import ASSETS
        meta = ASSETS.get(aid)
        if meta:
            p = os.path.join(ASSET_DIR, meta["file"])
            if os.path.exists(p): img = Image.open(p).convert("RGBA")
    except Exception: img = None
    _acache[aid] = img; return img

_BLOGO = os.path.join(os.path.dirname(__file__), "brand", "logo")
def brand_logo(name):
    key = "__blogo_" + name
    if key in _acache: return _acache[key]
    img = None; p = os.path.join(_BLOGO, name + ".png")
    if os.path.exists(p):
        try: img = Image.open(p).convert("RGBA")
        except Exception: img = None
    _acache[key] = img; return img

W, H, FPS = 1080, 1920, 30
# --- Miksuu's Warfare brand tokens (from miksuus-warfare/brand/tokens.css) ---
BG=(20,23,27)       # gunmetal #14171b
PANEL=(42,47,54)    # steel    #2a2f36
INK=(231,227,214)   # bone     #e7e3d6 (text)
DIM=(150,150,138)   # muted bone
GOLD=(217,118,60)   # orange   #d9763c (the brand accent / chrome)
WEST=(93,130,163)   # faction west #5d82a3
EAST=(168,80,63)    # faction east #a8503f
GUER=(122,134,72)   # olive #5c6536, lifted for legibility
NEU=(111,118,128)   # #6f7680
SIDE_COL={"west":WEST,"east":EAST,"guer":GUER,"neu":NEU}
SIDE_NAME={"west":"BLUFOR","east":"OPFOR","guer":"GUER","neu":"NEUTRAL"}

# --- brand typography: Oswald (display) / Inter (sans) / JetBrains Mono (numbers) ---
_FDIR=os.path.join(os.path.dirname(__file__),"brand","fonts")
def _bf(name,sz,fb="arialbd.ttf"):
    try: return ImageFont.truetype(os.path.join(_FDIR,name),sz)
    except Exception:
        try: return ImageFont.truetype(os.path.join(r"C:\Windows\Fonts",fb),sz)
        except Exception: return ImageFont.load_default()
def DISP(sz): return _bf("Oswald-700.ttf",sz)
def SANS(sz,b=True): return _bf("Inter-600.ttf" if b else "Inter-400.ttf",sz,"arial.ttf")
def MONO(sz): return _bf("JetBrainsMono-600.ttf",sz)
f_huge=DISP(118); f_h1=DISP(80); f_h2=DISP(58); f_h3=DISP(44)
f_md=SANS(34,True); f_sm=SANS(28,True); f_xs=SANS(23,False); f_num=MONO(58)

def ease(t): t=max(0,min(1,t)); return t*t*(3-2*t)
def lerp(a,b,t): return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(3))
def mix(c,t): return lerp(BG,c,t)

def paste_cover(im, aid, box=None, opacity=1.0):
    """Paste an asset scaled to COVER box (default whole frame). Returns True if used."""
    a = asset(aid)
    if a is None: return False
    bx = box or (0, 0, W, H); bw = bx[2]-bx[0]; bh = bx[3]-bx[1]
    s = max(bw/a.width, bh/a.height); a2 = a.resize((max(1,int(a.width*s)), max(1,int(a.height*s))))
    if opacity < 1.0:
        a2 = a2.copy(); a2.putalpha(a2.split()[3].point(lambda v:int(v*opacity)))
    im.paste(a2, (bx[0]+(bw-a2.width)//2, bx[1]+(bh-a2.height)//2), a2); return True

def paste_emblem(im, aid, cx, cy, maxw):
    a = asset(aid)
    if a is None: return False
    s = maxw/a.width; a2 = a.resize((max(1,int(a.width*s)), max(1,int(a.height*s))))
    im.paste(a2, (int(cx-a2.width/2), int(cy-a2.height/2)), a2); return True

def drift_silhouette(im, idx, i, n, yfrac=0.60, wfrac=0.7, opacity=0.10):
    """Faint drifting vehicle 'blackout' behind open scenes, if the asset exists."""
    if not SILHOUETTES: return
    a = asset(SILHOUETTES[idx % len(SILHOUETTES)])
    if a is None: return
    w = int(W*wfrac); a2 = a.resize((w, max(1, int(a.height*w/a.width)))).copy()
    a2.putalpha(a2.split()[3].point(lambda v: int(v*opacity)))
    x = int(-w*0.25 + (i/max(1, n))*(W + w*0.25)); y = int(H*yfrac)
    im.paste(a2, (x, y), a2)

_fx = {}
def _fx_vignette():
    if "vig" in _fx: return _fx["vig"]
    m = Image.new("L",(W,H),0); ImageDraw.Draw(m).ellipse([-W*0.45,-H*0.24,W*1.45,H*1.16], fill=255)
    m = m.filter(ImageFilter.GaussianBlur(260))
    dark = Image.new("RGBA",(W,H),(5,6,8,255)); dark.putalpha(Image.eval(m, lambda v:int((255-v)*0.42)))
    _fx["vig"]=dark; return dark
def _fx_grain():
    if "grain" not in _fx:
        _fx["grain"]=(np.random.default_rng(7).random((H+96,W))*255).astype(np.uint8)
    return _fx["grain"]
def _fx_frame():
    if "frame" in _fx: return _fx["frame"]
    fo=Image.new("RGBA",(W,H),(0,0,0,0)); d=ImageDraw.Draw(fo)
    c=(150,150,138,150); o=(217,118,60,170); L=72; mg=34
    for (cx,cy,sx,sy) in [(mg,mg,1,1),(W-mg,mg,-1,1),(mg,H-mg,1,-1),(W-mg,H-mg,-1,-1)]:
        d.line([(cx,cy),(cx+L*sx,cy)],fill=c,width=3); d.line([(cx,cy),(cx,cy+L*sy)],fill=c,width=3)
        d.line([(cx,cy),(cx+16*sx,cy)],fill=o,width=3)
    for x in range(150,W-120,96): d.line([(x,mg-7),(x,mg)],fill=(150,150,138,60))
    _fx["frame"]=fo; return fo

def overlay_fx(im, i=0):
    """Production polish over a finished RGB frame: cinematic vignette + animated film
    grain + a HUD corner frame. Codex's grain/frame_overlay PNGs override the procedural
    versions when present; otherwise everything is generated, so the look is always on."""
    out = im.convert("RGBA")
    out = Image.alpha_composite(out, _fx_vignette())
    gr = asset("grain")
    if gr is not None:
        g = gr.resize((W,H)).copy(); g.putalpha(g.split()[3].point(lambda v:int(v*0.10)))
        out = Image.alpha_composite(out, g)
    else:
        # static grain (i-independent) so x264 inter-prediction stays cheap -> small file
        gg=_fx_grain(); tile=Image.fromarray(gg[:H,:])
        out=Image.alpha_composite(out, Image.merge("RGBA",[tile]*3+[tile.point(lambda v:9)]))
    fo=asset("frame_overlay")
    out=Image.alpha_composite(out, fo.resize((W,H)) if fo is not None else _fx_frame())
    return out.convert("RGB")

MX0,MY0,MS=40,470,1000

WATER=(15,38,56); LAND_BASE=(22,30,28); COAST=(70,120,150)
class Renderer:
    def __init__(self, m):
        self.m=m; S=m.world_size
        # coastline: world_y below coast_y(x) is sea (Chernarus' south edge is all coast).
        self._coast=lambda x:1100+500*(x/S)+200*math.sin(x/S*8.0)
        # precompute a relief-noise field + sea/land mask + land-owner tint base on the grid.
        GC=m.grid_n; rngn=np.random.default_rng(5)
        self.sea=np.zeros((GC,GC),bool); self.relief=np.zeros((GC,GC),np.float32)
        for r in range(GC):
            for c in range(GC):
                gx=(c+0.5)/GC*S; gy=(1-(r+0.5)/GC)*S
                self.sea[r,c]= gy < self._coast(gx) or (gx>0.94*S and gy<0.42*S)
                self.relief[r,c]=0.5+0.5*math.sin(gx/S*22+gy/S*6)*math.cos(gy/S*17)
        self.relief=0.6*self.relief+0.4*rngn.random((GC,GC))
        # roads: connect each town to its 2 nearest neighbours (deduped undirected edges).
        names=m.tnames; pos=[m.towns[t] for t in names]; edges=set()
        for i,(ax,ay) in enumerate(pos):
            nn=sorted(range(len(pos)),key=lambda j:(pos[j][0]-ax)**2+(pos[j][1]-ay)**2)[1:3]
            for j in nn: edges.add((min(i,j),max(i,j)))
        self.roads=list(edges)

    def to_canvas(self,x,y): S=self.m.world_size; return MX0+x/S*MS, MY0+(1-y/S)*MS

    def control_map(self,d,im,ts,flash=None,fk=0.0,x0=MX0,y0=MY0,size=MS,labels=True):
        m=self.m; o=m.owners_at(ts); GC=m.grid_n; S=m.world_size; sc=size/MS
        # --- terrain layer: sea (banded water) + land (relief-shaded owner territory) ---
        terr=np.zeros((GC,GC,3),np.uint8)
        for r in range(GC):
            for c in range(GC):
                if self.sea[r,c]:
                    band=1.0+0.12*math.sin(r*0.9); terr[r,c]=tuple(min(255,int(v*band)) for v in WATER)
                else:
                    s=o[m.tnames[m.nearest[r,c]]]; rel=0.78+0.5*self.relief[r,c]
                    base=lerp(LAND_BASE,SIDE_COL[s],0.34 if s!="neu" else 0.10)
                    terr[r,c]=tuple(min(255,int(v*rel)) for v in base)
        im.paste(Image.fromarray(terr).resize((size,size),Image.NEAREST),(x0,y0))
        # --- coastline stroke ---
        coastpts=[]
        for c in range(0,size+1,8):
            gx=c/size*S; cy=y0+(1-self._coast(gx)/S)*size
            if y0<=cy<=y0+size: coastpts.append((x0+c,cy))
        if len(coastpts)>1: d.line(coastpts,fill=COAST,width=2)
        # --- military grid + edge coordinates ---
        for k in range(12):
            gx=x0+k*size/11; gy=y0+k*size/11
            d.line([(gx,y0),(gx,y0+size)],fill=(255,255,255,10)); d.line([(x0,gy),(x0+size,gy)],fill=(255,255,255,10))
            if k<11:
                d.text((x0+k*size/11+4,y0+2),chr(65+k),font=f_xs,fill=(90,100,116))
                d.text((x0+3,y0+k*size/11+2),f"{k:02d}",font=f_xs,fill=(90,100,116))
        d.rectangle([x0,y0,x0+size,y0+size],outline=(70,80,96),width=2)
        # --- roads (faint, under the town dots) ---
        for (i,j) in self.roads:
            ax,ay=m.towns[m.tnames[i]]; bx,by=m.towns[m.tnames[j]]
            d.line([(x0+ax/S*size,y0+(1-ay/S)*size),(x0+bx/S*size,y0+(1-by/S)*size)],fill=(120,128,120,90),width=max(1,int(2*sc)))
        # --- compass ---
        ccx,ccy=x0+size-44*sc,y0+46*sc
        d.ellipse([ccx-22*sc,ccy-22*sc,ccx+22*sc,ccy+22*sc],outline=(120,132,150),width=2)
        d.line([(ccx,ccy+14*sc),(ccx,ccy-14*sc)],fill=(200,210,225),width=2); d.polygon([(ccx,ccy-20*sc),(ccx-6*sc,ccy-8*sc),(ccx+6*sc,ccy-8*sc)],fill=EAST)
        d.text((ccx,ccy-34*sc),"N",font=f_xs,fill=(200,210,225),anchor="mm")
        # --- towns ---
        for t,(x,y) in m.towns.items():
            cx=x0+x/S*size; cy=y0+(1-y/S)*size; s=o[t]; col=SIDE_COL[s]; rr=(9 if s!="neu" else 6)*sc
            if flash==t: d.ellipse([cx-26*fk,cy-26*fk,cx+26*fk,cy+26*fk],outline=col,width=3)
            d.ellipse([cx-rr-2,cy-rr-2,cx+rr+2,cy+rr+2],fill=(8,10,14))
            d.ellipse([cx-rr,cy-rr,cx+rr,cy+rr],fill=col)
        if labels:
            placed=[]
            for t,(x,y) in sorted(m.towns.items(), key=lambda kv:-kv[1][1]):  # north-first
                cx=x0+x/S*size; cy=y0+(1-y/S)*size
                if any(abs(cx-px)<150*sc and abs(cy-py)<22*sc for px,py in placed): continue
                placed.append((cx,cy))
                d.text((cx+11*sc,cy-9*sc),t,font=f_xs,fill=(20,24,30))      # shadow for legibility
                d.text((cx+10*sc,cy-10*sc),t,font=f_xs,fill=(220,228,240))

def vignette(d): d.rectangle([0,0,W,8],fill=(0,0,0,120)); d.rectangle([0,H-8,W,H],fill=(0,0,0,120))
def footer(im,d):
    mk=brand_logo("mark"); txt="MIKSUU'S WARFARE   ·   POST-MATCH REPORT"; f=SANS(21,False); trk=3
    tw=sum(d.textlength(c,font=f) for c in txt)+trk*(len(txt)-1)
    mkw=28 if mk else 0; total=mkw+(12 if mk else 0)+tw; x0=W/2-total/2
    if mk: m2=mk.resize((28,28)); im.paste(m2,(int(x0),H-55),m2); x0+=mkw+12
    tracked(d,(x0,H-41),txt,f,(146,146,134),anchor="lm",track=trk)
def chip(d,x,y,side,fs=f_sm): c=SIDE_COL[side]; d.rectangle([x,y+4,x+12,y+30],fill=c); d.text((x+22,y),SIDE_NAME[side],font=fs,fill=c)
def panel(d,x0,y0,x1,y1,fill=PANEL,outline=(46,54,66)): d.rounded_rectangle([x0,y0,x1,y1],radius=18,fill=fill,outline=outline,width=2)

MARGIN = 72   # shared content margin / grid unit

def tracked(d, xy, text, font, fill, anchor="lm", track=0):
    """Draw text with letter-spacing (Pillow has none natively). anchor: h in l/m/r, v in a/m/s."""
    x, y = xy
    ws = [d.textlength(ch, font=font) for ch in text]
    total = sum(ws) + track*max(0, len(text)-1)
    cx = x - total/2 if anchor[0]=="m" else (x-total if anchor[0]=="r" else x)
    va = "l"+(anchor[1] if len(anchor)>1 else "m")
    for ch, w in zip(text, ws):
        d.text((cx, y), ch, font=font, fill=fill, anchor=va); cx += w+track

def rule(d, cx, y, half=150, accent=True):
    d.line([(cx-half, y),(cx-12, y)], fill=(74,84,96), width=2)
    d.line([(cx+12, y),(cx+half, y)], fill=(74,84,96), width=2)
    if accent: d.line([(cx-7, y),(cx+7, y)], fill=GOLD, width=4)

def header(d, title, sub=None):
    """Editorial header: tracked uppercase title + tracked kicker + accent rule. Shared by all scenes."""
    tracked(d, (W/2, 104), title.upper(), DISP(62), INK, anchor="mm", track=8)
    if sub: tracked(d, (W/2, 156), sub.upper(), SANS(23, False), DIM, anchor="mm", track=4)
    rule(d, W/2, 196, half=150)
def donut(d,cx,cy,r,segs):
    a0=-90
    for frac,col in segs: a1=a0+frac*360; d.pieslice([cx-r,cy-r,cx+r,cy+r],a0,a1,fill=col); a0=a1
    d.ellipse([cx-r*0.58,cy-r*0.58,cx+r*0.58,cy+r*0.58],fill=BG)

def caption(m):
    """Social caption built from the match — used as the Discord/TikTok post text."""
    mm, ss = divmod(m.duration, 60)
    side = SIDE_NAME.get(m.winner, m.winner.upper())
    mvp = f" MVP {m.mvp['name']} ({m.mvp['kills']}K)." if m.mvp else ""
    return (f"{side} victory on {m.map_name.title()} — {m.total_kills} kills in {mm:02d}:{ss:02d}.{mvp}\n"
            f"#arma2 #warfare #cti #miksuuswarfare #gaming #milsim")


def render(m, out_path):
    R=Renderer(m)
    frames=[]
    def base(): im=Image.new("RGB",(W,H),BG); return im,ImageDraw.Draw(im,"RGBA")
    def fade(im,k): return im if k>=1 else Image.fromarray((np.asarray(im).astype(np.float32)*k).astype(np.uint8))
    def scene(n,fn,fin=12,fout=10):
        for i in range(n):
            im,d=base(); fn(im,d,i,n); im=overlay_fx(im,i)
            k=1.0
            if i<fin: k=ease(i/fin)
            if i>n-fout: k=ease((n-i)/fout)
            frames.append(np.asarray(fade(im,k)))

    def s_intro(im,d,i,n):
        paste_cover(im,"intro_splash")   # generated background if present, else dark base
        mk=brand_logo("mark")
        if mk is not None:
            m2=mk.resize((300,300)); im.paste(m2,(int(W/2-150),int(H/2-455)),m2)
        tracked(d,(W/2,H/2-92),"MIKSUU'S WARFARE",DISP(82),INK,anchor="mm",track=6)
        tracked(d,(W/2,H/2+10),m.map_name.upper(),DISP(50),GOLD,anchor="mm",track=14)
        tracked(d,(W/2,H/2+80),"POST-MATCH REPORT",SANS(26,False),DIM,anchor="mm",track=8)
        mm,ss=divmod(m.duration,60)
        tracked(d,(W/2,H/2+152),f"{len(m.players)} OPERATORS      {mm:02d}:{ss:02d}      {m.total_kills} KILLS",SANS(23,False),(150,150,138),anchor="mm",track=3)

    def s_battle(im,d,i,n):
        ts=i/n*m.duration; ft=None; fk=0
        for (t,town,s) in m.caps:
            if abs(ts-t)<(m.duration/n)*8: ft=town; fk=max(fk,1-abs(ts-t)/((m.duration/n)*8))
        header(d,"THE BATTLE","territory control over the match")
        o=m.owners_at(ts); w=sum(v=="west" for v in o.values()); e=sum(v=="east" for v in o.values()); tot=len(m.towns); nn=tot-w-e
        d.text((60,300),"BLUFOR",font=f_h3,fill=WEST); d.text((60,346),str(w),font=f_num,fill=INK)
        d.text((W-60,300),"OPFOR",font=f_h3,fill=EAST,anchor="ra"); d.text((W-60,346),str(e),font=f_num,fill=INK,anchor="ra")
        d.text((W/2,330),f"{nn} contested",font=f_sm,fill=DIM,anchor="ma")
        bx,by,bw=40,440,W-80; t2=max(1,tot)
        d.rectangle([bx,by,bx+bw,by+12],fill=(40,46,56)); d.rectangle([bx,by,bx+int(bw*w/t2),by+12],fill=WEST)
        d.rectangle([bx+bw-int(bw*e/t2),by,bx+bw,by+12],fill=EAST)
        R.control_map(d,im,ts,ft,fk)
        mm,ss=divmod(int(ts),60); d.text((W/2,1452),f"{mm:02d}:{ss:02d}",font=f_h1,fill=INK,anchor="ma")
        tracked(d,(W/2,1566),"RECENT CONTACTS",SANS(20,False),(120,126,118),anchor="mm",track=5)
        feed=[k for k in m.kills if k[0]<=ts][-4:]; y=1600
        for (t,nm,s,wp,cat,dd) in feed:
            c=SIDE_COL[s]; d.rectangle([60,y+7,74,y+31],fill=c); d.text((90,y),(nm or "AI"),font=f_sm,fill=c)
            d.text((W-205,y),wp,font=f_sm,fill=DIM,anchor="ra"); d.text((W-60,y),f"{dd}m",font=f_sm,fill=(150,160,176),anchor="ra"); y+=56
        footer(im,d)

    def s_momentum(im,d,i,n):
        paste_cover(im,"bg_momentum",opacity=0.5)   # generated scene backdrop if present
        header(d,"MOMENTUM","towns held over time")
        px0,py0,pw,ph=90,360,W-180,760; panel(d,px0-20,py0-30,px0+pw+20,py0+ph+70)
        prog=ease(min(1,i/(n-12))); nshow=max(2,int(len(m.ser_x)*prog))
        def pt(idx,val): return px0+m.ser_x[idx]/m.duration*pw, py0+ph-val/20*ph
        for g in range(0,21,5):
            yy=py0+ph-g/20*ph; d.line([(px0,yy),(px0+pw,yy)],fill=(46,54,66)); d.text((px0-14,yy),str(g),font=f_xs,fill=DIM,anchor="rm")
        for ser,col in [(m.ser_w,WEST),(m.ser_e,EAST)]:
            pts=[pt(j,ser[j]) for j in range(nshow)]
            if len(pts)>1:
                d.line(pts,fill=col,width=5,joint="curve"); d.polygon(pts+[(pts[-1][0],py0+ph),(pts[0][0],py0+ph)],fill=col+(40,))
            d.ellipse([pts[-1][0]-7,pts[-1][1]-7,pts[-1][0]+7,pts[-1][1]+7],fill=col)
        dt=m.decisive[0]
        if m.ser_x[nshow-1]>=dt:
            mxp=px0+dt/m.duration*pw; d.line([(mxp,py0),(mxp,py0+ph)],fill=GOLD+(150,),width=2); d.text((mxp,py0-8),"supremacy",font=f_xs,fill=GOLD,anchor="mb")
        chip(d,px0,py0+ph+24,"west"); chip(d,px0+200,py0+ph+24,"east")
        d.text((W/2,1280),f"{SIDE_NAME[m.winner]} took the lead at the mid-game and never gave it back.",font=f_sm,fill=DIM,anchor="ma")
        footer(im,d)

    def s_mvp(im,d,i,n):
        if not m.mvp: return
        paste_cover(im,"mvp_backdrop",opacity=0.5)   # dimmed so the stat card pops
        header(d,"MATCH MVP"); p=m.mvp; col=SIDE_COL[p["side"]]; kk=ease(min(1,i/26))
        panel(d,140,300,W-140,470,fill=mix(col,0.10),outline=col)
        if not paste_emblem(im, emblem_id(p["side"]), 255, 385, 120):
            d.ellipse([200,330,310,440],fill=mix(col,0.25),outline=col,width=3); d.text((255,385),p["name"][:2].upper(),font=f_h2,fill=INK,anchor="mm")
        d.text((352,342),p["name"],font=DISP(60),fill=INK); chip(d,354,420,p["side"],SANS(24,False))
        gx,gy=180,560; cw=(W-360)//2; num=lambda v:str(int(v*kk))
        cells=[("KILLS",num(p["kills"]),col),("DEATHS",num(p["d"][6]),INK),("K / D",f'{p["kd"]*kk:.2f}',GOLD),
               ("TOWN CAPS",num(p["d"][10]),col),("PVP KILLS",num(p["d"][7]),INK),("FAV WEAPON",p.get("fav","—") if kk>0.6 else "",col)]
        for idx,(lab,val,c) in enumerate(cells):
            x=gx+(idx%2)*cw; y=gy+(idx//2)*150; panel(d,x,y,x+cw-30,y+125)
            d.text((x+26,y+24),lab,font=f_sm,fill=DIM); d.text((x+26,y+58),val,font=f_h2 if len(val)<8 else f_h3,fill=c)
        rule(d,W/2,1018,half=120,accent=False); tracked(d,(W/2,1052),f"TOP SCORE   {int(p['score']*kk)}",SANS(24,False),(200,204,196),anchor="mm",track=6); footer(im,d)

    def s_board(im,d,i,n):
        header(d,"TOP OPERATORS","by match score"); top=m.players[:6]
        if not top: return
        mx=max(p["score"] for p in top) or 1; y0=320; bh=92; gap=22
        for idx,p in enumerate(top):
            y=y0+idx*(bh+gap); col=SIDE_COL[p["side"]]; prog=ease(min(1,(i-idx*4)/26)); bw=int((W-300)*p["score"]/mx*prog)
            if idx==0 and paste_emblem(im,"icon_mvp",92,y+bh/2,52): pass   # medal on #1 if generated
            else: d.text((92,y+bh/2),f"{idx+1}",font=f_h2,fill=GOLD if idx==0 else DIM,anchor="mm")
            panel(d,120,y,W-60,y+bh); d.rounded_rectangle([120,y,120+bw+40,y+bh],radius=18,fill=mix(col,0.22),outline=col,width=2)
            d.rectangle([124,y+18,138,y+bh-18],fill=col); d.text((158,y+16),p["name"],font=f_h3,fill=INK)
            d.text((158,y+58),f'{SIDE_NAME[p["side"]]}  ·  {p["kills"]}K / {p["d"][6]}D  ·  {p["d"][10]} caps',font=f_xs,fill=DIM)
            d.text((W-84,y+bh/2),str(int(p["score"]*prog)),font=f_h3,fill=INK,anchor="rm")
        footer(im,d)

    def s_combat(im,d,i,n):
        header(d,"COMBAT BREAKDOWN"); kk=ease(min(1,i/26))
        order=[("INF","Infantry",(198,178,142)),("VEH","Vehicle",(217,118,60)),("AIR","Air",(122,134,72)),("STATIC","Static",(120,128,138))]  # brand: bone/orange/olive/steel
        tot=sum(m.catcount.values()) or 1; segs=[(m.catcount[c]/tot*kk,col) for c,_,col in order]
        if kk<1: segs.append((1-kk,(40,46,56)))
        cx,cy,r=W/2,540,210; donut(d,cx,cy,r,segs)
        d.text((cx,cy-18),str(int(m.total_kills*kk)),font=f_h1,fill=INK,anchor="mm"); d.text((cx,cy+44),"TOTAL KILLS",font=f_xs,fill=DIM,anchor="mm")
        lx,ly=160,820
        for idx,(c,name,col) in enumerate(order):
            x=lx+(idx%2)*420; y=ly+(idx//2)*70; d.rectangle([x,y+4,x+24,y+28],fill=col)
            d.text((x+36,y),name,font=f_sm,fill=INK); d.text((x+360,y),f"{int(m.catcount[c]/tot*100)}%",font=f_sm,fill=DIM,anchor="ra")
        gy=1010; cw=(W-220)//2
        cards=[("LONGEST KILL",f"{m.longest[5]} m",f"{m.longest[3]}",GOLD,"icon_longest"),("TOP WEAPON",m.topweap[0],f"{m.topweap[1]} kills",WEST,"icon_weapon"),
               ("PVP KILLS",str(m.pvp_total),"player vs player",INK,"icon_pvp"),("TOWN CAPTURES",str(m.cap_total),"ownership flips",GUER,"icon_captures")]
        for idx,(lab,big,sub,c,ic) in enumerate(cards):
            x=110+(idx%2)*cw; y=gy+(idx//2)*200; panel(d,x,y,x+cw-20,y+175)
            paste_emblem(im,ic,x+cw-58,y+44,48)   # stat icon (top-right) if generated
            d.text((x+26,y+22),lab,font=f_xs,fill=DIM); d.text((x+26,y+52),big,font=f_h3 if len(big)<12 else f_md,fill=c); d.text((x+26,y+120),sub,font=f_xs,fill=DIM)
        footer(im,d)

    def s_decisive(im,d,i,n):
        header(d,"DECISIVE BLOW"); t,town,s=m.decisive; col=SIDE_COL[s]; mm,ss=divmod(t,60)
        ms=560; mx0=(W-ms)//2; my0=300; R.control_map(d,im,t+1,flash=town,fk=1.0,x0=mx0,y0=my0,size=ms,labels=False)
        if town in m.towns:
            x,y=m.towns[town]; cx=mx0+x/m.world_size*ms; cy=my0+(1-y/m.world_size)*ms; pulse=18+8*math.sin(i/4)
            d.ellipse([cx-pulse,cy-pulse,cx+pulse,cy+pulse],outline=GOLD,width=4)
        tracked(d,(W/2,948),town.upper(),DISP(56),col,anchor="mm",track=10); tracked(d,(W/2,1008),f"CAPTURED AT {mm:02d}:{ss:02d}",SANS(23,False),DIM,anchor="mm",track=4)
        w=sum(v=="west" for v in m.owners_at(t+1).values()); e=sum(v=="east" for v in m.owners_at(t+1).values())
        panel(d,120,1110,W-120,1250,fill=mix(col,0.10),outline=col)
        d.text((W/2,1140),f"This capture pushed {SIDE_NAME[s]} to {max(w,e)} towns",font=f_sm,fill=INK,anchor="ma")
        d.text((W/2,1182),"— the swing that decided the match.",font=f_sm,fill=INK,anchor="ma"); footer(im,d)

    def s_winner(im,d,i,n):
        k=ease(min(1,i/18)); col=SIDE_COL[m.winner]
        if paste_cover(im, winner_bg_id(m.winner)):
            d=ImageDraw.Draw(im,"RGBA")
        else:
            wash=np.asarray(im).astype(np.float32); wash[:]=mix(lerp(BG,col,0.20),k); im.paste(Image.fromarray(wash.astype(np.uint8)),(0,0)); d=ImageDraw.Draw(im,"RGBA")
            for j in range(80):
                px=(j*977)%W; sp=40+(j*53)%120; py=H-(i*sp/6)%H; d.ellipse([px,py,px+5,py+5],fill=lerp(col,INK,(j%5)/5))
        drift_silhouette(im, 0, i, n, yfrac=0.72, wfrac=0.60, opacity=0.10)  # faint blackout low, if generated
        paste_emblem(im, emblem_id(m.winner), W/2, 320, 200)
        tracked(d,(W/2,522),SIDE_NAME[m.winner],DISP(100),INK,anchor="mm",track=8); tracked(d,(W/2,648),"VICTORY",DISP(100),col,anchor="mm",track=16)
        mm,ss=divmod(m.duration,60); o=m.owners_at(m.duration); w=sum(v=="west" for v in o.values()); e=sum(v=="east" for v in o.values())
        mvp=m.mvp["name"]+f' ({m.mvp["kills"]}K)' if m.mvp else "—"
        rows=[("DURATION",f"{mm:02d}:{ss:02d}"),("FINAL TOWNS",f"{w} – {e}"),("TOTAL KILLS",str(m.total_kills)),("MVP",mvp),("MAP",m.map_name)]
        y=940
        for lab,val in rows:
            d.text((W/2-40,y),lab,font=f_md,fill=(225,231,240),anchor="ra"); d.text((W/2+40,y),val,font=f_md,fill=col,anchor="la"); y+=88
        mk=brand_logo("mark")
        if mk is not None:
            m2=mk.resize((60,60)); im.paste(m2,(int(W/2-30),1498),m2)
        d.text((W/2,1580),"MIKSUU'S WARFARE",font=f_sm,fill=INK,anchor="mm")

    scene(54,s_intro,fin=18,fout=10); scene(420,s_battle); scene(168,s_momentum); scene(156,s_mvp)
    scene(186,s_board); scene(198,s_combat); scene(120,s_decisive); scene(126,s_winner,fin=4,fout=2)
    for _ in range(18): frames.append(frames[-1])

    imageio.mimwrite(out_path,frames,fps=FPS,codec="libx264",macro_block_size=8,
                     ffmpeg_params=["-crf","24","-preset","slow","-pix_fmt","yuv420p","-movflags","+faststart"])
    # crf 24 keeps a 48s clip ~6 MB — comfortably under Discord's non-boosted upload limit
    # (10.9 MB was rejected) while staying crisp at 1080p. Bump lower (19) only for off-Discord exports.
    return len(frames)


def render_leaderboard(data, out_path):
    """Render the real server leaderboard (LeaderboardData) -> mp4. Reuses the branded helpers."""
    frames=[]
    def base(): im=Image.new("RGB",(W,H),BG); return im,ImageDraw.Draw(im,"RGBA")
    def _fade(im,k): return im if k>=1 else Image.fromarray((np.asarray(im).astype(np.float32)*k).astype(np.uint8))
    def scn(n,fn,fin=12,fout=10):
        for i in range(n):
            im,d=base(); fn(im,d,i,n); im=overlay_fx(im,i)
            k=1.0
            if i<fin: k=ease(i/fin)
            if i>n-fout: k=ease((n-i)/fout)
            frames.append(np.asarray(_fade(im,k)))

    def s_intro(im,d,i,n):
        mk=brand_logo("mark")
        if mk is not None: m2=mk.resize((300,300)); im.paste(m2,(int(W/2-150),int(H/2-455)),m2)
        tracked(d,(W/2,H/2-92),"MIKSUU'S WARFARE",DISP(78),INK,anchor="mm",track=6)
        tracked(d,(W/2,H/2+8),"SERVER LEADERBOARD",DISP(46),GOLD,anchor="mm",track=10)
        tracked(d,(W/2,H/2+80),f"{data.n_players} OPERATORS      {data.total_kills} KILLS LOGGED",SANS(24,False),(150,150,138),anchor="mm",track=3)

    def s_board(im,d,i,n):
        header(d,"TOP OPERATORS","by total score"); top=data.players[:6]
        if not top: return
        mx=max(p["score"] for p in top) or 1; y0=320; bh=92; gap=22
        for idx,p in enumerate(top):
            y=y0+idx*(bh+gap); col=SIDE_COL[p["side"]]; prog=ease(min(1,(i-idx*4)/26)); bw=int((W-300)*p["score"]/mx*prog)
            if idx==0 and paste_emblem(im,"icon_mvp",92,y+bh/2,52): pass
            else: d.text((92,y+bh/2),f"{idx+1}",font=f_h2,fill=GOLD if idx==0 else DIM,anchor="mm")
            panel(d,120,y,W-60,y+bh); d.rounded_rectangle([120,y,120+bw+40,y+bh],radius=18,fill=mix(col,0.22),outline=col,width=2)
            d.rectangle([124,y+18,138,y+bh-18],fill=col); d.text((158,y+16),p["name"],font=f_h3,fill=INK)
            d.text((158,y+58),f'{SIDE_NAME[p["side"]]}   ·   {p["kills"]} kills   ·   {p["caps"]} caps',font=f_xs,fill=DIM)
            d.text((W-84,y+bh/2),str(int(p["score"]*prog)),font=f_h3,fill=INK,anchor="rm")
        footer(im,d)

    def s_mvp(im,d,i,n):
        if not data.mvp: return
        paste_cover(im,"mvp_backdrop",opacity=0.5)
        header(d,"SERVER MVP"); p=data.mvp; col=SIDE_COL[p["side"]]; kk=ease(min(1,i/26))
        panel(d,140,300,W-140,470,fill=mix(col,0.10),outline=col)
        if not paste_emblem(im, emblem_id(p["side"]), 255, 385, 120):
            d.ellipse([200,330,310,440],fill=mix(col,0.25),outline=col,width=3); d.text((255,385),p["name"][:2].upper(),font=f_h2,fill=INK,anchor="mm")
        d.text((352,342),p["name"],font=DISP(60),fill=INK); chip(d,354,420,p["side"],SANS(24,False))
        gx,gy=180,560; cw=(W-360)//2; num=lambda v:str(int(v*kk))
        cells=[("KILLS",num(p["kills"]),col),("SCORE",num(p["score"]),GOLD),("INFANTRY",num(p["inf"]),INK),
               ("VEHICLE",num(p["veh"]),col),("AIR",num(p["air"]),INK),("TOWN CAPS",num(p["caps"]),col)]
        for idx,(lab,val,c) in enumerate(cells):
            x=gx+(idx%2)*cw; y=gy+(idx//2)*150; panel(d,x,y,x+cw-30,y+125)
            d.text((x+26,y+24),lab,font=f_sm,fill=DIM); d.text((x+26,y+58),val,font=f_h2 if len(val)<8 else f_h3,fill=c)
        rule(d,W/2,1018,half=120,accent=False); tracked(d,(W/2,1052),"TOP OPERATOR ON THE SERVER",SANS(22,False),(200,204,196),anchor="mm",track=6); footer(im,d)

    def s_combat(im,d,i,n):
        header(d,"COMBAT BREAKDOWN","all operators, all time"); kk=ease(min(1,i/26))
        order=[("INF","Infantry",(198,178,142)),("VEH","Vehicle",(217,118,60)),("AIR","Air",(122,134,72)),("STATIC","Static",(120,128,138))]
        tot=sum(data.catcount.values()) or 1; segs=[(data.catcount[c]/tot*kk,col) for c,_,col in order]
        if kk<1: segs.append((1-kk,(40,46,56)))
        cx,cy,r=W/2,540,210; donut(d,cx,cy,r,segs)
        d.text((cx,cy-18),str(int(data.total_kills*kk)),font=f_h1,fill=INK,anchor="mm"); d.text((cx,cy+44),"TOTAL KILLS",font=f_xs,fill=DIM,anchor="mm")
        lx,ly=160,820
        for idx,(c,name,col) in enumerate(order):
            x=lx+(idx%2)*420; y=ly+(idx//2)*70; d.rectangle([x,y+4,x+24,y+28],fill=col)
            d.text((x+36,y),name,font=f_sm,fill=INK); d.text((x+360,y),f"{int(data.catcount[c]/tot*100)}%",font=f_sm,fill=DIM,anchor="ra")
        gy=1010; cw=(W-220)//2; top=data.mvp
        mostcaps=max(data.players,key=lambda p:p["caps"]) if data.players else None
        cards=[("TOP FRAGGER",top["name"] if top else "—",f"{top['kills']} kills" if top else "",GOLD,"icon_kills"),
               ("MOST CAPTURES",mostcaps["name"] if mostcaps else "—",f"{mostcaps['caps']} towns" if mostcaps else "",GUER,"icon_captures"),
               ("OPERATORS",str(data.n_players),"tracked",INK,"icon_mvp"),
               ("TOTAL CAPTURES",str(sum(p["caps"] for p in data.players)),"all time",WEST,"icon_towns")]
        for idx,(lab,big,sub,c,ic) in enumerate(cards):
            x=110+(idx%2)*cw; y=gy+(idx//2)*200; panel(d,x,y,x+cw-20,y+175)
            paste_emblem(im,ic,x+cw-58,y+44,48)
            d.text((x+26,y+22),lab,font=f_xs,fill=DIM); d.text((x+26,y+52),str(big),font=f_h3 if len(str(big))<12 else f_md,fill=c); d.text((x+26,y+120),sub,font=f_xs,fill=DIM)
        footer(im,d)

    def s_outro(im,d,i,n):
        paste_cover(im,"outro_bg")
        mk=brand_logo("mark")
        if mk is not None: m2=mk.resize((220,220)); im.paste(m2,(int(W/2-110),int(H/2-360)),m2)
        tracked(d,(W/2,H/2-90),"JOIN THE WAR",DISP(74),INK,anchor="mm",track=8)
        tracked(d,(W/2,H/2+6),"MIKSUU'S WARFARE",DISP(44),GOLD,anchor="mm",track=10)
        tracked(d,(W/2,H/2+86),"MIKSUUSWARFARE.COM",SANS(26,False),(200,204,196),anchor="mm",track=6)

    scn(54,s_intro,fin=18,fout=10); scn(210,s_board); scn(156,s_mvp); scn(186,s_combat); scn(120,s_outro,fin=12,fout=2)
    for _ in range(18): frames.append(frames[-1])
    imageio.mimwrite(out_path,frames,fps=FPS,codec="libx264",macro_block_size=8,
                     ffmpeg_params=["-crf","24","-preset","slow","-pix_fmt","yuv420p","-movflags","+faststart"])
    return len(frames)


def caption_leaderboard(data):
    mvp = f" Top operator: {data.mvp['name']} ({data.mvp['kills']}K)." if data.mvp else ""
    return (f"MIKSUU'S WARFARE — server leaderboard. {data.n_players} operators, "
            f"{data.total_kills} kills logged.{mvp}\n"
            f"#arma2 #warfare #cti #miksuuswarfare #leaderboard #milsim")
