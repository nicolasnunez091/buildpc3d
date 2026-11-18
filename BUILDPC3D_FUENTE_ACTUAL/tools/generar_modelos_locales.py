# Modelos 3D geométricos originales para prototipo; NO réplicas de fabricante.
from pathlib import Path
import json, math, re, shutil, random
import numpy as np, trimesh
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'godot/assets/models'
OUT.mkdir(parents=True, exist_ok=True)
CAT=json.loads((ROOT/'godot/data/catalog.json').read_text(encoding='utf-8'))
FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FONT_SMALL='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
PALETTES={
  'AMD': ('#a31833','#262a2f'), 'NVIDIA': ('#78be20','#111417'), 'Intel': ('#2684c8','#343b43'),
  'ASUS': ('#cc2452','#15181f'), 'Gigabyte': ('#f08a28','#1b2229'), 'MSI': ('#ed203d','#17171b'),
  'ASRock': ('#b2c4d5','#222d35'),'Corsair': ('#e3bd43','#1b1c20'),'Kingston': ('#ce233f','#141417'),
  'Thermaltake': ('#e22d3d','#202328'), 'Aerocool': ('#a0e8ec','#202a31'),'NZXT': ('#bba3df','#171b24'),
  'Iceberg': ('#66c2ee','#1a2231'), 'Lian Li': ('#dee5f1','#1b242b'),'Cooler Master': ('#9f6bdd','#20202b'),
  'EVGA': ('#d2d9e6','#191919'), 'Crucial': ('#378dbc','#252832'), 'G.Skill': ('#d93140','#1a1c20'),
}

def rgba(h,alpha=255):
 if isinstance(h,(list,tuple)):return [int(x) for x in h]
 h=h.lstrip('#');return [int(h[i:i+2],16) for i in (0,2,4)]+[alpha]

