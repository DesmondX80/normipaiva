"""Pyörän ajoääni, kolahdukset ja pelaajan hengitys (assets/sounds: bike_ride, bike_clunk_*, breath_*, pant_*).

Ajo: python3 -I tools/aanet/rakenna_pyora_hengitys.py <työkansio>
<työkansio>/lataus_aanet sisältää lähteet (ks. assets/sounds/LICENSE.md):
  oldbike.wav = Wikimedia Commons "Old Bike UglyBIke Onboard Slow Start-ride-stop ... F&T Bicycle.wav" (CC BY-SA 4.0)
  hb2.ogg     = Wikimedia Commons "Heavy breathing 2.ogg" (ezwa, public domain)
  tired.wav   = OpenGameArt "Breathing Tired" (CC0)
Tulokset kirjoitetaan <työkansio>/aanet_ulos; kopioi ne assets/sounds-kansioon. Käsittely: verkkohurinan ja sen
yläsävelten lovet, STFT-spektrivähennys hengenvetojen väleistä mitatulla kohinalla, ylipäästö 150 Hz, häivytykset ja
huipun normalisointi; ajosilmukka ristiinhäivytetään saumasta ja sovitetaan vanhan bike_roll.ogg:n tasoon (huippu -1 dB).
"""
import numpy as np, subprocess, sys, os
S=sys.argv[1]; L=S+"/lataus_aanet"; O=S+"/aanet_ulos"; SR=44100
os.makedirs(O, exist_ok=True)
def load(p, af=None):
    cmd=["ffmpeg","-v","error","-i",p]+(["-af",af] if af else [])+["-ac","1","-ar",str(SR),"-f","s16le","-"]
    return np.frombuffer(subprocess.run(cmd,capture_output=True).stdout,np.int16).astype(np.float32)/32768.0
def save(x,name):
    pcm=(np.clip(x,-1,1)*32767).astype(np.int16).tobytes()
    subprocess.run(["ffmpeg","-v","error","-y","-f","s16le","-ar",str(SR),"-ac","1","-i","-","-c:a","libvorbis","-q:a","5",O+"/"+name],input=pcm,check=True)
def rms(x): return float(np.sqrt(np.mean(x**2)))
def fade(x,fi,fo):
    x=x.copy(); a=int(fi*SR); b=int(fo*SR)
    if a: x[:a]*=np.linspace(0,1,a)**2
    if b: x[-b:]*=np.linspace(1,0,b)**1.5
    return x
def hum_f0(x,lo,hi):
    # perustaajuus, jonka yläsävelten (1..20) teho on suurin (hiljainen kohta ei tarvita: hurina on koko ajan)
    P=np.abs(np.fft.rfft(x*np.hanning(len(x))))**2; f=np.fft.rfftfreq(len(x),1/SR); df=f[1]
    best=(0,lo)
    for f0 in np.arange(lo,hi,0.05):
        s=sum(P[int(round(k*f0/df))] for k in range(1,21))
        if s>best[0]: best=(s,f0)
    return best[1]
def dehum(x,f0,kmax=60,w=2.5):
    X=np.fft.rfft(x); f=np.fft.rfftfreq(len(x),1/SR)
    for k in range(1,kmax+1):
        X[np.abs(f-k*f0)<w]*=0.03
    return np.fft.irfft(X,len(x))
def denoise(x,quiet,over=2.0,floor=0.04,N=2048,H=512):
    # STFT-spektrivähennys: kohinaprofiili hiljaisilta väleiltä [(a,b) s], vahvistus max(1-over*N/|X|, floor), tasoitettu
    win=np.hanning(N); pad=np.concatenate([np.zeros(N),x,np.zeros(N)])
    fr=[pad[i:i+N]*win for i in range(0,len(pad)-N,H)]
    X=np.array([np.fft.rfft(f) for f in fr]); M=np.abs(X)
    q=[k for k in range(len(fr)) if any(a<= (k*H-N)/SR <=b for a,b in quiet)]
    noise=M[q].mean(axis=0)
    G=np.maximum(1-over*noise/(M+1e-9),floor)
    G=np.apply_along_axis(lambda g: np.convolve(g,np.ones(3)/3,'same'),0,G)
    Y=X*G; out=np.zeros(len(pad)); wsum=np.zeros(len(pad))
    for k in range(len(fr)):
        out[k*H:k*H+N]+=np.fft.irfft(Y[k],N)*win; wsum[k*H:k*H+N]+=win**2
    out/=np.maximum(wsum,1e-6)
    return out[N:N+len(x)].astype(np.float32)
