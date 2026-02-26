#!/usr/bin/env bash

INTERVAL=0.08
HUE=260   # base violet/bleu
ANGLE=0

hsv_to_hex() {
python3 - <<EOF
import colorsys
h=$1/360
s=0.35
v=0.85
r,g,b=colorsys.hsv_to_rgb(h,s,v)
print("0xff%02x%02x%02x"%(int(r*255),int(g*255),int(b*255)))
EOF
}

while true; do
    COLORS=()

    for i in {0..9}; do
        hue=$(( (HUE + i*4) % 360 ))
        COLORS+=("$(hsv_to_hex $hue)")
    done

    hyprctl keyword general:col.active_border "${COLORS[@]}" "${ANGLE}deg"

    HUE=$(( (HUE + 1) % 360 ))
    ANGLE=$(( (ANGLE + 0) % 360 ))  # angle fixe = look stable

    sleep "$INTERVAL"
done