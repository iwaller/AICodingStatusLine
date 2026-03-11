#!/bin/bash

set -f

# Codex CLI status line — reads model/effort from config.toml,
# token usage and rate limits from session JSONL files.

# Parse arguments: codex_statusline.sh [project_dir] [--line N]
target_dir="$PWD"
line_select=0
while [ $# -gt 0 ]; do
    case "$1" in
        --line) line_select="$2"; shift 2 ;;
        *) target_dir="$1"; shift ;;
    esac
done
if [ -d "$target_dir" ]; then
    target_dir="$(cd "$target_dir" && pwd)"
else
    target_dir="$PWD"
fi

config_file="$HOME/.codex/config.toml"
session_base="${CODEX_STATUSLINE_SESSION_DIR:-$HOME/.codex/sessions}"

# Read statusline config from config.toml [statusline] section, env vars take priority.
_toml_get() {
    local key="$1" default="$2"
    if [ -f "$config_file" ]; then
        local val
        val=$(sed -n '/^\[statusline\]/,/^\[/{ s/^'"$key"'[[:space:]]*=[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p; }' "$config_file" 2>/dev/null | head -1)
        [ -n "$val" ] && { printf "%s" "$val"; return; }
    fi
    printf "%s" "$default"
}

theme_name="${CODEX_STATUSLINE_THEME:-$(_toml_get theme default)}"
layout_name="${CODEX_STATUSLINE_LAYOUT:-$(_toml_get layout compact)}"
bar_style_name="${CODEX_STATUSLINE_BAR_STYLE:-$(_toml_get bar_style ascii)}"

# Output format: tmux (#[fg=...]) vs ansi (\033[...m)
# Auto-detect: use tmux format when TMUX is set, unless overridden.
output_format="${CODEX_STATUSLINE_FORMAT:-}"
if [ -z "$output_format" ]; then
    if [ -n "${TMUX:-}" ]; then
        output_format="tmux"
    else
        output_format="ansi"
    fi
fi

case "$layout_name" in
    bars|compact) ;;
    *) layout_name="compact" ;;
esac
case "$bar_style_name" in
    dots)
        bar_filled_char='●'
        bar_empty_char='○'
        ;;
    squares)
        bar_filled_char='■'
        bar_empty_char='□'
        ;;
    blocks)
        bar_filled_char='█'
        bar_empty_char='░'
        ;;
    braille)
        bar_filled_char='⣿'
        bar_empty_char='⣀'
        ;;
    shades)
        bar_filled_char='▓'
        bar_empty_char='░'
        ;;
    diamonds)
        bar_filled_char='◆'
        bar_empty_char='◇'
        ;;
    custom:*)
        bar_filled_char="$(printf '%s' "$bar_style_name" | cut -d: -f2)"
        bar_empty_char="$(printf '%s' "$bar_style_name" | cut -d: -f3)"
        [ -z "$bar_filled_char" ] && bar_filled_char='='
        [ -z "$bar_empty_char" ] && bar_empty_char='-'
        ;;
    *)
        bar_style_name="ascii"
        bar_filled_char='='
        bar_empty_char='-'
        ;;
esac

