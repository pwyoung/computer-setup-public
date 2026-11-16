#!/usr/bin/env bash

OS="$(uname -s)"

# Header
printf "%-15s | %-12s | %-35s | %-10s | %s\n" "INTERFACE" "STATE" "HARDWARE / MODEL" "SPEED" "IP ADDRESS"
printf '%s\n' "----------------+--------------+-------------------------------------+------------+--------------------"

if [ "$OS" = "Linux" ]; then
  # ==========================================
  # LINUX IMPLEMENTATION
  # ==========================================
  for iface in /sys/class/net/*; do
    i=$(basename "$iface")
    
    state=$(cat "$iface/operstate" 2>/dev/null)
    carrier=$(cat "$iface/carrier" 2>/dev/null)
    ip_addr=$(ip -4 -br a show "$i" 2>/dev/null | awk '{print $3}')
    
    is_up=false
    if [ "$state" = "up" ]; then
      is_up=true
    elif [ -n "$ip_addr" ] || [ "$i" = "lo" ] || [ "$carrier" = "1" ]; then
      is_up=true
      if [ "$state" != "up" ]; then
        state="up*"
      fi
    fi

    # Human-readable speed formatting
    speed_val=$(cat "$iface/speed" 2>/dev/null)
    if [ -z "$speed_val" ] || [ "$speed_val" -lt 0 ]; then
      spd="N/A"
    elif [ "$speed_val" -ge 1000 ]; then
      gbps=$(( speed_val / 1000 ))
      spd="${gbps}Gbps"
    else
      spd="${speed_val}Mbps"
    fi
    
    # Pull hardware model from PCI bus info
    if [ -d "$iface/device" ]; then
      pci_slot=$(basename "$(readlink -f "$iface/device" 2>/dev/null)")
      model=$(lspci -s "$pci_slot" 2>/dev/null | sed 's/.*: //')
    else
      model="Virtual / System Interface"
    fi
    
    if [ "$is_up" = true ]; then
      color="\033[32m"
    else
      color="\033[90m"
    fi
    reset="\033[0m"
    
    printf "${color}%-15s | %-12s | %-35s | %-10s | %s${reset}\n" \
      "$i" "$state" "${model:0:35}" "$spd" "${ip_addr:-No IP}"
  done

elif [ "$OS" = "Darwin" ]; then
  # ==========================================
  # macOS (DARWIN) IMPLEMENTATION
  # ==========================================
  for i in $(ifconfig -l); do
    ifconfig_out=$(ifconfig "$i")
    is_active=false
    
    if echo "$ifconfig_out" | grep -q "status: active"; then
      is_active=true
      state="up"
    else
      state="down"
    fi
    
    # Extract IPv4 address
    ip_addr=$(ipconfig getifaddr "$i" 2>/dev/null)
    if [ -z "$ip_addr" ]; then
      ip_addr=$(echo "$ifconfig_out" | awk '/inet / {print $2}' | head -n 1)
    fi
    
    # Consider loopback or interfaces with IPs as up
    if [ "$i" = "lo0" ] || [ -n "$ip_addr" ]; then
      is_active=true
      if [ "$state" != "up" ]; then
        state="up*"
      fi
    fi
    
    model="Virtual / Apple Interface"
    spd="N/A"

    if [ "$is_active" = true ]; then
      color="\033[32m"
    else
      color="\033[90m"
    fi
    reset="\033[0m"
    
    printf "${color}%-15s | %-12s | %-35s | %-10s | %s${reset}\n" \
      "$i" "$state" "${model:0:35}" "$spd" "${ip_addr:-No IP}"
  done

else
  echo "Unsupported Operating System: $OS"
  exit 1
fi