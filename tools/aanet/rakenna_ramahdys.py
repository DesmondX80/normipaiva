"""Juurakkoon osuminen huonosti kasassa olevalla pyörällä (assets/sounds/bike_root_*.ogg): iso rämähdys.
Osat: (1) etupyörä juureen: synteettinen tömähdys + vanhan pyörän iso kolahdus, (2) irralliset osat kolisevat:
10–14 lyhyttä kolahdusta saman pyörän äänitteestä vaimeten 0,4 s, (3) pomppu ja lasku 0,18–0,26 s kohdalla: toinen
tömähdys ja kolahdus, (4) kello helähtää hiljaa (bike_bell.ogg, CC0). Lähteet: oldbike.wav (CC BY-SA 4.0).
Ajo: python3 -I tools/aanet/rakenna_ramahdys.py <työkansio> <pelin kansio>
"""
import numpy as np, subprocess, sys, os
S=sys.argv[1]; G=sys.argv[2]; SR=44100; O=S+"/aanet_ulos"; os.makedirs(O,exist_ok=True)
def load(p,af="highpass=f=60"):
    return np.frombuffer(subprocess.run(["ffmpeg","-v","error","-i",p,"-af",af,"-ac","1","-ar",str(SR),"-f","s16le","-"],capture_output=True).stdout,np.int16).astype(np.float32)/32768
bike=load(S+"/lataus_aanet/oldbike.wav"); bell=load(G+"/assets/sounds/bike_bell.ogg","anull")
HITS=[0.73,1.87,5.46,7.34,9.18,10.98,12.65,15.10,22.90,28.13]  # isoimmat kolahdukset ajosta (rakenna-skriptin haku)
def resample(x,r):
    n=int(len(x)/r); return np.interp(np.arange(n)*r,np.arange(len(x)),x).astype(np.float32)
def slice_hit(t,dur,decay):
    c=bike[int((t-0.004)*SR):int((t+dur)*SR)].copy(); tt=np.arange(len(c))/SR
    c*=np.exp(-tt/decay); c[:int(0.002*SR)]*=np.linspace(0,1,int(0.002*SR))
    return c/(np.abs(c).max()+1e-9)
def thump(rng,f0,tau,amp):
    n=int(0.25*SR); t=np.arange(n)/SR; f=50+(f0-50)*np.exp(-t/0.04)
    body=np.sin(2*np.pi*np.cumsum(f)/SR)*np.minimum(t/0.003,1)*np.exp(-t/tau)
    nz=rng.uniform(-1,1,n); lp=np.zeros(n)
    for i in range(1,n): lp[i]=lp[i-1]+0.08*(nz[i]-lp[i-1])
    return ((body*0.75+lp*3.0*np.minimum(t/0.001,1)*np.exp(-t/0.02))*amp).astype(np.float32)
def add(out,x,t,g):
    i=int(t*SR); 
    if i>=len(out): return
    out[i:i+len(x)]+=x[:len(out)-i]*g
def build(seed):
    rng=np.random.default_rng(seed); out=np.zeros(int(0.95*SR),np.float32)
    # 1) etupyörä juureen
    add(out,thump(rng,rng.uniform(95,115),0.035,1.0),0.0,1.0)
    add(out,slice_hit(HITS[rng.integers(0,3)],0.30,0.12),0.012,0.95)
    # 2) irralliset osat kolisevat
    t=0.03; n=rng.integers(13,19)
    for k in range(n):
        h=slice_hit(HITS[rng.integers(len(HITS))],0.07,rng.uniform(0.015,0.035))
        h=resample(h,rng.uniform(0.85,1.25))
        add(out,h,t,1.05*np.exp(-t/0.32)*rng.uniform(0.6,1.0))
        t+=rng.exponential(0.028)+0.012
    # 3) pomppu ja lasku
    tl=rng.uniform(0.18,0.26)
    add(out,thump(rng,rng.uniform(80,95),0.03,0.65),tl,1.0)
    add(out,slice_hit(HITS[rng.integers(3,len(HITS))],0.25,0.08),tl+0.01,0.7)
    t=tl+0.03
    for k in range(rng.integers(4,7)):
        h=resample(slice_hit(HITS[rng.integers(len(HITS))],0.06,0.02),rng.uniform(0.9,1.3))
        add(out,h,t,0.65*np.exp(-(t-tl)/0.18)); t+=rng.exponential(0.03)+0.015
    # 4) kello helähtää tärähdyksestä
    b=bell[:int(0.9*SR)]*np.exp(-np.arange(int(0.9*SR))/SR/0.35)
    add(out,resample(b,rng.uniform(0.97,1.05)),rng.uniform(0.01,0.05),0.10/(np.abs(b).max()+1e-9))
    out[-int(0.08*SR):]*=np.linspace(1,0,int(0.08*SR))
    lim=10**(-1/20); out=out/np.abs(out).max()*1.3; out=lim*np.tanh(out/lim)  # kova mutta ei leikkaa
    return out
for k in range(4):
    y=build(11+k)
    subprocess.run(["ffmpeg","-v","error","-y","-f","s16le","-ar",str(SR),"-ac","1","-i","-","-c:a","libvorbis","-q:a","5",O+f"/bike_root_{k}.ogg"],input=(y*32767).astype(np.int16).tobytes(),check=True)
    print(k,"rms %.1f dB" % (20*np.log10(np.sqrt(np.mean(y**2)))))
