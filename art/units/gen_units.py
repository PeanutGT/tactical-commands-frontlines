import os, cairosvg
OUT='/mnt/project-files/art/units'
L='#e6e6e6'; M='#b4b4b4'; D='#6a6a6a'; K='#1c1c1c'; SW='stroke="%s" stroke-width="1.4" stroke-linejoin="round"'%K
def R(x,y,w,h,f=L,r=1.5): return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{f}" {SW}/>'
def C(x,y,r,f=L): return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{f}" {SW}/>'
def P(pts,f=L): return '<polygon points="%s" fill="%s" %s/>'%(' '.join(f'{a},{b}' for a,b in pts),f,SW)
def Ln(x1,y1,x2,y2,w=1.2,c=K): return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{c}" stroke-width="{w}" stroke-linecap="round"/>'
def tracks(x1,x2,y1,y2,w=6):
    s=''
    for x in (x1,x2):
        s+=R(x,y1,w,y2-y1,D,1.5)
        for y in range(int(y1)+3,int(y2)-1,4): s+=Ln(x+1,y,x+w-1,y,0.7,'#3a3a3a')
    return s
def wheels(xs,ys,w=5,h=7):
    return ''.join(R(x,y,w,h,D,2) for x in xs for y in ys)
def barrel(x,y1,y2,w=3): return R(x-w/2,y1,w,y2-y1,M,0.8)
U={};T={}
U['mbt']=tracks(13,45,8,58)+P([(19,10),(45,10),(45,56),(19,56)],M);T['mbt']=((32,35),barrel(32,2,26)+P([(23,26),(41,26),(44,34),(41,44),(23,44),(20,34)])+C(36,38,2.5,M))
U['heavy_tank']=tracks(9,49,6,60,7)+R(15,8,34,50,M,2)+R(14,16,4,10,D,1)+R(46,16,4,10,D,1)+R(14,34,4,10,D,1)+R(46,34,4,10,D,1);T['heavy_tank']=((32,35),barrel(32,0,24,3.6)+P([(21,24),(43,24),(47,33),(43,46),(21,46),(17,33)])+R(24,40,16,5,M,1)+C(37,30,2.5,M))
U['light_tank']=tracks(18,40,16,52,5)+R(22,17,20,34,M,1.5);T['light_tank']=((32,34),barrel(32,8,30,2.4)+C(32,34,8)+C(35,37,1.8,M))
U['tank_destroyer']=tracks(14,44,10,58)+P([(32,6),(44,14),(44,56),(20,56),(20,14)],M)+P([(32,12),(41,18),(41,36),(23,36),(23,18)])+barrel(32,-2,18,3.4)+C(32,18,3.2,M)+''.join(Ln(24,y,40,y,0.8,'#555') for y in (42,46,50))
U['ifv']=wheels((15,44),(14,24,34,44))+P([(26,7),(38,7),(44,15),(44,57),(20,57),(20,15)],M)+R(25,50,14,5,D,1);T['ifv']=((30,30),barrel(30,6,26,1.8)+C(30,30,6.5))
U['apc']=tracks(15,43,10,56)+P([(23,10),(41,10),(43,16),(43,55),(21,55),(21,16)],L)+Ln(21,20,43,20,0.9)+R(26,49,12,5,D,1);T['apc']=((37,26),C(37,26,3.5,M)+Ln(37,26,37,18,1.4))
U['recon']=wheels((19,40),(17,40),5,8)+P([(27,12),(37,12),(41,19),(41,52),(23,52),(23,19)],M)+C(32,45,1.8,D);T['recon']=((32,32),C(32,32,4.5)+Ln(32,32,32,22,1.4))
U['spg']=tracks(14,44,10,60)+R(20,12,24,46,M,1.5);T['spg']=((32,41),barrel(32,-2,32,2.8)+R(19,28,26,26,L,2)+R(29,30,6,4,M,1))
U['mlrs']=wheels((16,43),(10,40,50))+R(21,6,22,14,M,2)+R(23,8,18,5,D,1)+R(19,23,26,36,L,1.5)+''.join(C(23+6*i,29+6*j,1.9,D) for i in range(4) for j in range(5))
U['aa']=tracks(14,44,10,58)+R(20,12,24,44,M,1.5)+P([(25,44),(39,44),(37,50),(27,50)],M)+Ln(32,44,32,40,1.2);T['aa']=((32,32),barrel(28,6,30,1.8)+barrel(36,6,30,1.8)+C(32,32,9))
U['truck']=wheels((17,42),(13,38,48))+R(22,8,20,13,M,2)+R(24,10,16,5,D,1)+R(20,23,24,34,L,1.5)+''.join(Ln(20,y,44,y,0.8,'#555') for y in (30,37,44,51))
U['engineer']=tracks(13,45,8,58)+R(19,10,26,46,M,1.5)+R(17,14,30,38,L,1.5)+Ln(17,33,47,33,1)+''.join(Ln(19+4*i,15,21+4*i,32,0.7,'#555')+Ln(21+4*i,34,19+4*i,51,0.7,'#555') for i in range(7))
U['recovery']=tracks(13,45,8,58)+R(19,10,26,46,M,1.5)+R(22,30,20,20,L,1.5)+Ln(26,40,40,8,3.2,K)+Ln(26,40,40,8,1.6,L)+C(26,40,3,M)+R(22,12,10,8,D,1)
U['infantry']=R(25,36,14,11,M,2)+'<ellipse cx="32" cy="34" rx="12" ry="6.5" fill="%s" %s/>'%(L,SW)+Ln(38,32,40,12,2.4)+Ln(36,32,40,24,1.6,D)+C(32,33,6,M)+C(32,32,3,L)
SC={'infantry':1.4,'light_tank':1.15,'recon':1.2}
import json
def wrap(b,k):
    k_=SC.get(k,1)
    return b if k_==1 else f'<g transform="translate(32,32) scale({k_}) translate(-32,-32)">{b}</g>'
def shadow(b): return f'<g transform="translate(1.6,1.6)" opacity="0.35">{b.replace(L,"#000").replace(M,"#000").replace(D,"#000")}</g>'
def svg(body,sh=True): return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">{shadow(body) if sh else ""}{body}</svg>'
def burnt(b): return b.replace(L,'#5c5650').replace(M,'#47423d').replace(D,'#2e2b28')
meta={}
for k,h in U.items():
    t=T.get(k); full=h+(t[1] if t else '')
    open(f'{OUT}/unit_{k}.svg','w').write(svg(wrap(full,k)))
    sc=SC.get(k,1); m={'scale':sc}
    if t:
        (px,py),tb=t
        open(f'{OUT}/unit_{k}_hull.svg','w').write(svg(wrap(h,k)))
        open(f'{OUT}/unit_{k}_turret.svg','w').write(svg(wrap(tb,k)))
        m['turret_pivot']=[round(32+(px-32)*sc,2),round(32+(py-32)*sc,2)]
        wr=burnt(h)+f'<g transform="translate(3,-2) rotate(28 {px} {py})">{burnt(tb)}</g>'
    else: wr=burnt(h)
    wr+='<ellipse cx="34" cy="36" rx="14" ry="10" fill="#000" opacity="0.25"/>'
    open(f'{OUT}/unit_{k}_wreck.svg','w').write(svg(wrap(wr,k)))
    meta[k]=m
json.dump({'size':64,'facing':'up (-y)','units':meta},open(f'{OUT}/units_meta.json','w'),indent=1)
print(len(U),len(T))