class Build:
 def __init__(self):self.scene=trimesh.Scene();self.i=0;self.groups={}
 def put(self, mesh, c='#344353'):
  if c is not None:
   self.groups.setdefault(c,[]).append(mesh)
  else:
   self.scene.add_geometry(mesh,node_name=f'n{self.i}',geom_name=f'g{self.i}');self.i+=1
 def box(self,p,s,c):
  m=trimesh.creation.box(extents=s);m.apply_translation(p);self.put(m,c)
 def cylinder(self,p,r,depth,c,axis='z',sections=16):
  m=trimesh.creation.cylinder(radius=r,height=depth,sections=sections)
  if axis=='y':m.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2,[1,0,0]))
  if axis=='x':m.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2,[0,1,0]))
  m.apply_translation(p);self.put(m,c)
 def ring(self,p,outer,inner,depth,c,axis='z',segments=32):
  verts=[]; faces=[]
  for z in [-depth/2,depth/2]:
   for radius in [outer,inner]:
    for k in range(segments):
     a=2*math.pi*k/segments;verts.append([radius*math.cos(a),radius*math.sin(a),z])
  for k in range(segments):
   nxt=(k+1)%segments
   for a,b in [(0,1),(2,3),(0,2),(1,3)]:
    x=a*segments+k;y=a*segments+nxt;u=b*segments+k;v=b*segments+nxt
    faces.extend([[x,y,v],[x,v,u]])
  m=trimesh.Trimesh(vertices=verts,faces=faces,process=False)
  if axis=='x':m.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2,[0,1,0]))
  if axis=='y':m.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2,[1,0,0]))
  m.apply_translation(p);self.put(m,c)
 def blade(self,cx,cy,z,r,a,c):
  # curved, tapered fan blade triangular mesh with thickness and metallic highlights
  xy=[]
  for mult,theta in [(0.25,a),(0.93,a+0.15),(0.65,a+0.60),(0.25,a+0.50)]:
   xy.append((cx+r*mult*math.cos(theta),cy+r*mult*math.sin(theta)))
  verts=[[x,y,z+(0.011 if j%2==0 else 0.0)] for j,(x,y) in enumerate(xy)]
  m=trimesh.Trimesh(vertices=verts,faces=[[0,1,2],[0,2,3]],process=False);self.put(m,c)
 def fan(self,p,r,color='#202b34',accent='#e7417b',axis='z',blades=9):
  x,y,z=p
  self.ring(p,r,r*.82,.028,color,axis=axis)
  self.ring(p,r*.79,r*.73,.018,accent,axis=axis)
  # All visible front fans in XY plane
  if axis=='z':
   for i in range(blades):self.blade(x,y,z+.025,r,2*math.pi*i/blades,'#697581')
   self.cylinder((x,y,z+.03),r*.22,.045,'#232a35')
   self.cylinder((x,y,z+.056),r*.10,.008,accent)
  else:
   self.cylinder(p,r*.25,.04,'#202831',axis=axis)
 def text_plate(self,text,sub,p,s,bg='#151b24',fg='#ffffff',brand='',accent='#ce2356'):
  # textured rectangular nameplate on XY facing +Z
  w,h=s
  im=Image.new('RGBA',(768,192),tuple(rgba(bg)))
  d=ImageDraw.Draw(im)
  d.rounded_rectangle((12,12,756,180),radius=18,outline=tuple(rgba(accent)),width=6)
  f=ImageFont.truetype(FONT,38)
  fs=ImageFont.truetype(FONT_SMALL,23)
  txt=text[:27]
  if d.textbbox((0,0),txt,font=f)[2]>700: f=ImageFont.truetype(FONT,27)
  d.text((25,25),txt,font=f,fill=tuple(rgba(fg)))
  d.text((26,100),sub[:52],font=fs,fill=tuple(rgba('#bac6ce')))
  x,y,z=p
  pts=[[x-w/2,y-h/2,z],[x+w/2,y-h/2,z],[x+w/2,y+h/2,z],[x-w/2,y+h/2,z]]
  m=trimesh.Trimesh(vertices=pts,faces=[[0,1,2],[0,2,3]],process=False)
  # glTF texture coord origin bottom left
  uv=np.array([[0,1],[1,1],[1,0],[0,0]])
  m.visual=trimesh.visual.TextureVisuals(uv=uv,material=trimesh.visual.material.PBRMaterial(baseColorTexture=im,metallicFactor=0.02,roughnessFactor=0.70))
  self.put(m,None)
 def export(self,path):
  for c, meshes in self.groups.items():
   mesh=trimesh.util.concatenate(meshes)
   mesh.visual.vertex_colors=np.tile(rgba(c),(len(mesh.vertices),1))
   self.scene.add_geometry(mesh,node_name=f'n{self.i}',geom_name=f'g{self.i}')
   self.i+=1
  self.scene.export(path)


def gpu(d):
 b=Build(); name=d['name'];brand=d['brand'];accent,shade=PALETTES.get(brand,('#e22a62','#1b1d22'))
 mm=d.get('length_mm',240);L=max(.80,min(1.55, mm/300*1.5));h=.38;z=.0
 b.box((0,0,-.060),(L,h,.07),'#103826') # PCB
 b.box((0,-.018,.007),(L*.98,h*.93,.11),shade)
 b.box((0,h*.41,.03),(L*.91,.035,.17),accent)
 b.box((0,-h*.45,.04),(L*.97,.025,.19),'#616a72')
 b.box((0,-h*.54,-.02),(L*.53,.04,.035),'#d4a854') # gold pci contacts
 b.box((-L/2-.02,0,-.02),(.06,h*1.12,.27),'#b7bec2')
 for q in range(5):b.box((-L/2-.052,-h*.35+q*.065,.13),(.007,.037,.022),'#384552')
 num = 1 if mm<180 else (3 if mm>=290 else 2)
 rr=min(h*.37,L/num*.35)
 for i in range(num):
  x=(-L*.47)+(i+.5)*(L*.94)/num
  b.fan((x,-.012,.094),rr,'#323841',accent,blades=9)
  for k in range(7):
   b.box((x, -.13+k*.038,-.115),(.18,.012,.018),'#99a3a8')
 for i in range(14):
  x=-L*.42+i*L*.84/13
  b.box((x,-.14,-.13),(.008,.21,.014),'#a6aeb0')
 b.text_plate(name.replace('NVIDIA ','').replace('AMD Radeon ',''),brand+' · '+str(d.get('vram_gb',0))+' GB', (0,h*.42,.126),(L*.68,.09),shade,'#eeeeee',brand,accent)
 return b

