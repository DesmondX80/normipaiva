"""Ajo: python3 -I tools/aanet/korosta_kolina.py <bike_ride.ogg rakenna-skriptistä> assets/sounds/bike_ride.ogg 7

Ajosilmukan kolinan korostus (transient shaper): nopean ja hitaan verhokäyrän ero kertoo iskun; iskujen vahvistus
+boost dB, tasainen osa ennallaan. Lopuksi huippu -1 dB ja RMS ennallaan tai nostettuna."""
import numpy as np, subprocess, sys
src,dst,boost=sys.argv[1],sys.argv[2],float(sys.argv[3]); SR=44100
x=np.frombuffer(subprocess.run(["ffmpeg","-v","error","-i",src,"-ac","1","-ar",str(SR),"-f","s16le","-"],capture_output=True).stdout,np.int16).astype(np.float32)/32768
def follow(a,att,rel):
    ea=np.exp(-1/(att*SR)); er=np.exp(-1/(rel*SR)); y=np.zeros_like(a); v=0.0
    for i,s in enumerate(a):
        c=ea if s>v else er; v=c*v+(1-c)*s; y[i]=v
    return y
ab=np.abs(x)
fast=follow(ab,0.0005,0.02); slow=follow(ab,0.02,0.12)
g=np.clip(fast/(slow+1e-6),1.0,4.0)  # >1 iskun kohdalla
gain=1+(10**(boost/20)-1)*(g-1)/3.0
y=x*gain
# silmukan sauma: alku ja loppu samasta äänitteestä, vahvistus jatkuu; tasoitus 5 ms reunoilla ei tarpeen
# keskitaso alkuperäinen +2 dB, huiput pehmeästi rajattuna (tanh) -1 dB:n alle
y*=np.sqrt(np.mean(x**2))*10**(2/20)/np.sqrt(np.mean(y**2))
lim=10**(-1/20); y=lim*np.tanh(y/lim)
print("rms ennen %.1f jälkeen %.1f dB" % (20*np.log10(np.sqrt(np.mean(x**2))),20*np.log10(np.sqrt(np.mean(y**2)))))
subprocess.run(["ffmpeg","-v","error","-y","-f","s16le","-ar",str(SR),"-ac","1","-i","-","-c:a","libvorbis","-q:a","5",dst],input=(np.clip(y,-1,1)*32767).astype(np.int16).tobytes(),check=True)
