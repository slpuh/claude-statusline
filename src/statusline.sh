#!/usr/bin/env bash
# claude-statusline — minimal, single-file
set -uo pipefail

input=$(cat)
[ -z "$input" ] && { echo "Claude"; exit 0; }

# debug: STATUSLINE_DEBUG=1 → dump stdin to /tmp
[ "${STATUSLINE_DEBUG:-0}" = "1" ] && { echo "$input" > /tmp/claude-statusline-last.json; chmod 600 /tmp/claude-statusline-last.json; } 2>/dev/null

# ── helpers ───────────────────────────────────────────
j() { echo "$input" | jq -r "$1 // empty"; }
sanitize() { printf '%s' "$1" | sed 's/\\/\\\\/g'; }

pct_color() {
    local p=${1:-0}
    if   [ "$p" -ge 90 ]; then echo $'\033[38;5;203m'
    elif [ "$p" -ge 75 ]; then echo $'\033[38;5;215m'
    elif [ "$p" -ge 50 ]; then echo $'\033[38;5;221m'
    elif [ "$p" -ge 25 ]; then echo $'\033[38;5;115m'
    else                       echo $'\033[38;5;78m'
    fi
}

bar() {
    local p=${1:-0} w=${2:-10} f e i filled="" empty=""
    [ "$p" -gt 100 ] && p=100
    [ "$p" -lt 0 ]   && p=0
    f=$(( p * w / 100 )); e=$(( w - f ))
    for ((i=0; i<f; i++)); do filled+="▪"; done
    for ((i=0; i<e; i++)); do empty+="▫"; done
    printf '%b%s\033[2m%s\033[0m' "$(pct_color "$p")" "$filled" "$empty"
}

fmt_epoch() {  # epoch_seconds STYLE (time|date)
    local e=$1 style=$2 out
    [ -z "$e" ] || [ "$e" = "0" ] && return
    if [ "$style" = time ]; then
        out=$(date -j -r "$e" +"%l:%M%p" 2>/dev/null || date -d "@$e" +"%l:%M%P" 2>/dev/null)
    else
        out=$(date -j -r "$e" +"%b %-d, %l:%M%p" 2>/dev/null || date -d "@$e" +"%b %-d, %l:%M%P" 2>/dev/null)
    fi
    echo "$out" | sed 's/^ *//; s/  */ /g' | tr '[:upper:]' '[:lower:]'
}

fmt_duration() {  # ms → "1h20m" / "5m" / "30s"
    local ms=${1:-0} s
    s=$(( ms / 1000 ))
    if   [ "$s" -ge 3600 ]; then echo "$((s/3600))h$(( (s%3600)/60 ))m"
    elif [ "$s" -ge 60 ];   then echo "$((s/60))m"
    else                         echo "${s}s"
    fi
}

shorten_model() {  # "Opus 4.7 (1M context)" → "opus-4.7-1m"; "Claude Sonnet 4.6" → "sonnet-4.6"
    echo "$1" \
        | sed -E 's/Claude //I; s/\(([0-9]+)M context\)/\1m/I; s/[()]//g' \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/ +/-/g; s/-+$//'
}

# ── data ──────────────────────────────────────────────
model_raw=$(j '.model.display_name')
model=$(sanitize "$(shorten_model "${model_raw:-Claude}")")

effort=$(sanitize "$(j '.effort.level')")
[ -z "$effort" ] && effort="default"

ctx_pct=$(j '.context_window.used_percentage')
[ -z "$ctx_pct" ] && ctx_pct=0
ctx_in_total=$(j '.context_window.total_input_tokens')
ctx_size=$(j '.context_window.context_window_size')
cache_read=$(j '.context_window.current_usage.cache_read_input_tokens')
cache_create=$(j '.context_window.current_usage.cache_creation_input_tokens')

fmt_tokens() {  # 91745 → "92k"; 1000000 → "1M"
    local n=${1:-0}
    if   [ "$n" -ge 1000000 ]; then awk -v n="$n" 'BEGIN { printf "%gM", n/1000000 }'
    elif [ "$n" -ge 1000 ];    then awk -v n="$n" 'BEGIN { printf "%dk", n/1000 }'
    else                            echo "$n"
    fi
}

ctx_used_str=""
if [ -n "$ctx_in_total" ] && [ -n "$ctx_size" ]; then
    ctx_used_str="$(fmt_tokens "$ctx_in_total")/$(fmt_tokens "$ctx_size")"