# Color palette — theme hex values (R;G;B triplets)
# Mapped to either ANSI or tmux format below.
case "$theme_name" in
    forest)    _accent="120;196;120" _teal="94;170;150" _branch="214;224;205" _muted="132;144;124" _red="224;108;117" _orange="214;170;84" _yellow="198;183;101" _green="120;196;120" _white="234;238;228" ;;
    dracula)   _accent="189;147;249" _teal="139;233;253" _branch="248;248;242" _muted="98;114;164" _red="255;85;85" _orange="255;184;108" _yellow="241;250;140" _green="80;250;123" _white="248;248;242" ;;
    monokai)   _accent="102;217;239" _teal="166;226;46" _branch="230;219;116" _muted="117;113;94" _red="249;38;114" _orange="253;151;31" _yellow="230;219;116" _green="166;226;46" _white="248;248;242" ;;
    solarized) _accent="38;139;210" _teal="42;161;152" _branch="147;161;161" _muted="88;110;117" _red="220;50;47" _orange="203;75;22" _yellow="181;137;0" _green="133;153;0" _white="238;232;213" ;;
    ocean)     _accent="0;188;212" _teal="0;151;167" _branch="178;235;242" _muted="120;144;156" _red="239;83;80" _orange="255;152;0" _yellow="255;213;79" _green="102;187;106" _white="224;247;250" ;;
    sunset)    _accent="255;138;101" _teal="255;183;77" _branch="255;204;128" _muted="161;136;127" _red="239;83;80" _orange="255;112;66" _yellow="255;213;79" _green="174;213;129" _white="255;243;224" ;;
    amber)     _accent="255;193;7" _teal="220;184;106" _branch="240;230;200" _muted="158;148;119" _red="232;98;92" _orange="232;152;62" _yellow="212;170;50" _green="140;179;105" _white="245;240;224" ;;
    rose)      _accent="244;143;177" _teal="206;147;216" _branch="248;215;224" _muted="173;139;159" _red="239;83;80" _orange="255;138;101" _yellow="255;213;79" _green="165;214;167" _white="253;232;239" ;;
    *)         _accent="77;166;255" _teal="77;175;176" _branch="196;208;212" _muted="115;132;139" _red="255;85;85" _orange="255;176;85" _yellow="230;200;0" _green="0;160;0" _white="228;232;234" ;;
esac

# Convert R;G;B triplets to output format
_rgb_to_hex() {
    local IFS=';'; set -- $1
    printf '#%02x%02x%02x' "$1" "$2" "$3"
}

if [ "$output_format" = "tmux" ]; then
    accent="#[fg=$(_rgb_to_hex "$_accent")]"
    teal="#[fg=$(_rgb_to_hex "$_teal")]"
    branch="#[fg=$(_rgb_to_hex "$_branch")]"
    muted="#[fg=$(_rgb_to_hex "$_muted")]"
    red="#[fg=$(_rgb_to_hex "$_red")]"
    orange="#[fg=$(_rgb_to_hex "$_orange")]"
    yellow="#[fg=$(_rgb_to_hex "$_yellow")]"
    green="#[fg=$(_rgb_to_hex "$_green")]"
    white="#[fg=$(_rgb_to_hex "$_white")]"
    dim='#[dim]'
    reset='#[default]'
else
    accent="\033[38;2;${_accent}m"
    teal="\033[38;2;${_teal}m"
    branch="\033[38;2;${_branch}m"
    muted="\033[38;2;${_muted}m"
    red="\033[38;2;${_red}m"
    orange="\033[38;2;${_orange}m"
    yellow="\033[38;2;${_yellow}m"
    green="\033[38;2;${_green}m"
    white="\033[38;2;${_white}m"
    dim='\033[2m'
    reset='\033[0m'
fi

sep_plain=' | '
sep_text=" ${dim}|${reset} "
seven_day_time_format='%m %d %H:%M'
short_seven_day_date_format='%m %d'

SEG_TEXT=""
SEG_PLAIN=""
COMPOSED_TEXT=""
COMPOSED_PLAIN=""
COMPOSED_LEN=0
GIT_SEGMENT_LEN=0
OUTPUT_TEXT=""
LINE_TEXT=""
LINE_PLAIN=""

# ── Data collection ──────────────────────────────────────────────

resolve_model() {
    local m="${CODEX_MODEL_NAME:-${CODEX_MODEL:-${OPENAI_MODEL:-${MODEL:-}}}}"
    if [ -z "$m" ] && [ -f "$config_file" ]; then
        m=$(grep '^model\s*=' "$config_file" 2>/dev/null | head -1 | sed 's/^model[[:space:]]*=[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}/\1/')
    fi
    printf "%s" "${m:-codex}"
}

