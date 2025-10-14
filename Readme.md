
# UFW blocklist

My attempt to make my uncomplicated firewall (ufw) more complicated by adding
automatically updated public blocklists, and what I learned

## Basics about ufw

Uncomplicated Firewall (UFW) is a program for managing a netfilter firewall. 
It can be seen as a more user-friendly frontend to `iptables`. 
`iptables` allows to set up a chain of rules (rule chains) that basically determine what happens with inbound, outbound or forwarded packets. Packets jump through a sequence of considered rules until reaching build-in targets of ACCEPT, DROP, QUEUE, RETURN or LOG. More details: https://wiki.archlinux.org/title/Iptables

UFW manages its own rule chains. It processes inbound traffic (INPUT) like this
```
INPUT
 └─ ufw-before-input     ← from before.rules
 └─ ufw-user-input       ← your ufw allow/deny rules
 └─ ufw-after-input      ← from after.rules
```
anything dropped in one stage of the chain cannot be allowed again in a later stage, ie. anything dropped in `ufw-before-input` will not be able to be allowed again after. For outbound and forward traffic there are also rule chains like that (e.g. `ufw-before-output` > `ufw-user-output` > `ufw-after-output`)

Entries can be added to these chains in the `before.rules` and `after.rules` files in `/etc/ufw`

In addition there are `before.init` and `after.init`. These are user-defined shell scripts that ufw will call before/after having created its own rules. `*.rules` are declarative, `*.init` imperative.
```
before.init   ← runs first, before UFW loads its rules
after.init    ← runs last, after all rules are applied
```

## Setting up a blocklist

The idea is to create a custom `BLOCKLIST` rule chain, that contains a single rule that will `DENY` all packets whose IP is on a `blocklist` `ipset`.
An `ipset` is basically a hash-set that `iptables` uses for O(1) lookups to determine whether a given IP matches a set of IPs.
Ipsets can be created via `ipset create` and entries can be added via `ipset add`.

A shell script populates this ipset from IPs listed in a given input file and then creates a rule chain `BLOCKLIST` that has just a single rule
```
-A BLOCKLIST -m set --match-set blocklist src -j DROP
```
ie. any paket that reaches `BLOCKLIST` will be dropped if it is in the `blocklist` ipset.

Now we just need to make sure that any inbound/outbound/forwarded paket reaches the `BLOCKLIST` chain, ideally as early as possible, such that there is no `ACCEPT` rule before that could potentially circumvent the blocklist.

One way is to add the following rule right at the start of the `ufw-before-input` chain.
```
iptables -I ufw-before-input <pos> -j BLOCKLIST
```
where `pos` is the position of the rule in the chain `ufw-before-input` (0 or after the loopback rules).
When this rule is invoked, it will jump to the custom `BLOCKLIST` chain.

Any paket not in `blocklist` will go through the rest of `ufw-before-input` (all positions after `<pos>`) and ultimately `user-input` (and thereby any rules configured via `ufw` by the user) and `after-input`.

UFW rebuilds the rule chains when it gets enables `ufw enable`, at every system boot (if the systemd service is enabled, `systemd enable ufw`) or when `ufw reload` is invoked (and potentially at other times).
Each time we need to make sure that our custom rule is wired into the `ufw-before-input` chain.

One way is to utilize `after.init` for exactly this purpose.
In this way ufw builds its own chain first and then invokes `after.init start`. Here we can build our `blocklist` ipset from a file (`/etc/ufw/blocklist.txt`) and create the `BLOCKLIST` chain and insert it at the top of `ufw-before-input`.

Now the only thing left to do is to populate the blocklist file `/etc/ufw/blocklist.txt` from good, up-to-date public sources (see section blocklist sources used for some examples).
For this purpose I use a `systemd` service that executes a shell script that 
- pulls from multiple possible sources
- deduplicates, cleans these sources
- removes entries from the blocklist that are in a whitelist file `/etc/ufw/blocklist-allow.txt`
- only applies the blocklist if it has actually changed (sha256 check)
- is triggered daily by a systemd.timer (configure other time intervals as you like)

## Requirements/Dependencies

basic shell utils (bash, grep, awk, sed, ...) and curl (highly likely already installed)
- `sudo pacman -S base` (on arch)

ufw installed and enabled with
- `sudo pacman -S ufw` (on arch)
- `ufw enable`
- `/etc/ufw/ufw.conf` should contain `enabled=yes`
- `sudo systemctl enable --now ufw.service` (ufw starts automatically)