def peaknorm(x,db): return x*(10**(db/20)/(np.abs(x).max()+1e-9))
# --- pyörä ---
ref=load(os.path.join(os.path.dirname(os.path.abspath(__file__)),"..","..","assets","sounds","bike_roll.ogg"))
bike=load(L+"/oldbike.wav","highpass=f=60")
t0,T,F=5.0,28.0,1.0
seg=bike[int(t0*SR):int((t0+T+F)*SR)]
n=int(T*SR); f=int(F*SR)
loop=seg[:n].copy(); w=np.linspace(0,1,f)
loop[:f]=seg[:f]*np.sqrt(w)+seg[n:n+f]*np.sqrt(1-w)
loop*=rms(ref)/rms(loop)
g=min(1.0,10**(-1/20)/np.abs(loop).max()); loop*=g; print("ride gain dB", 20*np.log10(g))
save(loop,"bike_ride.ogg")
print("ride rms dB",20*np.log10(rms(loop)),"ref",20*np.log10(rms(ref)),"peak",20*np.log10(np.abs(loop).max()))
# kolahdukset: transientit yli 1,5 kHz:n kaistalla ajo-osuudelta 3–35 s
hp=load(L+"/oldbike.wav","highpass=f=1500")
hop=int(0.005*SR); a0,a1=int(3*SR),int(35*SR)
e=np.sqrt(np.mean(hp[a0:a1-(a1-a0)%hop].reshape(-1,hop)**2,axis=1)); ed=20*np.log10(e+1e-9)
med=np.convolve(ed,np.ones(200)/200,'same')
cand=np.argsort(-(ed-med))
picked=[]
for i in cand:
    if ed[i]-med[i]<10: break
    t=a0/SR+i*0.005
    if all(abs(t-p)>0.6 for p in picked): picked.append(t)
    if len(picked)>=6: break
print("kolahdukset",[(round(p,2)) for p in sorted(picked)])
for k,t in enumerate(sorted(picked)):
    c=bike[int((t-0.03)*SR):int((t+0.32)*SR)]
    c=fade(c,0.005,0.2); c=peaknorm(c,-3)
    save(c,f"bike_clunk_{k}.ogg")
# --- hengitys ---
hb=load(L+"/hb2.ogg")
f0=hum_f0(hb[:SR*20],95,140); print("hb2 hurina",round(f0,2)); hb=dehum(hb,f0)
hb=denoise(hb,[(2.62,4.10),(6.20,7.40),(9.32,10.68)],over=1.6)
hb=np.frombuffer(subprocess.run(["ffmpeg","-v","error","-f","f32le","-ar",str(SR),"-ac","1","-i","-","-af","highpass=f=150,lowpass=f=9000","-f","f32le","-"],input=hb.astype(np.float32).tobytes(),capture_output=True).stdout,np.float32)
cyc=[(0.62,2.62),(4.10,6.20),(7.40,9.32),(10.68,12.84),(17.46,19.44)]
for k,(a,b) in enumerate(cyc):
    c=fade(hb[int(a*SR):int(b*SR)],0.05,0.25); c=peaknorm(c,-3); save(c,f"breath_{k}.ogg")
td=load(L+"/tired.wav")
f0=hum_f0(td,95,140); print("tired hurina",round(f0,2)); td=dehum(td,f0)
td=denoise(td,[(0.72,1.22),(1.92,2.38)])  # vinkuna 3,8 kHz ja huoneen sävyt: kohina hengenvetojen väleistä
td=np.frombuffer(subprocess.run(["ffmpeg","-v","error","-f","f32le","-ar",str(SR),"-ac","1","-i","-","-af","highpass=f=150,lowpass=f=9000","-f","f32le","-"],input=td.astype(np.float32).tobytes(),capture_output=True).stdout,np.float32)
for k,(a,b) in enumerate([(0.08,0.70),(1.26,1.86),(2.42,3.02)]):
    c=fade(td[int(a*SR):int(b*SR)],0.03,0.18); c=peaknorm(c,-3); save(c,f"pant_{k}.ogg")
for name in sorted(os.listdir(O)):
    x=load(O+"/"+name); print(f"  {name:20s} {len(x)/SR:5.2f}s rms {20*np.log10(rms(x)+1e-9):6.1f} peak {20*np.log10(np.abs(x).max()+1e-9):5.1f}")
