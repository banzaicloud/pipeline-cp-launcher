#!/bin/bash

echo -n "[concat('#!/bin/bash\\n','echo $(cat scripts/bootstrap_arm.sh | gzip -9 - | /usr/bin/base64 ) | base64 -d | gunzip | ',$(cat scripts/bootstrap_arm_params.sh | awk -F '=' '{print "'\''"$1 "='\'',"$2",'\'' '\'',"}'| tr -d "\n")'bash')]"
