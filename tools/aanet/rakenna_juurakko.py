"""Juurakkoisku (assets/sounds/bike_root_*.ogg): synteettinen renkaan tömähdys (laskeva 95→50 Hz:n sini ja
alipäästetty kohinarasahdus) ja 20 ms myöhemmin saman vanhan pyörän kolahdus (oldbike.wav, ks. rakenna_pyora_hengitys.py).
Ajo: python3 -I tools/aanet/rakenna_juurakko.py <työkansio>"""
import numpy as np, subprocess, sys
S=sys.argv[1]; SR=44100; O=S+"/aanet_ulos"
import os; os.makedirs(O, exist_ok=True)
x=np.frombuffer(subprocess.run(["ffmpeg","-v","error","-i",S+"/lataus_aanet/oldbike.wav","-af","highpass=f=60","-ac","1","-ar",str(SR),"-f","s16le","-"],capture_output=True).stdout,np.int16).astype(np.float32)/32768
def save(y,n):
    y=y*(10**(-2/20)/np.abs(y).max())
    subprocess.run(["ffmpeg","-v","error","-y","-f","s16le","-ar",str(SR),"-ac","1","-i","-","-c:a","libvorbis","-q:a","5",O+"/"+n],input=(y*32767).astype(np.int16).tobytes(),check=True)
def thump(seed,f0=95,f1=50,tau=0.032,dur=0.25):
    rng=np.random.default_rng(seed); n=int(dur*SR); t=np.arange(n)/SR
    f=f1+(f0-f1)*np.exp(-t/0.04); ph=2*np.pi*np.cumsum(f)/SR
    env=np.minimum(t/0.003,1)*np.exp(-t/tau)
    body=np.sin(ph)*env
    nz=rng.uniform(-1,1,n); lp=np.zeros(n); a=0.08
    for i in range(1,n): lp[i]=lp[i-1]+a*(nz[i]-lp[i-1])
    crack=lp*np.minimum(t/0.001,1)*np.exp(-t/0.018)*3.0
    return (body*0.7+crack*1.0).astype(np.float32)
for k,(tc,seed,f0) in enumerate([(0.73,1,100),(1.87,2,88),(5.46,3,110)]):
    th=thump(seed,f0=f0); c=x[int((tc-0.02)*SR):int((tc+0.40)*SR)].copy()
    c*=np.linspace(1,0,len(c))**1.2
    c=c/np.abs(c).max()*0.85
    out=np.zeros(int(0.5*SR),np.float32); out[:len(th)]+=th[:len(out)]
    d=int(0.02*SR); out[d:d+len(c)]+=c[:len(out)-d]
    out[-int(0.05*SR):]*=np.linspace(1,0,int(0.05*SR))
    save(out,f"bike_root_{k}.ogg")
print("ok")