resolve_effort() {
    local e="${CODEX_EFFORT_LEVEL:-}"
    if [ -z "$e" ] && [ -f "$config_file" ]; then
        e=$(grep '^model_reasoning_effort\s*=' "$config_file" 2>/dev/null | head -1 | sed 's/^model_reasoning_effort[[:space:]]*=[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}/\1/')
    fi
    printf "%s" "${e:-medium}"
}

find_latest_session() {
    find "$session_base" -name "*.jsonl" -type f 2>/dev/null | sort -r | head -1
}

parse_session_data() {
    local cache_file="${CODEX_STATUSLINE_CACHE_FILE:-/tmp/codex/statusline-session-cache.json}"
    local cache_max_age=10
    mkdir -p /tmp/codex

    if [ -f "$cache_file" ]; then
        local mtime now age
        mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)
        now=$(date +%s)
        age=$(( now - mtime ))
        if [ "$age" -lt "$cache_max_age" ]; then
            cat "$cache_file"
            return 0
        fi
    fi

    local session_file
    session_file=$(find_latest_session)
    [ -z "$session_file" ] && return 1

    local line
    if command -v tac >/dev/null 2>&1; then
        line=$(tac "$session_file" | grep -m1 '"token_count"')
    else
        line=$(tail -r "$session_file" 2>/dev/null | grep -m1 '"token_count"')
    fi
    [ -z "$line" ] && return 1

    if ! command -v jq >/dev/null 2>&1; then
        return 1
    fi

    local parsed
    parsed=$(printf '%s' "$line" | jq -c '{
        input: .payload.info.total_token_usage.input_tokens,
        cached: .payload.info.total_token_usage.cached_input_tokens,
        output: .payload.info.total_token_usage.output_tokens,
        total: .payload.info.total_token_usage.total_tokens,
        window: .payload.info.model_context_window,
        primary_pct: .payload.rate_limits.primary.used_percent,
        primary_reset: .payload.rate_limits.primary.resets_at,
        secondary_pct: .payload.rate_limits.secondary.used_percent,
        secondary_reset: .payload.rate_limits.secondary.resets_at,
        has_limits: (.payload.rate_limits.primary != null)
    }' 2>/dev/null)

    if [ -n "$parsed" ]; then
        printf '%s' "$parsed" > "$cache_file"
        printf '%s' "$parsed"
        return 0
    fi
    return 1
}

# ── Shared rendering functions (ported from statusline.sh) ───────

format_tokens() {
    local num=$1
    if [ "$num" -ge 1000000 ]; then
        awk "BEGIN {printf \"%.1fm\", $num / 1000000}"
    elif [ "$num" -ge 1000 ]; then
        awk "BEGIN {printf \"%.0fk\", $num / 1000}"
    else
        printf "%d" "$num"
    fi
}

usage_color() {
    local pct=$1
    if [ "$pct" -ge 90 ]; then
        printf "%s" "$red"
    elif [ "$pct" -ge 70 ]; then
        printf "%s" "$orange"
    elif [ "$pct" -ge 50 ]; then
        printf "%s" "$yellow"
    else
        printf "%s" "$green"
    fi
}

is_positive_int() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

get_max_width() {
    if is_positive_int "${CODEX_STATUSLINE_MAX_WIDTH:-}"; then
        printf "%s" "$CODEX_STATUSLINE_MAX_WIDTH"
        return
    fi

    if is_positive_int "${COLUMNS:-}"; then
        printf "%s" "$COLUMNS"
        return
    fi

    local cols
    cols=$(tput cols 2>/dev/null)
    if is_positive_int "$cols"; then
        printf "%s" "$cols"
        return
    fi

    printf "100"
}

