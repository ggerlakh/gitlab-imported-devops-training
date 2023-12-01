#!/bin/bash
if [[ $(curl -s -i http://localhost:33227/ping | head -1 | awk -F' ' '{print $2}') == '500' ]]; then /bin/systemctl restart bingo; fi