fi

cost_usd=$(j '.cost.total_cost_usd')
sess_ms=$(j '.cost.total_duration_ms')

thinking=$(j '.thinking.enabled')
fast_mode=$(j '.fast_mode')

cwd=$(j '.cwd')
repo_name=$(sanitize "$(j '.workspace.repo.name')")
branch=""
[ -n "$cwd" ] && branch=$(sanitize "$(git -C "$cwd" branch --show-current 2>/dev/null)")

cache_hit_pct=""
if [ -n "$cache_read" ] && [ -n "$ctx_in_total" ] && [ "$ctx_in_total" -gt 0 ]; then
    cache_hit_pct=$(awk -v r="$cache_read" -v t="$ctx_in_total" 'BEGIN { printf "%d", r/t*100 }')
fi

rl5_pct=$(j '.rate_limits.five_hour.used_percentage')
rl5_reset=$(j '.rate_limits.five_hour.resets_at')
rl7_pct=$(j '.rate_limits.seven_day.used_percentage')
rl7_reset=$(j '.rate_limits.seven_day.resets_at')

# ── icons ─────────────────────────────────────────────
ctx_icon='🧠'
time_icon='⏱'
case "$effort" in
    xhigh) eff_icon='◉' ;;
    high)  eff_icon='●' ;;
    medium) eff_icon='◑' ;;
    low)    eff_icon='◔' ;;
    *)      eff_icon='○' ;;
esac

# ── line 1 ────────────────────────────────────────────
SEP=' \033[2m|\033[0m '
parts=()
parts+=("\033[38;5;75m${model}\033[0m")
[ "$fast_mode" = "true" ] && parts[-1]="${parts[-1]} \033[38;5;215m⚡\033[0m"
ctx_part="${ctx_icon} $(pct_color "$ctx_pct")${ctx_pct}%\033[0m"
[ -n "$ctx_used_str" ] && ctx_part+=" \033[2m·\033[0m \033[2m${ctx_used_str}\033[0m"
[ -n "$cache_hit_pct" ] && ctx_part+=" \033[2m·\033[0m \033[38;5;115mcache ${cache_hit_pct}%\033[0m"
parts+=("$ctx_part")
if [ -n "$sess_ms" ] && [ "$sess_ms" != "0" ]; then
    parts+=("${time_icon} $(fmt_duration "$sess_ms")")
fi
parts+=("${eff_icon} ${effort}")
[ "$thinking" = "true" ] && parts+=("\033[38;5;141m✱ think\033[0m")
if [ -n "$cost_usd" ]; then
    parts+=("\$$(LANG=C awk -v c="$cost_usd" 'BEGIN { printf "%.2f", c }')")
fi

line1=""
for i in "${!parts[@]}"; do
    [ "$i" -gt 0 ] && line1+="$SEP"
    line1+="${parts[$i]}"
done

# ── line 2 (rate limits) ──────────────────────────────
line2=""
if [ -n "$rl5_pct" ]; then
    p=$(printf '%.0f' "$rl5_pct")
    r=$(fmt_epoch "$rl5_reset" time)
    line2+="\033[2m5h\033[0m $(bar "$p" 12) $(pct_color "$p")${p}%\033[0m"
    [ -n "$r" ] && line2+=" \033[2m↻\033[0m ${r}"
fi
if [ -n "$rl7_pct" ]; then
    p=$(printf '%.0f' "$rl7_pct")
    r=$(fmt_epoch "$rl7_reset" date)
    [ -n "$line2" ] && line2+="  \033[2m|\033[0m  "
    line2+="\033[2m7d\033[0m $(bar "$p" 12) $(pct_color "$p")${p}%\033[0m"
    [ -n "$r" ] && line2+=" \033[2m↻\033[0m ${r}"
fi

# ── line 3 (repo + branch) ───────────────────────────
line3=""
if [ -n "$repo_name" ]; then
    line3+="\033[38;5;245m${repo_name}\033[0m"
    [ -n "$branch" ] && line3+="\033[2m:\033[0m\033[38;5;179m${branch}\033[0m"
fi

# ── output ────────────────────────────────────────────
printf '%b' "$line1"
[ -n "$line2" ] && printf '\n%b' "$line2"
[ -n "$line3" ] && printf '\n%b' "$line3"
exit 0