truncate_middle() {
    local value="$1"
    local limit="$2"
    local length=${#value}

    if [ "$length" -le "$limit" ]; then
        printf "%s" "$value"
        return
    fi

    if [ "$limit" -le 3 ]; then
        printf "..."
        return
    fi

    local left_keep=$(( (limit - 3) / 2 ))
    local right_keep=$(( limit - 3 - left_keep ))
    local right_start=$(( length - right_keep ))

    printf "%s...%s" "${value:0:left_keep}" "${value:right_start}"
}

add_segment() {
    segment_texts+=("$1")
    segment_plains+=("$2")
}

repeat_char() {
    local count="$1"
    local char="$2"
    local result=""

    [ "$count" -le 0 ] && return
    while [ "$count" -gt 0 ]; do
        result="${result}${char}"
        count=$(( count - 1 ))
    done
    printf "%s" "$result"
}

# ── Segment builders ─────────────────────────────────────────────

build_model_segment() {
    SEG_PLAIN="$model_name"
    SEG_TEXT="${accent}${model_name}${reset}"
}

build_git_segment() {
    SEG_PLAIN=""
    SEG_TEXT=""

    local base_plain="$display_dir"
    if [ -n "$git_branch" ]; then
        base_plain="${display_dir}@${git_branch}"
    fi

    if [ "$show_git_diff" -eq 1 ] && [ -n "$git_stat" ]; then
        base_plain="${base_plain} (${git_stat})"
    fi

    if [ "$git_truncate_width" -gt 0 ] && [ ${#base_plain} -gt "$git_truncate_width" ]; then
        local truncated
        truncated=$(truncate_middle "$base_plain" "$git_truncate_width")
        SEG_PLAIN="$truncated"
        SEG_TEXT="${teal}${truncated}${reset}"
        return
    fi

    SEG_PLAIN="$base_plain"
    SEG_TEXT="${teal}${display_dir}${reset}"
    if [ -n "$git_branch" ]; then
        SEG_TEXT+="${dim}@${reset}${branch}${git_branch}${reset}"
    fi
    if [ "$show_git_diff" -eq 1 ] && [ -n "$git_stat" ]; then
        local added_part="${git_stat%% *}"
        local deleted_part="${git_stat##* }"
        SEG_TEXT+=" ${dim}(${reset}${green}${added_part}${reset} ${red}${deleted_part}${reset}${dim})${reset}"
    fi
}

build_ctx_segment() {
    local pct_color
    pct_color=$(usage_color "$pct_used")
    SEG_PLAIN="ctx ${used_tokens}/${total_tokens} ${pct_used}%"
    SEG_TEXT="${dim}ctx${reset} ${white}${used_tokens}/${total_tokens}${reset} ${pct_color}${pct_used}%${reset}"
}

build_eff_segment() {
    local effort_label effort_text
    case "$effort_level" in
        low)
            effort_label="low"
            effort_text="${branch}low${reset}"
            ;;
        medium)
            effort_label="med"
            effort_text="${yellow}med${reset}"
            ;;
        *)
            effort_label="high"
            effort_text="${orange}high${reset}"
            ;;
    esac

    SEG_PLAIN="eff ${effort_label}"
    SEG_TEXT="${dim}eff${reset} ${effort_text}"
}

build_five_hour_segment() {
    if [ "$usage_available" -ne 1 ]; then
        SEG_PLAIN="5h -"
        SEG_TEXT="${dim}5h${reset} ${dim}-${reset}"
        return
    fi

    local pct_color
    pct_color=$(usage_color "$five_hour_pct")
    SEG_PLAIN="5h ${five_hour_pct}%"
    SEG_TEXT="${dim}5h${reset} ${pct_color}${five_hour_pct}%${reset}"
    if [ "$show_five_hour_reset" -eq 1 ] && [ -n "$five_hour_reset" ]; then
        SEG_PLAIN+=" ${five_hour_reset}"
        SEG_TEXT+=" ${dim}${five_hour_reset}${reset}"
    fi
}

