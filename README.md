# Proxmox ip2tag

This script automatically assigns tags containing IP addresses to virtual machines and containers running
in a Proxmox environment. It is an alternative to lxc-iptags but is more extensive and flexible in many ways.

![](./img/prox-ip2tag-p1.png)

### Key Features:  

- Support for containers (LXCs), virtual machines (VMs), or both  
- Independent user-defined colors for active and inactive IP tags  
- Control over tag placement (beginning or end)  
- Automatic sorting of IP tags for running and stopped guests  
- Custom actions for inactive IP tags (change color, remove, or none)  
- Definition of IP addresses and network ranges to tag  
- Ignore lists for IPs, network ranges, and VM/LXC IDs  
- Configurable interval for checking and updating IP tags  
- Run as a systemd service or standalone script  
- Built-in config validation on startup to prevent runtime errors  
- Faster retrieval of selected settings compared to pvesh, qm, and lxc  

## Installation and upgrade

To install or upgrade to the latest stable release, run as root:

```sh
INSTALL_SOURCE=github bash -c "$(curl -sSL https://github.com/MorsStefan/proxmox-ip2tag/releases/latest/download/prox-ip2tag_install.sh)"
```

The script will automatically download all necessary files and perform a installation.  

If a previous version of the program is detected, it will be replaced **only after confirmation**.  
The original configuration file will remain untouched – the new config will be saved as:  

`/usr/local/etc/prox-ip2tag.conf_new`  

## Manual installation and upgrade

Download the latest stable release, extract it, and run the `prox-ip2tag_install.sh` installer
— the same script used for online installation, supporting both online and offline methods.  

If you prefer full control over every file, follow these steps:

```
# Stopping service before installation or upgrade
systemctl stop prox-ip2tag.service &>/dev/null

# Download files
curl -sSL https://github.com/MorsStefan/proxmox-ip2tag/releases/latest/download/prox-ip2tag -o /usr/local/bin/prox-ip2tag
curl -sSL https://github.com/MorsStefan/proxmox-ip2tag/releases/latest/download/prox-ip2tag.conf -o /usr/local/etc/prox-ip2tag.conf
curl -sSL https://github.com/MorsStefan/proxmox-ip2tag/releases/latest/download/prox-ip2tag.service -o /etc/systemd/system/prox-ip2tag.service

# Enable and run service
systemctl daemon-reload
systemctl enable --now prox-ip2tag.service

# Check status
systemctl status prox-ip2tag.service
```

## Configuration

The configuration file with all available options is located at: `/usr/local/etc/prox-ip2tag.conf`

| Option                    | Default         | Description                                                                |
|---------------------------|-----------------|----------------------------------------------------------------------------|
| `GUEST_TYPE`              | `3`             | Defines which guest types to process: 1 = LXCs, 2 = VMs, 3 = both.         |
| `NETWORK_RANGES`          | `(0.0.0.0/0)`   | IP addresses and network ranges in CIDR format in which IP must be located in order to be automatically added or removed as IP tag. |
| `NETWORK_RANGES_IGNORED`  | `(127.0.0.1)`   | Do not auto add or remove IP tags for VMs and LXCs from this range, and do not change their color. |
| `IGNORED_VMIDS`           | `()`            | Ignore these LXCs and VMs.                                                 |
| `INACTIVE_IP_TAGS_ACTION` | `change_color`  | What to do with IP tags when VM/LXC is stopped: \[ `remove` \| `change_color` \| `none` \]. |
| `CHANGE_IP_TAGS_COLORS`   | `1`             | Allow changing Proxmox default tags colors: \[ 0 \| 1 \]. <sup>(\*1)</sup> |
| `UPDATE_IP_TAGS_INTERVAL` | `60`            | Time in seconds between IP tags updates. Must be > 0. Minimum 60 is recommended. |
| `IP_TAGS_POS`             | `first`         | Controls the placement of newly added IP tags: \[ `first` \| `last` \]. <sup>(\*2)</sup>|
| `FORCE_IP_TAGS_POS`       | `1`             | Enforces a fixed position for IP tags according to the value of the `IP_TAGS_POS`. <sup>(\*2)</sup> |
| `TAG_COLOR`               | `ffffff`        | Foreground color for active IPs (hex).                                     |
| `TAG_BGCOLOR`             | `4c4c4c`        | Background color for active IPs (hex).                                     |
| `TAG_INACTIVE_COLOR`      | `ffffff`        | Foreground color for inactive IPs (hex).                                   |
| `TAG_INACTIVE_BGCOLOR`    | `aaaaaa`        | Background color for inactive IPs (hex).                                   |
| `VM_LXC_CONFIG_SOURCE`    | `cfg_files`     | Method for reading tags and selected config options: \[ cfg_files \| qm_pct \]. <sup>(\*3)</sup> |
| `VM_LXC_LIST_METHOD`      | `custom`        | Method for creating list of running VMs and LXCs: \[ custom \| qm_pct \].  |
| `CLUSTER_CONFIG_SOURCE`   | `cfg_files`     | Method for reading cluster config options: \[ cfg_files \| pvesh \].  <sup>(\*3)</sup> |
| `DISPLAY_TIMESTAMP`       | `0`             | Prefixes each output line with a timestamp - useful for terminal logging.  |
| `VERBOSE`                 | `3`             | Verbosity level of log messages: \[ 0 \| 1 \| 2 \| 3 \| 4 \| 5 \| 6 \].    |


