"""
render(m, out_path) — turn a finalized MatchData into a vertical (1080x1920)
post-match report MP4.

Scenes: intro -> battle control-map -> momentum -> MVP -> leaderboard ->
combat breakdown -> decisive blow -> winner card. Pure Pillow drawing; encoded
with the ffmpeg bundled by imageio-ffmpeg (no system ffmpeg needed).
"""
import math, numpy as np, imageio.v2 as imageio
from PIL import Image, ImageDraw, ImageFont

W, H, FPS = 1080, 1920, 30
BG=(11,15,21); PANEL=(20,26,35); WEST=(62,142,255); EAST=(236,72,72); GUER=(96,200,112)
NEU=(96,104,120); GOLD=(240,196,92); INK=(234,240,248); DIM=(138,149,165)
SIDE_COL={"west":WEST,"east":EAST,"guer":GUER,"neu":NEU}
SIDE_NAME={"west":"BLUFOR","east":"OPFOR","guer":"GUER","neu":"NEUTRAL"}

def F(sz,bold=True):
    return ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf" if bold else r"C:\Windows\Fonts\arial.ttf", sz)
f_huge=F(104); f_h1=F(70); f_h2=F(52); f_h3=F(40); f_md=F(34); f_sm=F(28); f_xs=F(23); f_num=F(60)

def ease(t): t=max(0,min(1,t)); return t*t*(3-2*t)
def lerp(a,b,t): return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(3))
def mix(c,t): return lerp(BG,c,t)

MX0,MY0,MS=40,470,1000

