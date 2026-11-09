#!/usr/bin/env python3
"""타일 경계가 이어지는 사암 색상·높이(RGBA)를 절차적으로 생성합니다."""
from pathlib import Path
import numpy as np
from PIL import Image
N=1024
rng=np.random.default_rng(59206)
def noise(size):
    a=rng.random((size,size)).astype(np.float32)
    q=np.arange(N)*size/N
    k=q.astype(int);t=q-k;t=t*t*(3-2*t)
    v=a[k[:,None]%size,k[None,:]%size]*(1-t[None,:])+a[k[:,None]%size,(k[None,:]+1)%size]*t[None,:]
    w=a[(k[:,None]+1)%size,k[None,:]%size]*(1-t[None,:])+a[(k[:,None]+1)%size,(k[None,:]+1)%size]*t[None,:]
    return v*(1-t[:,None])+w*t[:,None]
y,x=np.mgrid[:N,:N]/N
broad=noise(4);medium=noise(16);fine=noise(64);grain=noise(256)
warp=np.sin(x*2*np.pi)*.08+np.sin(x*6*np.pi)*.025
strata=np.sin((y+warp)*np.pi*32)*.5+.5
height=.4*broad+.22*medium+.15*fine+.08*grain+.15*strata
color=np.array([155,99,65])[None,None,:]*(.84+.14*broad+.10*medium+.12*fine+.04*grain)[...,None]
color+=((strata-.5)*7)[...,None]*np.array([1,.8,.5])
rgba=np.concatenate([np.clip(color,0,255).astype(np.uint8),np.clip(height[...,None]*255,0,255).astype(np.uint8)],axis=2)
Image.fromarray(rgba).save(Path(__file__).resolve().parents[1]/'assets/environment/sandstone-detail.png')