def mobo(d):
 b=Build();brand=d['brand'];accent,shade=PALETTES.get(brand,('#ed2456','#222832'))
 b.box((0,0,-.045),(1.05,1.35,.08),'#1c2226')
 # tiny circuit traces with copper
 rng=random.Random(sum(ord(x) for x in d['name']))
 for _ in range(85):
  x=rng.uniform(-.46,.45);y=rng.uniform(-.59,.58)
  b.box((x,y,-.002),(rng.uniform(.04,.12),.006,.003),'#b79b55' if _%3==0 else '#405964')
 # socket CPU left upper
 b.box((-.20,.24,.028),(.30,.30,.05),'#a5aeb3')
 b.box((-.20,.24,.057),(.235,.23,.015),'#515a61')
 b.box((-.20,.24,.070),(.18,.16,.008),'#c2c9c8')
 # memory slots right vertical
 for i in range(4):
  x=.19+i*.078
  b.box((x,.22,.044),(.036,.87,.036),shade)
  for y in [-.22,.67]:b.box((x,y,.045),(.053,.045,.042),'#bec8d3')
 # PCIe and heatsinks
 for j in range(3):
  y=-.42+j*.13
  b.box((-.03,y,.05),(.68,.048,.058),'#29313a')
  b.box((-.05,y,.085),(.51,.008,.009),accent)
 for i in range(2):
  b.box((-.42,.42-i*.10,.06),(.12,.13,.11),'#a6b2c4')
  for j in range(7):b.box((-.46+j*.014,.42-i*.10,.122),(.009,.11,.02),'#7b8593')
 # capacitors connector banks
 for i in range(12):
  x=-.45+(i%4)*.047;y=.01+(i//4)*.047
  b.cylinder((x,y,.046),.015,.045,'#a9b7b8',sections=9)
 for i in range(8):b.box((.43,-.37+i*.08,.045),(.055,.031,.075),'#252932')
 b.box((-.45,.58,.09),(.11,.2,.14),'#9aabb7') # rear io
 b.text_plate(brand, d.get('socket','')+' / '+d.get('ram_type','')+' / '+d.get('form_factor',''),(-.03,-.60,.06),(.7,.14),'#13181d','#f4f3ee',brand,accent)
 return b

def ram(d):
 b=Build();brand=d['brand'];accent,shade=PALETTES.get(brand,('#db2850','#252a31'))
 L=1.1;H=.32
 b.box((0,0,-.018),(L,H,.031),'#1d5b35')
 for i in range(24):
  x=-L*.44+i*(L*.88/23)
  b.box((x,-H*.48,-.007),(.025,.07,.009),'#d1ae55')
 for side in [-1,1]:
  for i in range(8):
   b.box((-.39+i*.11,side*.025,.014),(.066,.15,.018),'#13181d')
 b.box((0,.07,.040),(L*.93,H*.74,.050),shade)
 b.box((0,.165,.041),(L*.81,.028,.060),accent if 'RGB' in d['name'] else '#838c9b')
 b.text_plate(brand, f"{d.get('capacity_gb',0)} GB  ·  {d.get('ram_type','')}",(0,.02,.072),(.83,.16),shade,'#f8f8fc',brand,accent)
 return b

def cpu(d):
 b=Build();brand=d['brand'];accent,shade=PALETTES.get(brand,('#2789c8','#1b222b'))
 b.box((0,0,-.04),(.62,.62,.06),'#216f42')
 for i in range(14):
  for j in range(14):b.box((-.265+i*.040,-.265+j*.040,-.073),(.017,.017,.004),'#c9ae62')
 b.box((0,0,.002),(.50,.50,.052),'#9da9ae')
 b.box((0,0,.030),(.44,.44,.007),'#d2d5d5')
 b.text_plate(text=d['name'].split(' ',1)[-1] if False else d['name'].replace('AMD ','').replace('Intel ',''), sub=brand+' · '+d.get('socket',''),p=(0,0,.037),s=(.405,.28),bg='#959fa6',fg='#172531',brand=brand,accent=accent)
 return b

def psu(d):
 b=Build();brand=d['brand'];accent,shade=PALETTES.get(brand,('#cc2852','#23252b'))
 b.box((0,0,0),(1.0,.65,.85),shade)
 # air grill and fan
 b.ring((0,.01,.438),.29,.26,.02,'#6d7076')
 b.fan((0,.01,.45),.245,'#a9aeb2',accent,blades=7)
 for i in range(5):
  b.box((-.36+i*.18,-.31,.0),(.014,.025,.52),'#a3adb7')
 # power plug, switch
 b.box((-.36,.11,-.438),(.15,.13,.02),'#14191e')
 b.box((-.14,.11,-.438),(.08,.07,.018),'#c52338')
 for i in range(10):b.box((.30,-.20+i*.04,-.433),(.22,.009,.015),'#69747c')
 b.text_plate(brand, f"{d.get('watts',0)} W  /  80+",(0,-.20,.454),(.64,.18),shade,'#eeeeee',brand,accent)
 return b

def case(d):
 b=Build();name=d['name'];brand=d['brand'];accent,shade=PALETTES.get(brand,('#d23b60','#242731'))
 tall = 1.80 if 'mATX' in name else 2.10;w=1.48 if 'mATX' in name else 1.72;depth=1.15
 steel='#27313b';sheet='#151b24';edge=accent
 # rear backplate and base; open front z positive to show internals
 b.box((0,0,-depth*.49),(w,tall,.055),'#333f4b')
 b.box((0,-tall/2+.035,0),(w,.07,depth),steel)
 b.box((0,tall/2-.035,0),(w,.07,depth),steel)
 for x in [-w/2+.035,w/2-.035]:
  for z in [-depth/2+.04, depth/2-.04]: b.box((x,0,z),(.07,tall,.07),steel)
 # front support and panel on right side edge
 b.box((w/2-.032,0,0),(.055,tall,depth),sheet)
 for z in np.linspace(-depth*.43,depth*.43,13):
  b.box((w/2+.004,0,z),(.012,tall*.93,.012),'#75828c')
 # motherboard tray visible
 b.box((-.24,.11,-depth*.42),(.81,tall*.71,.025),'#49545c')
 for i in range(9):b.cylinder((-.53+(i%3)*.28,-.48+(i//3)*.45,-depth*.39),.019,.04,'#d5aa5d',sections=8)
 # PSU shroud with vents
 b.box((0,-tall*.36,-depth*.42),(w*.87,.085,.055),'#1c232c')
 for i in range(12):b.box((-.57+i*.10,-tall*.36+.105,.08),(.04,.009,.24),'#65727c')
 # side door open angle near left, glass is tinted transparency omitted for see-through: frame and seam only
 b.box((-w*.48,.04,depth*.50),(.043,tall*.85,.025),'#697887')
 b.box((0,tall*.45,depth*.50),(w*.89,.025,.024),'#697887')
 b.box((0,-tall*.45,depth*.50),(w*.89,.025,.024),'#697887')
 # RGB front fans on +x side, face +z, visible
 n=3 if 'RGB' in name or 'Mesh' in name or 'ARGB' in name else 2
 for i in range(n):
  y=(-n/2+i+.5)*.41
  b.fan((w*.42,y,depth*.42),.18,'#121924',accent,blades=7)
 # feet
 for x in [-w*.34,w*.34]:
  for z in [-depth*.3,depth*.3]:b.box((x,-tall*.50-.035,z),(.17,.09,.17),'#11151b')
 b.text_plate(brand, 'GABINETE  ·  '+('mATX' if 'mATX' in name else 'ATX'),(0,tall*.48,depth*.50+.018),(.67,.082),shade,'#e7e8e9',brand,accent)
 return b

BUILD={'gpu':gpu,'cpu':cpu,'motherboard':mobo,'ram':ram,'psu':psu,'case':case}
for cat,items in CAT['catalog'].items():
 for d in items:
  path=OUT/(d['id']+'.glb')
  BUILD[cat](d).export(path)
  assert path.read_bytes()[:4]==b'glTF',path
print('GLB de referencia regenerados',len(list(OUT.glob('*.glb'))),'size MB',round(sum(p.stat().st_size for p in OUT.glob('*.glb'))/1e6,2))
