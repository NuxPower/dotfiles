#!/bin/bash

if pgrep -x "wf-recorder" > /dev/null; then
    # Stop recording
    pkill -SIGINT wf-recorder
    notify-send "Recording" "Mixed video saved"
    
    # Wait a second for the video file to finalize
    sleep 1 
    
    # Safely unload only the specific modules we created for this recording
    if [ -f /tmp/wf-record-modules ]; then
        while read -r module_id; do
            pactl unload-module "$module_id"
        done < /tmp/wf-record-modules
        rm /tmp/wf-record-modules
    fi
else
    notify-send "Recording" "Started (Desktop + Mic)"
    
    # 1. Create a temporary virtual sink
    SINK_ID=$(pactl load-module module-null-sink sink_name=WfRecordMix sink_properties=device.description="WfRecordMix")
    echo "$SINK_ID" > /tmp/wf-record-modules
    
    # 2. Route desktop audio into the virtual sink
    LOOP1_ID=$(pactl load-module module-loopback source=$(pactl get-default-sink).monitor sink=WfRecordMix)
    echo "$LOOP1_ID" >> /tmp/wf-record-modules
    
    # 3. Route mic audio into the virtual sink
    LOOP2_ID=$(pactl load-module module-loopback source=$(pactl get-default-source) sink=WfRecordMix)
    echo "$LOOP2_ID" >> /tmp/wf-record-modules

    # 4. Start recording the combined virtual sink
    wf-recorder --audio=WfRecordMix.monitor -g "$(slurp)" -f ~/Videos/$(date +'%H-%M-%S_mixed').mp4
fi