\*1 - When `CHANGE_IP_TAGS_COLORS`=`0`, it overwrites `INACTIVE_IP_TAGS_ACTION=change_color` and  
      `INACTIVE_IP_TAGS_ACTION=change_none`.  
\*2 - Require cluster setting: `Datacenter->Options->Tag Style Override->Ordering='Configuration'`  
\*3 - The `cfg_files` option is very fast because it reads local configuration files; otherwise, the default Proxmox tools  
      are used.

## Usage

By default, the program runs in an infinite loop, continuously monitoring IP addresses and their associated tags.   
However, it can be launched with the `--run-once` option to perform a one-time synchronization and exit afterward.  

### IP Discovery

By default, the script detects all IPv4 addresses (excluding 127.0.0.1) and assigns them as tags to virtual machines and LXC containers.   

To limit the range of detected IP addresses, you can define custom networks using the `NETWORK_RANGES` parameter.
For example, to include only common local networks and a single IP address:

```
NETWORK_RANGES=( 192.168.0.0/16 10.0.0.0/8 194.181.15.20 )
```
IP addresses that should be ignored must be added to the `NETWORK_RANGES_IGNORED` variable.
This list can also include existing IP tags that you don't want to modify. If, for example, docker is
installed in LXCc and we do not want its internal container (docker) addresses are added as tags:   

```
NETWORK_RANGES_IGNORED=( 127.0.0.1 172.17.0.0/16 172.18.0.0/16 )
```

This also works the other way around, if these addresses were already assigned as IP tags to a
LXC/VM, they will not be automatically removed when added to the `NETWORK_RANGES_IGNORED`.   

They will be ignored, just as the variable name suggests.   

Note that `NETWORK_RANGES_IGNORED` has higher priority than `NETWORK_RANGES`!

### Tags order

The order in which IP tags are displayed depends on both the script's configuration and the cluster's global settings.  
To ensure correct IP tag sorting and position enforcement, the parameter:   
`Datacenter -> Options -> Tag Style Override -> Ordering` should be set to `Configuration`.

Please note that IP tags are not automatically sorted in the following cases:   
- The VM/LXC is listed in the `IGNORED_VMIDS`  
- The IP address is listed in the `NETWORK_RANGES_IGNORED`  
- The guest agent is not installed in the virtual machine (VM)  
- Datacenter `Tag Style Override -> Ordering` is not set to `Configuration`  
- `FORCE_IP_TAGS_POS` is set to `0` in `/usr/local/etc/prox-ip2tag.conf`  

### Tags colors

By default, when a virtual machine associated with an IP tag is shut down,
the color of the IP tag is updated to indicate its inactive state.   

If the same IP address is assigned to more than one machine — with one running and the other stopped
— the tag color will be determined by the running machine. This behavior results from the fact that tag
color changes are applied globally and cannot differ per machine.

**Important note:**

Tag color changes are not visible immediately. Press `F5` to refresh the view.
This is not a bug, but a limitation/feature of the Proxmox interface.

### Initial Setup Guide

This is not a required step, but it allows for a quick and trouble-free script setup.

1. Stop the service: `systemctl stop prox-ip2tag`
2. In the file `/usr/local/etc/prox-ip2tag.conf`, set `VERBOSE=4` and `UPDATE_IP_TAGS_INTERVAL=5`
3. Set two options in the Proxmox configuration:  
   `Datacenter -> Options -> Tag Style Override -> Ordering` = `Configuration`  
   `Datacenter -> Options -> Tag Style Override -> Tree Shape` = `Full`
4. Run in terminal: `/usr/local/bin/prox-ip2tag` and observe the output

This way, all running virtual machines and containers will receive IP tags.
They will be placed at the beginning of the tag list, making them easier to view and sort -
especially in the `Datacenter -> Search` view.

If available memory is limited on the server, you can start virtual machines one by one,
and shut them down after they get IP tags. Once all machines have tags assigned, you can stop the script (`Ctrl + C`).   

You can now make configuration changes and check the effect by running the script manually again.   
With the above settings, changes should be visible within 60 seconds after launch.

Once the result is satisfactory, you may reduce the `VERBOSE` level, increase `UPDATE_IP_TAGS_INTERVAL`,
and run the script as a systemd service.

## Uninstall

```
# stop and disable prox-ip2tag.service
systemctl stop prox-ip2tag.service
systemctl disable prox-ip2tag.service

# remove prox-ip2tag
rm -fv /etc/systemd/system/prox-ip2tag.service
rm -fv /usr/local/bin/prox-ip2tag
rm -fv /usr/local/etc/prox-ip2tag.conf
```

## Roadmap

- ~~Sort tags for stopped VMs and LXCs~~ [0.7.6]  
- Read IP addresses from stopped LXC containers 
- Use `pvesh get` for alternative configuration reading
- ~~Support ranges and IPs in `ignored_ip_tags_list`~~ [0.8.0]  
- ~~Replace 'ignored_ip_tags_list' with 'NETWORK_RANGES_IGNORED'~~ [0.8.0]  
- ~~Implement a faster method for reading settings than `pvesh`, `qm`, and `lxc`~~ [0.8.0]  
- Add a tool to remove all IP tags from VMs and LXCs
- Add the `--dry-run` option
