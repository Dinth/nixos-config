#!/run/current-system/sw/bin/bash
#
# ZYV
#
# This horrible script adds and removes iptables rules to allow for port
# forwarding from the host machine (virtualization server) to the selected
# virtualized guests.
#
# Unfortunately, libvirt inserts its own FORWARD rules along with final REJECTs
# at the very top of the table, so the rules defined via iptables config will
# be rendered ineffective, hence the need for this hook.
#

set -e
set -u

iptables='/run/current-system/sw/sbin/iptables'

# Ideally, rewrite as ERB template and fetch this from Puppet
external_ifs='enp5s0 virbr0'
external_ip='10.10.10.10'

# List the machines here
machines=( 'linuxmint' )

# Machine definition block
linuxmint_hostname='LinuxMint'
linuxmint_ip='192.168.122.50'
linuxmint_sport=( '8095' '8095' )
linuxmint_dport=( '8095' '8095' )
linuxmint_protocol=( 'tcp' 'udp' )

rules_update() {

    domain="$1"
    action="$2"

    for host in ${machines[@]}; do

        eval host_name="\$${host}_hostname"

        if [ "$domain" == "${host_name}" ]; then

            eval host_ip="\$${host}_ip"

            eval host_sport=( \${${host}_sport[@]} )
            eval host_dport=( \${${host}_dport[@]} )
            eval host_protocol=( \${${host}_protocol[@]} )

            length=$(( ${#host_sport[@]} - 1 ))

            for i in `seq 0 $length`; do

                protocol="${host_protocol[$i]}"

                for external_if in ${external_ifs}; do

                    PREROUTING="$iptables -t nat $action PREROUTING -d ${external_ip} -i ${external_if} -p ${protocol} -m ${protocol} --dport ${host_sport[$i]} -j DNAT --to-destination ${host_ip}:${host_dport[$i]}"

                    if [ -z "${DEBUG_RULES:-}" ]; then
                        `$PREROUTING`
                    else
                        echo $PREROUTING
                    fi

                done

                FORWARD="$iptables $action FORWARD -d ${host_ip} -p ${protocol} -m state --state NEW -m ${protocol} --dport ${host_dport[$i]} -j ACCEPT"

                if [ -z "${DEBUG_RULES:-}" ]; then
                    `$FORWARD`
                else
                    echo $FORWARD
                fi

            done

        fi

    done

}

domain_name="$1"
domain_task="$2"

case "${domain_task}" in
    # hook is called with <domain_name> start begin -
    start)
        rules_update ${domain_name} " -I "
    ;;
    # hook is called with <domain_name> stopped end -
    stopped)
        rules_update ${domain_name} " -D "
    ;;
    # libvirtd restart hook, added in libvirt-0.9.13
    reconnect)
        rules_update ${domain_name} " -D "
        rules_update ${domain_name} " -I "
    ;;
    *)
        echo "qemu hook called with unexpected options $*" >&2
    ;;
esac
