#!/bin/bash

set -ex

[[ -z "$1" ]] && echo "$0 <TEMPLATE>" && exit 1
template="$1"

ssh dellr740f 'ip netns del server || true'
gen_vm_config.sh --host0 dellr740e --soc0 dellr740e-soc --host1 dellr740f --soc1 dellr740f-soc

./dellr740f.sh $template > dellr740f_setup.sh
./dellr740e.sh $template > dellr740e_setup.sh

chmod +x dellr740f_setup.sh
chmod +x dellr740e_setup.sh

for h in dellr740f dellr740e
do
    scp ${h}_setup.sh ${h}:/root/
    scp ${h}_setup.sh ${h}-soc:/root/

    ssh ${h} "/root/${h}_setup.sh"
    ssh ${h}-soc "/root/${h}_setup.sh"
done



exit 0
