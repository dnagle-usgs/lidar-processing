; symbol_circle.pro
 
PRO symbol_circle,_EXTRA=extra
; define a circle symbol, which can be used by plotting with psym=8
; acceptable keywords are color,fill,thick, which are passed thru to usersym
s=!pi*2./15.*findgen(16)
v=cos(s)
u=sin(s)
usersym,u,v,_EXTRA=extra
end