build_seven_day_segment() {
    if [ "$usage_available" -ne 1 ]; then
        SEG_PLAIN="2w -"
        SEG_TEXT="${dim}2w${reset} ${dim}-${reset}"
        return
    fi

    local pct_color
    pct_color=$(usage_color "$seven_day_pct")
    SEG_PLAIN="2w ${seven_day_pct}%"
    SEG_TEXT="${dim}2w${reset} ${pct_color}${seven_day_pct}%${reset}"
    if [ "$show_seven_day_reset" -eq 1 ] && [ -n "$seven_day_reset" ]; then
        SEG_PLAIN+=" ${seven_day_reset}"
        SEG_TEXT+=" ${dim}${seven_day_reset}${reset}"
    fi
}

# ── Composition ──────────────────────────────────────────────────

compose_segments() {
    segment_texts=()
    segment_plains=()
    GIT_SEGMENT_LEN=0

    build_model_segment
    add_segment "$SEG_TEXT" "$SEG_PLAIN"

    build_git_segment
    if [ -n "$SEG_PLAIN" ]; then
        GIT_SEGMENT_LEN=${#SEG_PLAIN}
        add_segment "$SEG_TEXT" "$SEG_PLAIN"
    fi

    build_ctx_segment
    add_segment "$SEG_TEXT" "$SEG_PLAIN"

    build_eff_segment
    add_segment "$SEG_TEXT" "$SEG_PLAIN"

    if [ "$include_usage_summary" -eq 1 ]; then
        build_five_hour_segment
        add_segment "$SEG_TEXT" "$SEG_PLAIN"

        if [ "$show_seven_day" -eq 1 ]; then
            build_seven_day_segment
            add_segment "$SEG_TEXT" "$SEG_PLAIN"
        fi
    fi

    COMPOSED_TEXT=""
    COMPOSED_PLAIN=""
    local idx
    for idx in "${!segment_texts[@]}"; do
        if [ "$idx" -gt 0 ]; then
            COMPOSED_TEXT+="$sep_text"
            COMPOSED_PLAIN+="$sep_plain"
        fi
        COMPOSED_TEXT+="${segment_texts[$idx]}"
        COMPOSED_PLAIN+="${segment_plains[$idx]}"
    done
    COMPOSED_LEN=${#COMPOSED_PLAIN}
}

# ── Width-adaptive rendering ─────────────────────────────────────

render_compact_output() {
    include_usage_summary="$1"
    compose_segments

    if [ "$include_usage_summary" -eq 1 ] && [ "$COMPOSED_LEN" -gt "$max_width" ] && [ "$show_seven_day_reset" -eq 1 ]; then
        show_seven_day_reset=0
        compose_segments
    fi

    if [ "$include_usage_summary" -eq 1 ] && [ "$COMPOSED_LEN" -gt "$max_width" ] && [ "$show_five_hour_reset" -eq 1 ]; then
        show_five_hour_reset=0
        compose_segments
    fi

    if [ "$COMPOSED_LEN" -gt "$max_width" ] && [ "$show_git_diff" -eq 1 ]; then
        show_git_diff=0
        compose_segments
    fi

    if [ "$include_usage_summary" -eq 1 ] && [ "$COMPOSED_LEN" -gt "$max_width" ] && [ "$show_seven_day" -eq 1 ]; then
        show_seven_day=0
        compose_segments
    fi

    if [ "$COMPOSED_LEN" -gt "$max_width" ] && [ "$GIT_SEGMENT_LEN" -gt 0 ]; then
        available_for_git=$(( max_width - (COMPOSED_LEN - GIT_SEGMENT_LEN) ))
        if [ "$available_for_git" -lt 3 ]; then
            available_for_git=3
        fi
        git_truncate_width="$available_for_git"
        compose_segments
    fi

    OUTPUT_TEXT="$COMPOSED_TEXT"
}

build_usage_bar_line() {
    local label="$1"
    local pct_value="$2"
    local pct_text="$3"
    local full_time="$4"
    local short_time="$5"
    local time_text="$full_time"
    local base_bar_width=10
    local min_bar_width=4

    if [ "$label" = "5h" ] && [ "$max_width" -le 44 ]; then
        time_text=""
    fi

    if [ "$label" = "2w" ]; then
        if [ "$max_width" -le 44 ]; then
            time_text="$short_time"
        elif [ "$max_width" -le 52 ] && [ -n "$short_time" ]; then
            time_text="$short_time"
        fi
    fi

    local fixed_width=$(( ${#label} + 1 + ${#pct_text} + 1 + 2 ))
    if [ -n "$time_text" ]; then
        fixed_width=$(( fixed_width + 1 + ${#time_text} ))
    fi

    local bar_width=$base_bar_width
    local available_width=$(( max_width - fixed_width ))
    if [ "$available_width" -lt "$bar_width" ]; then
        bar_width="$available_width"
    fi
    if [ "$bar_width" -lt "$min_bar_width" ]; then
        bar_width="$min_bar_width"
    fi

    local filled_width=0
    if [ "$pct_value" -gt 0 ]; then
        filled_width=$(( pct_value * bar_width / 100 ))
    fi
    if [ "$filled_width" -gt "$bar_width" ]; then
        filled_width="$bar_width"
    fi
    local empty_width=$(( bar_width - filled_width ))

    local filled_plain empty_plain filled_text pct_color time_color
    filled_plain=$(repeat_char "$filled_width" "$bar_filled_char")
    empty_plain=$(repeat_char "$empty_width" "$bar_empty_char")

    if [ "$pct_text" = "--" ]; then
        pct_color="$branch"
        time_color="$branch"
        filled_text="${muted}${filled_plain}${reset}"
    else
        pct_color=$(usage_color "$pct_value")
        time_color="$muted"
        filled_text="${pct_color}${filled_plain}${reset}"
    fi

    LINE_PLAIN="${label} ${pct_text} [${filled_plain}${empty_plain}]"
    LINE_TEXT="${dim}${label}${reset} ${pct_color}${pct_text}${reset} ${dim}[${reset}${filled_text}${muted}${empty_plain}${reset}${dim}]${reset}"

    if [ -n "$time_text" ]; then
        LINE_PLAIN+=" ${time_text}"
        LINE_TEXT+=" ${time_color}${time_text}${reset}"
    fi
}

render_bars_output() {
    local full_five_time="$five_hour_reset"
    local full_seven_time="$seven_day_reset"
    local short_seven_time="$seven_day_date"

    render_compact_output 0
    local top_line="$OUTPUT_TEXT"

    if [ "$usage_available" -eq 1 ]; then
        build_usage_bar_line "5h" "$five_hour_pct" "${five_hour_pct}%" "$full_five_time" ""
    else
        build_usage_bar_line "5h" 0 "--" "n/a" ""
    fi
    local five_line="$LINE_TEXT"

    if [ "$usage_available" -eq 1 ]; then
        build_usage_bar_line "2w" "$seven_day_pct" "${seven_day_pct}%" "$full_seven_time" "$short_seven_time"
    else
        build_usage_bar_line "2w" 0 "--" "n/a" ""
    fi
    local seven_line="$LINE_TEXT"

    OUTPUT_TEXT="${top_line}"$'\n'"${five_line}"$'\n'"${seven_line}"
}

# ── Collect data ─────────────────────────────────────────────────

model_name=$(resolve_model)
effort_level=$(resolve_effort)

display_dir="${target_dir##*/}"
git_branch=""
git_stat=""
if git -C "$target_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_branch=$(git -C "$target_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
    git_stat=$(
        {
            git -C "$target_dir" diff --numstat 2>/dev/null
            git -C "$target_dir" diff --cached --numstat 2>/dev/null
        } | awk '{if ($1 ~ /^[0-9]+$/) a+=$1; if ($2 ~ /^[0-9]+$/) d+=$2} END {if (a+d>0) printf "+%d -%d", a, d}'
    )
fi

# Parse session data for token usage and rate limits
usage_available=0
show_seven_day=1
show_five_hour_reset=0
show_seven_day_reset=0
show_git_diff=0
git_truncate_width=0

five_hour_pct=0
five_hour_reset=""
seven_day_pct=0
seven_day_reset=""
seven_day_date=""

ctx_total=0
ctx_window=0
pct_used=0
used_tokens="0"
total_tokens="0"

session_json=$(parse_session_data 2>/dev/null) || session_json=""
if [ -n "$session_json" ]; then
    ctx_total=$(printf '%s' "$session_json" | jq -r '.total // 0')
    ctx_window=$(printf '%s' "$session_json" | jq -r '.window // 0')
    if [ "$ctx_window" -gt 0 ] 2>/dev/null; then
        pct_used=$(( ctx_total * 100 / ctx_window ))
    fi
    used_tokens=$(format_tokens "$ctx_total")
    total_tokens=$(format_tokens "$ctx_window")

    has_limits=$(printf '%s' "$session_json" | jq -r '.has_limits')
    if [ "$has_limits" = "true" ]; then
        usage_available=1
        five_hour_pct=$(printf '%s' "$session_json" | jq -r '.primary_pct // 0' | awk '{printf "%.0f", $1}')
        five_hour_reset_epoch=$(printf '%s' "$session_json" | jq -r '.primary_reset // 0')
        seven_day_pct=$(printf '%s' "$session_json" | jq -r '.secondary_pct // 0' | awk '{printf "%.0f", $1}')
        seven_day_reset_epoch=$(printf '%s' "$session_json" | jq -r '.secondary_reset // 0')

        now=$(date +%s)
        if [ "$five_hour_reset_epoch" -gt "$now" ] 2>/dev/null; then
            five_hour_reset=$(date -r "$five_hour_reset_epoch" +"%H:%M" 2>/dev/null || \
                              date -d "@$five_hour_reset_epoch" +"%H:%M" 2>/dev/null) || true
            [ -n "$five_hour_reset" ] && show_five_hour_reset=1
        fi
        if [ "$seven_day_reset_epoch" -gt "$now" ] 2>/dev/null; then
            seven_day_reset=$(date -r "$seven_day_reset_epoch" +"$seven_day_time_format" 2>/dev/null || \
                              date -d "@$seven_day_reset_epoch" +"$seven_day_time_format" 2>/dev/null) || true
            seven_day_date=$(date -r "$seven_day_reset_epoch" +"$short_seven_day_date_format" 2>/dev/null || \
                             date -d "@$seven_day_reset_epoch" +"$short_seven_day_date_format" 2>/dev/null) || true
            [ -n "$seven_day_reset" ] && show_seven_day_reset=1
        fi
    fi
fi

[ -n "$git_stat" ] && show_git_diff=1
max_width=$(get_max_width)

# --line N: output a single line from bars layout (1=overview, 2=5h, 3=2w)
if [ "$line_select" -gt 0 ] 2>/dev/null; then
    # Force bars rendering, then extract requested line
    render_bars_output
    line_out=$(printf "%b" "$OUTPUT_TEXT" | sed -n "${line_select}p")
    if [ "$output_format" = "tmux" ]; then
        printf "%s" "$line_out"
    else
        printf "%s" "$line_out"
    fi
    exit 0
fi

if [ "$layout_name" = "bars" ]; then
    render_bars_output
else
    render_compact_output 1
fi

if [ "$output_format" = "tmux" ]; then
    printf "%s" "$OUTPUT_TEXT"
else
    printf "%b" "$OUTPUT_TEXT"
fi
exit 0