class Renderer:
    def __init__(self, m): self.m=m
    def to_canvas(self,x,y): S=self.m.world_size; return MX0+x/S*MS, MY0+(1-y/S)*MS

    def control_map(self,d,im,ts,flash=None,fk=0.0,x0=MX0,y0=MY0,size=MS,labels=True):
        m=self.m; o=m.owners_at(ts); GC=m.grid_n; S=m.world_size
        terr=np.zeros((GC,GC,3),np.uint8)
        for r in range(GC):
            for c in range(GC):
                s=o[m.tnames[m.nearest[r,c]]]; terr[r,c]=mix(SIDE_COL[s],0.30 if s!="neu" else 0.12)
        im.paste(Image.fromarray(terr).resize((size,size),Image.NEAREST),(x0,y0))
        for i in range(0,size+1,size//11):
            d.line([(x0+i,y0),(x0+i,y0+size)],fill=(255,255,255,8)); d.line([(x0,y0+i),(x0+size,y0+i)],fill=(255,255,255,8))
        d.rectangle([x0,y0,x0+size,y0+size],outline=(70,80,96),width=2); sc=size/MS
        for t,(x,y) in m.towns.items():
            cx=x0+x/S*size; cy=y0+(1-y/S)*size; s=o[t]; col=SIDE_COL[s]; rr=(9 if s!="neu" else 6)*sc
            if flash==t: d.ellipse([cx-26*fk,cy-26*fk,cx+26*fk,cy+26*fk],outline=col,width=3)
            d.ellipse([cx-rr,cy-rr,cx+rr,cy+rr],fill=col,outline=(8,10,14),width=2)
        if labels:
            big=sorted(m.towns,key=lambda t:-(m.towns[t][0]**2))[:5]
            for t in big:
                x,y=m.towns[t]; cx=x0+x/S*size; cy=y0+(1-y/S)*size; d.text((cx+12,cy-12),t,font=f_xs,fill=(220,226,236))

def vignette(d): d.rectangle([0,0,W,8],fill=(0,0,0,120)); d.rectangle([0,H-8,W,H],fill=(0,0,0,120))
def footer(d): d.text((W/2,H-46),"a2waspwarfare  ·  POST-MATCH REPORT",font=f_xs,fill=(120,130,146),anchor="mm")
def chip(d,x,y,side,fs=f_sm): c=SIDE_COL[side]; d.rectangle([x,y+4,x+12,y+30],fill=c); d.text((x+22,y),SIDE_NAME[side],font=fs,fill=c)
def panel(d,x0,y0,x1,y1,fill=PANEL,outline=(46,54,66)): d.rounded_rectangle([x0,y0,x1,y1],radius=18,fill=fill,outline=outline,width=2)
def header(d,title,sub=None):
    d.text((W/2,120),title,font=f_h1,fill=INK,anchor="mm")
    if sub: d.text((W/2,182),sub,font=f_sm,fill=DIM,anchor="mm")
    d.line([(W/2-160,214),(W/2+160,214)],fill=(60,70,84),width=3)
def donut(d,cx,cy,r,segs):
    a0=-90
    for frac,col in segs: a1=a0+frac*360; d.pieslice([cx-r,cy-r,cx+r,cy+r],a0,a1,fill=col); a0=a1
    d.ellipse([cx-r*0.58,cy-r*0.58,cx+r*0.58,cy+r*0.58],fill=BG)


def render(m, out_path):
    R=Renderer(m)
    frames=[]
    def base(): im=Image.new("RGB",(W,H),BG); return im,ImageDraw.Draw(im,"RGBA")
    def fade(im,k): return im if k>=1 else Image.fromarray((np.asarray(im).astype(np.float32)*k).astype(np.uint8))
    def scene(n,fn,fin=12,fout=10):
        for i in range(n):
            im,d=base(); fn(im,d,i,n)
            k=1.0
            if i<fin: k=ease(i/fin)
            if i>n-fout: k=ease((n-i)/fout)
            frames.append(np.asarray(fade(im,k)))

    def s_intro(im,d,i,n):
        d.text((W/2,H/2-150),"WASP WARFARE",font=f_huge,fill=INK,anchor="mm")
        d.text((W/2,H/2-30),m.map_name,font=f_h1,fill=WEST,anchor="mm")
        d.text((W/2,H/2+70),"POST-MATCH REPORT",font=f_h3,fill=DIM,anchor="mm")
        mm,ss=divmod(m.duration,60)
        d.text((W/2,H/2+150),f"{len(m.players)} operators   ·   {mm:02d}:{ss:02d}   ·   {m.total_kills} kills",font=f_sm,fill=(150,160,176),anchor="mm")

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
        mm,ss=divmod(int(ts),60); d.text((W/2,1500),f"{mm:02d}:{ss:02d}",font=f_h1,fill=INK,anchor="ma")
        feed=[k for k in m.kills if k[0]<=ts][-4:]; y=1600
        for (t,nm,s,wp,cat,dd) in feed:
            c=SIDE_COL[s]; d.rectangle([60,y+6,74,y+30],fill=c); d.text((86,y),nm or "AI",font=f_sm,fill=c)
            d.text((W/2,y),wp,font=f_sm,fill=DIM,anchor="ma"); d.text((W-60,y),f"{dd}m",font=f_sm,fill=(150,160,176),anchor="ra"); y+=62
        footer(d)

    def s_momentum(im,d,i,n):
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
        footer(d)

    def s_mvp(im,d,i,n):
        if not m.mvp: return
        header(d,"MATCH MVP"); p=m.mvp; col=SIDE_COL[p["side"]]; kk=ease(min(1,i/26))
        panel(d,140,300,W-140,470,fill=mix(col,0.10),outline=col)
        d.ellipse([200,330,310,440],fill=mix(col,0.25),outline=col,width=3); d.text((255,385),p["name"][:2].upper(),font=f_h2,fill=INK,anchor="mm")
        d.text((350,330),p["name"],font=f_h1,fill=INK); chip(d,352,418,p["side"],f_md)
        gx,gy=180,560; cw=(W-360)//2; num=lambda v:str(int(v*kk))
        cells=[("KILLS",num(p["kills"]),col),("DEATHS",num(p["d"][6]),INK),("K / D",f'{p["kd"]*kk:.2f}',GOLD),
               ("TOWN CAPS",num(p["d"][10]),col),("PVP KILLS",num(p["d"][7]),INK),("FAV WEAPON",p.get("fav","—") if kk>0.6 else "",col)]
        for idx,(lab,val,c) in enumerate(cells):
            x=gx+(idx%2)*cw; y=gy+(idx//2)*150; panel(d,x,y,x+cw-30,y+125)
            d.text((x+26,y+24),lab,font=f_sm,fill=DIM); d.text((x+26,y+58),val,font=f_h2 if len(val)<8 else f_h3,fill=c)
        d.text((W/2,1180),f'Top score: {int(p["score"]*kk)}',font=f_md,fill=DIM,anchor="ma"); footer(d)

    def s_board(im,d,i,n):
        header(d,"TOP OPERATORS","by match score"); top=m.players[:6]
        if not top: return
        mx=max(p["score"] for p in top) or 1; y0=320; bh=92; gap=22
        for idx,p in enumerate(top):
            y=y0+idx*(bh+gap); col=SIDE_COL[p["side"]]; prog=ease(min(1,(i-idx*4)/26)); bw=int((W-300)*p["score"]/mx*prog)
            d.text((70,y+bh/2),f"{idx+1}",font=f_h2,fill=GOLD if idx==0 else DIM,anchor="mm")
            panel(d,120,y,W-60,y+bh); d.rounded_rectangle([120,y,120+bw+40,y+bh],radius=18,fill=mix(col,0.22),outline=col,width=2)
            d.rectangle([124,y+18,138,y+bh-18],fill=col); d.text((158,y+16),p["name"],font=f_h3,fill=INK)
            d.text((158,y+58),f'{SIDE_NAME[p["side"]]}  ·  {p["kills"]}K / {p["d"][6]}D  ·  {p["d"][10]} caps',font=f_xs,fill=DIM)
            d.text((W-84,y+bh/2),str(int(p["score"]*prog)),font=f_h3,fill=INK,anchor="rm")
        footer(d)

    def s_combat(im,d,i,n):
        header(d,"COMBAT BREAKDOWN"); kk=ease(min(1,i/26))
        order=[("INF","Infantry",(90,160,250)),("VEH","Vehicle",(240,150,70)),("AIR","Air",(120,210,150)),("STATIC","Static",(200,120,210))]
        tot=sum(m.catcount.values()) or 1; segs=[(m.catcount[c]/tot*kk,col) for c,_,col in order]
        if kk<1: segs.append((1-kk,(40,46,56)))
        cx,cy,r=W/2,540,210; donut(d,cx,cy,r,segs)
        d.text((cx,cy-18),str(int(m.total_kills*kk)),font=f_h1,fill=INK,anchor="mm"); d.text((cx,cy+44),"TOTAL KILLS",font=f_xs,fill=DIM,anchor="mm")
        lx,ly=160,820
        for idx,(c,name,col) in enumerate(order):
            x=lx+(idx%2)*420; y=ly+(idx//2)*70; d.rectangle([x,y+4,x+24,y+28],fill=col)
            d.text((x+36,y),name,font=f_sm,fill=INK); d.text((x+360,y),f"{int(m.catcount[c]/tot*100)}%",font=f_sm,fill=DIM,anchor="ra")
        gy=1010; cw=(W-220)//2
        cards=[("LONGEST KILL",f"{m.longest[5]} m",f"{m.longest[3]}",GOLD),("TOP WEAPON",m.topweap[0],f"{m.topweap[1]} kills",WEST),
               ("PVP KILLS",str(m.pvp_total),"player vs player",INK),("TOWN CAPTURES",str(m.cap_total),"ownership flips",GUER)]
        for idx,(lab,big,sub,c) in enumerate(cards):
            x=110+(idx%2)*cw; y=gy+(idx//2)*200; panel(d,x,y,x+cw-20,y+175)
            d.text((x+26,y+22),lab,font=f_xs,fill=DIM); d.text((x+26,y+52),big,font=f_h3 if len(big)<12 else f_md,fill=c); d.text((x+26,y+120),sub,font=f_xs,fill=DIM)
        footer(d)

    def s_decisive(im,d,i,n):
        header(d,"DECISIVE BLOW"); t,town,s=m.decisive; col=SIDE_COL[s]; mm,ss=divmod(t,60)
        ms=560; mx0=(W-ms)//2; my0=300; R.control_map(d,im,t+1,flash=town,fk=1.0,x0=mx0,y0=my0,size=ms,labels=False)
        if town in m.towns:
            x,y=m.towns[town]; cx=mx0+x/m.world_size*ms; cy=my0+(1-y/m.world_size)*ms; pulse=18+8*math.sin(i/4)
            d.ellipse([cx-pulse,cy-pulse,cx+pulse,cy+pulse],outline=GOLD,width=4)
        d.text((W/2,930),town.upper(),font=f_h1,fill=col,anchor="ma"); d.text((W/2,1010),f"captured at {mm:02d}:{ss:02d}",font=f_md,fill=DIM,anchor="ma")
        w=sum(v=="west" for v in m.owners_at(t+1).values()); e=sum(v=="east" for v in m.owners_at(t+1).values())
        panel(d,120,1110,W-120,1250,fill=mix(col,0.10),outline=col)
        d.text((W/2,1140),f"This capture pushed {SIDE_NAME[s]} to {max(w,e)} towns",font=f_sm,fill=INK,anchor="ma")
        d.text((W/2,1182),"— the swing that decided the match.",font=f_sm,fill=INK,anchor="ma"); footer(d)

    def s_winner(im,d,i,n):
        k=ease(min(1,i/18)); col=SIDE_COL[m.winner]
        wash=np.asarray(im).astype(np.float32); wash[:]=mix(lerp(BG,col,0.20),k); im.paste(Image.fromarray(wash.astype(np.uint8)),(0,0)); d=ImageDraw.Draw(im,"RGBA")
        for j in range(80):
            px=(j*977)%W; sp=40+(j*53)%120; py=H-(i*sp/6)%H; d.ellipse([px,py,px+5,py+5],fill=lerp(col,INK,(j%5)/5))
        d.text((W/2,520),SIDE_NAME[m.winner],font=f_huge,fill=INK,anchor="mm"); d.text((W/2,650),"VICTORY",font=f_huge,fill=col,anchor="mm")
        mm,ss=divmod(m.duration,60); o=m.owners_at(m.duration); w=sum(v=="west" for v in o.values()); e=sum(v=="east" for v in o.values())
        mvp=m.mvp["name"]+f' ({m.mvp["kills"]}K)' if m.mvp else "—"
        rows=[("DURATION",f"{mm:02d}:{ss:02d}"),("FINAL TOWNS",f"{w} – {e}"),("TOTAL KILLS",str(m.total_kills)),("MVP",mvp),("MAP",m.map_name)]
        y=940
        for lab,val in rows:
            d.text((W/2-40,y),lab,font=f_md,fill=(225,231,240),anchor="ra"); d.text((W/2+40,y),val,font=f_md,fill=col,anchor="la"); y+=88
        d.text((W/2,1560),"a2waspwarfare",font=f_sm,fill=(220,226,238),anchor="mm")

    scene(54,s_intro,fin=18,fout=10); scene(420,s_battle); scene(168,s_momentum); scene(156,s_mvp)
    scene(186,s_board); scene(198,s_combat); scene(120,s_decisive); scene(126,s_winner,fin=4,fout=2)
    for _ in range(18): frames.append(frames[-1])

    imageio.mimwrite(out_path,frames,fps=FPS,codec="libx264",quality=8,macro_block_size=8,ffmpeg_params=["-pix_fmt","yuv420p"])
    return len(frames)