iptables, ipset
- `sudo pacman -S iptables ipset` (on arch)

## Installation

`sudo sh install-blocklist.sh`: 
    - copies `update-blocklist-sources.sh` to `/usr/local/sbin`, sets correct permissions
    - copy `after.init` to `/etc/ufw/after.init`, set correct permissions
    - calls `update-blocklist-sources.sh` once to pull the blocklists 
    - cleaned up concatenation of all blocklists will be stored to `/etc/ufw/blocklist.txt`
    - reload ufw once to add the jump-to-BLOCKLIST rule to ufw-before-input (`after.init start`)

Expected output
```
Status: active
<..> 
Default: <user configured ufw defaults>
<...>
Chain ufw-before-input (1 references)
num   pkts bytes target     prot opt in     out     source               destination         
1    41827 2593K ACCEPT     all  --  lo     any     anywhere             anywhere            
2        1   417 BLOCKLIST  all  --  any    any     anywhere             anywhere            // this line should be early, after lo entry
<...>         
Chain ufw-before-output (1 references)
num   pkts bytes target     prot opt in     out     source               destination         
1    58843 3661K ACCEPT     all  --  any    lo      anywhere             anywhere            
2      211 23498 BLOCKLIST  all  --  any    any     anywhere             anywhere       // this line should be early, after lo entry     
<...>
Chain ufw-before-forward (1 references)
num   pkts bytes target     prot opt in     out     source               destination         
1        0     0 BLOCKLIST  all  --  any    any     anywhere             anywhere         // should be first line, since ufw-before-forward has no lo entry   
2        0     0 ACCEPT     all  --  any    any     anywhere             anywhere             ctstate RELATED,ESTABLISHED
<...>
-N BLOCKLIST
-A BLOCKLIST -m set --match-set blocklist src -j DROP 
-A BLOCKLIST -m set --match-set blocklist dst -j DROP // BLOCKLIST chain consists of 3 rules -N and -A with --match-set blocklist src, dst and DROP
Name: blocklist
Type: hash:net
Revision: 7
Header: family inet hashsize 4096 maxelem 65536 bucketsize 12 initval 0xba4c78fa
Size in memory: <some size>
References: 1
Number of entries: <number of entries> // the blocklist ipset should have entries
Members:
<some ips>
...
```

`sudo sh install-updater.sh`: copies `ufw-blocklist-update.*` (serivice + timer) to `/etc/systemd/system`, calls `update-blocklist-sources.sh` daily

Inspect logs via `sudo journalctl -b 0 | grep -E "ufw-after.init|ufw-blocklist-update"`

## Blocklist sources used

- IPSum https://github.com/stamparm/ipsum
    - a threat intelligence feed based on 30+ different publicly available lists of suspicious and/or malicious IP addresses
    - regularly updated source: https://raw.githubusercontent.com/stamparm/ipsum/master/levels/4.txt

- FireHOL IPsets https://iplists.firehol.org/
    - aggregator of many sets 
    - regularly updated source: https://raw.githubusercontent.com/ktsaou/blocklist-ipsets/master/firehol_level1.netset
    - firehol_level1
        - fullbogons (ips that should not be routable, eg. private, reserved, no assigned entity)
        - spamhaus drop (see below)
        - dshield (see below)
        - malware lists

- SpamHaus Drop List https://www.spamhaus.org/blocklists/do-not-route-or-peer/
    - netblocks hijacked/leased by criminal ops. Small, very low false positives. Good to block on ingress & egress
    - Updates daily
    - regularly updated source: https://www.spamhaus.org/drop/drop.txt

- abuse.ch Feodo Tracker https://feodotracker.abuse.ch/blocklist/
    - List of BotNet IPs
    - active C2s for Dridex/Emotet/QakBot/TrickBot/Bazar. Lower volume, curated to keep FP low
    - updates every few minutes

- dshield SANS
    - Top 20 attacking class C (/24) subnets
    - https://www.dshield.org/block.txt
    
    
## Gotchas

- fullbogons list from FireHOL includes RFC1918 and other non-routable ranges (10/8, 172.16/12, 192.168/16, 169.254/16, ...)
- such rules are fine on an edge router, but it can nuke LAN/router DNS/printers, ...
- if that happens, you may encounter problems connecting to websites or services
- useful: `sudo ipset test blocklist <non-working-url>`, if thats in your blocklist, add it to blocklist-allow.txt and reinstall `sudo sh install-blocklist.sh`
- `ip route | awk '/^default/ {print $3; exit}'` default gateway (router) should not be on blocklist
