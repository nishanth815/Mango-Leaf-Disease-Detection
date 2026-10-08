import sys, numpy as np, cv2
sys.path.insert(0,'/home/claude/src/repo/ai_backend/scripts')
import importlib.util
# import only the pure functions without loading models: exec the needed defs
src=open('/home/claude/src/repo/ai_backend/scripts/predict.py').read()
start=src.index('def check_image_quality'); end=src.index('# LEAF / NON-LEAF CHECK')
ns={'cv2':cv2,'np':np}; exec(src[start:end].rsplit('# ====',1)[0],ns)
s2=src.index('def estimate_severity'); e2=src.index('# COMPLETE PREDICTION PIPELINE')
ns['IMG_SIZE']=(224,224); exec(src[s2:e2].rsplit('# ====',1)[0],ns)

# --- literal port of the Dart code ---
def rgb2hsv(r,g,b):
    r=r.astype(float);g=g.astype(float);b=b.astype(float)
    mx=np.maximum(np.maximum(r,g),b); mn=np.minimum(np.minimum(r,g),b); d=mx-mn
    s=np.where(mx==0,0,np.floor(255*d/np.where(mx==0,1,mx)+.5))
    dd=np.where(d==0,1,d)
    h=np.where(mx==r,60*(g-b)/dd,np.where(mx==g,120+60*(b-r)/dd,240+60*(r-g)/dd)); h=np.where(d==0,0,h); h=np.where(h<0,h+360,h)
    return np.floor(h/2+.5)%180, s, mx
def morph(a,erode):
    from scipy.ndimage import minimum_filter,maximum_filter
    return (minimum_filter if erode else maximum_filter)(a,size=5,mode='nearest')  # clipped window == nearest for min/max
def dart_sev(bgr):
    im=cv2.resize(bgr,(224,224)); r,g,b=im[...,2],im[...,1],im[...,0]
    h,s,v=rgb2hsv(r,g,b)
    leaf=((h>=20)&(h<=100)&(s>=25)&(v>=20)&(v<=245)).astype(np.uint8)*255
    les=((h>=5)&(h<=30)&(s>=40)&(v>=20)&(v<=180)).astype(np.uint8)*255
    lm=morph(morph(leaf,True),False); lm=morph(morph(lm,False),True)
    les=np.where((les!=0)&(lm!=0),255,0).astype(np.uint8); lm2=morph(morph(les,True),False)
    la=(lm!=0).sum(); le=(lm2!=0).sum()
    return 0 if la==0 else min(le/la*100,100)
def dart_lapvar(gray):
    return cv2.Laplacian(gray,cv2.CV_64F,borderType=cv2.BORDER_REFLECT_101).var()
def pad101(a): return np.pad(a,1,mode='reflect')
def dart_lap(gray):
    p=pad101(gray.astype(float)); l=p[:-2,1:-1]+p[2:,1:-1]+p[1:-1,:-2]+p[1:-1,2:]-4*p[1:-1,1:-1]
    return l.var()

rng=np.random.default_rng(0)
bad=0
for t in range(30):
    # synthetic leaf: green base, brown/yellow blotches, noise
    im=np.zeros((300,400,3),np.uint8); im[:]=(40,rng.integers(100,170),rng.integers(30,80))
    for _ in range(rng.integers(0,8)):
        x,y=rng.integers(0,350),rng.integers(0,250); w,h=rng.integers(10,60,2)
        col=(int(rng.integers(20,60)),int(rng.integers(90,150)),int(rng.integers(120,200)))
        cv2.ellipse(im,(x,y),(w,h),0,0,360,col,-1)
    im=np.clip(im+rng.normal(0,8,im.shape),0,255).astype(np.uint8)
    ref=ns['estimate_severity'](im)[0]; mine=dart_sev(im)
    gray=cv2.cvtColor(im,cv2.COLOR_BGR2GRAY)
    lv_ref=cv2.Laplacian(gray,cv2.CV_64F).var(); lv=dart_lap(gray)
    ok=abs(ref-mine)<0.5 and abs(lv_ref-lv)<1e-6*max(1,lv_ref)
    bad+=not ok
    if not ok or t<4: print(t,round(ref,3),round(mine,3),round(lv_ref,2),round(lv,2),ok)
print("mismatches:",bad)
