# ── Portable xorshift32 PRNG ───────────────────────────────────────────────────

set -g _RKT_PRNG_STATE 0

function _rkt_xorshift32 --argument-names s
    set s (math --scale=0 "bitxor($s, ($s * 8192)) % 4294967296")
    set s (math --scale=0 "bitxor($s, floor($s / 131072)) % 4294967296")
    set s (math --scale=0 "bitxor($s, ($s * 32)) % 4294967296")
    echo $s
end

function _rkt_prng_seed
    while true
        set -g _RKT_PRNG_STATE (od -An -N4 -tu4 /dev/urandom | string trim)
        test "$_RKT_PRNG_STATE" != "0"; and break
    end
end

function _rkt_prng_range --argument-names min max
    set -g _RKT_PRNG_STATE (math --scale=0 "bitxor($_RKT_PRNG_STATE, ($_RKT_PRNG_STATE * 8192)) % 4294967296")
    set -g _RKT_PRNG_STATE (math --scale=0 "bitxor($_RKT_PRNG_STATE, floor($_RKT_PRNG_STATE / 131072)) % 4294967296")
    set -g _RKT_PRNG_STATE (math --scale=0 "bitxor($_RKT_PRNG_STATE, ($_RKT_PRNG_STATE * 32)) % 4294967296")
    set -l range (math "$max - $min + 1")
    math "$min + ($_RKT_PRNG_STATE % $range)"
end

function _hsl_to_hex --argument-names h s l --description "HSL (0-360, 0-100, 0-100) to 6-digit hex"
    set --local sat (math "$s / 100")
    set --local light (math "$l / 100")
    set --local c (math "(1 - abs(2 * $light - 1)) * $sat")
    set --local hp (math "$h / 60")
    set --local x (math "$c * (1 - abs(($hp - 2 * floor($hp / 2)) - 1))")
    set --local m (math "$light - $c / 2")

    set --local hi (math --scale=0 "floor($h)")
    set --local r 0
    set --local g 0
    set --local b 0
    if test $hi -lt 60
        set r $c
        set g $x
    else if test $hi -lt 120
        set r $x
        set g $c
    else if test $hi -lt 180
        set g $c
        set b $x
    else if test $hi -lt 240
        set g $x
        set b $c
    else if test $hi -lt 300
        set r $x
        set b $c
    else
        set r $c
        set b $x
    end

    set --local ri (math --scale=0 "round(($r + $m) * 255)")
    set --local gi (math --scale=0 "round(($g + $m) * 255)")
    set --local bi (math --scale=0 "round(($b + $m) * 255)")
    printf "%02x%02x%02x\n" $ri $gi $bi
end


function _rkt_load_settings --description "Load star color settings; defaults if file missing"
    set --local cfg ~/.config/fish/rocket_settings.fish
    set --global _rkt_random_star_mode white
    set --global _rkt_favorite_star_mode gold
    set --global _rkt_terminal_theme dark
    set --global _rkt_favorite_weight 20
    if test -f $cfg
        source $cfg
    end
end


function _rkt_save_settings --description "Persist star color settings"
    set --local cfg ~/.config/fish/rocket_settings.fish
    mkdir -p (dirname $cfg)
    printf 'set -g _rkt_random_star_mode %s\n'   (string escape -- "$_rkt_random_star_mode")    > $cfg
    printf 'set -g _rkt_favorite_star_mode %s\n' (string escape -- "$_rkt_favorite_star_mode") >> $cfg
    printf 'set -g _rkt_terminal_theme %s\n'     (string escape -- "$_rkt_terminal_theme")     >> $cfg
    printf 'set -g _rkt_favorite_weight %s\n'    (string escape -- "$_rkt_favorite_weight")    >> $cfg
end


function _rkt_print_option --description "Print '(a | b | ...)' with the active option in bold italics"
    set --local active $argv[1]
    set --local opts $argv[2..]
    echo -n "("
    set --local first 1
    for opt in $opts
        if test $first -eq 0
            echo -n " | "
        end
        set first 0
        if test "$active" = "$opt"
            set_color --bold --italics
            echo -n "$opt"
            set_color normal
        else
            echo -n "$opt"
        end
    end
    echo -n ")"
end


function _gen_rocket_palette --description "6-color palette with distinct hues per role"
    set --local h_base (_rkt_prng_range 0 359)
    set --local scheme (_rkt_prng_range 0 4)
    set --local sat (_rkt_prng_range 65 90)
    set --local light (_rkt_prng_range 55 72)


    # Six hues spread around the wheel so no two roles end up near-identical.
    # Slots: 1=porthole, 2=window, 3=body, 4=top, 5=window-sides, 6=flame.
    set --local offs
    switch $scheme
        case 0
            set offs 0 60 120 180 240 300
        case 1
            set offs 0 50 110 180 230 290
        case 2
            set offs 0 70 130 200 250 310
        case 3
            set offs 0 45 115 180 235 295
        case '*'
            set offs 0 65 125 190 245 310
    end

    for off in $offs
        set --local h (math "($h_base + $off) % 360")
        _hsl_to_hex $h $sat $light
    end
end


function _rocket_record_history --description "Append palette to history, cap at 100 entries"
    set --local file ~/.config/fish/rocket_history.txt
    set --local lock $file.lock
    mkdir -p (dirname $file)
    set --local waited 0
    while not mkdir $lock 2>/dev/null
        sleep 0.05
        set waited (math "$waited + 1")
        if test $waited -ge 20
            return 1
        end
    end
    echo (string join " " $argv) >> $file
    set --local lc (wc -l < $file | string trim)
    if test $lc -gt 100
        tail -n 100 $file > $file.tmp
        and mv $file.tmp $file
    end
    rmdir $lock 2>/dev/null
end


function _rkt_neon_color --description "Pick a neon hex from a dark-bg-optimized set"
    set --local neons \
        FF0033 FF3300 FF6600 FF9900 FFBB00 FFDD00 FFFF00 \
        CCFF00 99FF00 66FF00 33FF00 00FF33 00FF66 00FF99 \
        00FFCC 00FFFF 00CCFF 0099FF 0066FF 0033FF 3300FF \
        6600FF 9900FF CC00FF FF00FF FF00CC FF0099 FF0066
    echo $neons[(_rkt_prng_range 1 (count $neons))]
end


function _rkt_neon_color_light --description "Pick a neon hex from a light-bg-optimized set"
    set --local neons \
        CC0029 CC2900 CC5200 CC7A00 CC9500 B8860B AAAA00 \
        88AA00 668800 448800 228822 228B22 008844 008866 \
        008B7F 008B8B 0077AA 1E6FB8 0055CC 0033AA 2200AA \
        4B0082 6622AA 7B1FA2 A020A0 AA0088 AD1457 AA0044
    echo $neons[(_rkt_prng_range 1 (count $neons))]
end


function _palette_is_favorite --description "Check if the current palette is saved in favorites"
    set --local fav_file ~/.config/fish/rocket_favorites.txt
    if not test -f $fav_file
        return 1
    end
    set --local palette "$_rkt_tip $_rkt_win $_rkt_bdy $_rkt_top $_rkt_sds $_rkt_flm"
    grep -Fxq "$palette" $fav_file
end


function _rocket_print_star_row --description "Render one row of 6 colored stars + hex codes; optional 3rd arg overrides the '  N. ' prefix"
    set --local n $argv[1]
    set --local palette $argv[2]
    set --local cs (string split " " $palette)
    if test (count $argv) -ge 3
        echo -n "$argv[3]"
    else
        printf "%3d. " $n
    end
    set_color $cs[1]; echo -n "★ "
    set_color $cs[2]; echo -n "★ "
    set_color $cs[3]; echo -n "★ "
    set_color $cs[4]; echo -n "★ "
    set_color $cs[5]; echo -n "★ "
    set_color $cs[6]; echo -n "★"
    set_color normal
    echo "  $palette"
end


function _rocket_palette_bytes --description "Extract 18 bytes (0-255) from the 6 palette colors"
    for color in $_rkt_tip $_rkt_win $_rkt_bdy $_rkt_top $_rkt_sds $_rkt_flm
        for i in 1 3 5
            set --local byte_hex (string sub --start $i --length 2 -- $color)
            printf "%d\n" "0x$byte_hex"
        end
    end
end


function _compute_star_positions --description "Derive star positions from the palette deterministically"
    # Precomputed candidate positions (148 cells); lazy-init once per shell, then reused
    if not set --query _RKT_STAR_CANDIDATES
        set -g _RKT_STAR_CANDIDATES 0:0 0:1 0:2 0:3 0:4 0:5 0:6 0:7 0:8 0:9 0:10 0:11 0:12 0:13 0:14 0:15 0:16 0:17 1:0 1:1 1:2 1:3 1:4 1:5 1:6 1:7 1:9 1:10 1:11 1:12 1:13 1:14 1:15 1:16 1:17 2:0 2:1 2:2 2:3 2:4 2:5 2:6 2:10 2:11 2:12 2:13 2:14 2:15 2:16 2:17 3:0 3:1 3:2 3:3 3:4 3:5 3:11 3:12 3:13 3:14 3:15 3:16 3:17 4:0 4:1 4:2 4:3 4:4 4:12 4:13 4:14 4:15 4:16 4:17 5:0 5:1 5:2 5:3 5:4 5:12 5:13 5:14 5:15 5:16 5:17 6:0 6:1 6:2 6:3 6:4 6:6 6:7 6:8 6:9 6:10 6:12 6:13 6:14 6:15 6:16 6:17 7:0 7:1 7:2 7:6 7:7 7:9 7:10 7:14 7:15 7:16 7:17 8:0 8:1 8:3 8:4 8:6 8:7 8:9 8:10 8:12 8:13 8:15 8:16 8:17 9:0 9:1 9:15 9:16 9:17 11:0 11:1 11:2 11:3 11:4 11:5 11:6 11:7 11:8 11:9 11:10 11:11 11:12 11:13 11:14 11:15 11:16 11:17
    end

    set --local total (count $_RKT_STAR_CANDIDATES)

    set --local seen
    for b in $_RKT_PALETTE_BYTES
        set --local i1 (math "$b % $total")
        set --local i2 (math "($b + 73) % $total")
        for idx in $i1 $i2
            set --local pos $_RKT_STAR_CANDIDATES[(math "$idx + 1")]
            if not contains -- $pos $seen
                set --append seen $pos
            end
        end
    end

    printf "%s\n" $seen
end


function _rkt_star_color_for_mode --description "Return the hex color for the current star mode + theme"
    switch $_rkt_star_mode
        case gold
            if test "$_rkt_terminal_theme" = light
                echo B8860B
            else
                echo FFE600
            end
        case neon
            if test "$_rkt_terminal_theme" = light
                _rkt_neon_color_light
            else
                _rkt_neon_color
            end
        case '*'
            # white mode: charcoal on light, white on dark
            if test "$_rkt_terminal_theme" = light
                echo 333333
            else
                echo FFFFFF
            end
    end
end


function _render_row --argument-names line_num art role --description "Render one 18-col greeting line"
    for col in (seq 0 17)
        set --local i (math "$col + 1")
        set --local char (string sub --start $i --length 1 -- "$art")

        if test "$char" != " "
            set --local r (string sub --start $i --length 1 -- "$role")
            switch $r
                case p
                    set_color $_rkt_tip
                case w
                    set_color $_rkt_win
                case b
                    set_color $_rkt_bdy
                case t
                    set_color $_rkt_top
                case s
                    set_color $_rkt_sds
                case f
                    set_color $_rkt_flm
            end
            echo -n "$char"
            set_color normal
        else if contains -- "$line_num:$col" $_rocket_stars
            set_color (_rkt_star_color_for_mode)
            echo -n "*"
            set_color normal
        else
            echo -n " "
        end
    end
end


function _render_flame --description "4-char flame below the rocket base, palette-deterministic pattern"
    set --local patterns '\\| ||' '|| |/' '\\| |/' '|| ||' '*| |*' '~| ||' '|| |~' '\\| /|'
    set --local n_patterns (count $patterns)
    set --local idx (math "$_RKT_PALETTE_BYTES[1] % $n_patterns")
    set --local pattern $patterns[(math "$idx + 1")]

    echo -n "      "
    set_color $_rkt_flm
    echo -n "$pattern"
    set_color normal
end


function _rocket_pick_palette --description "Configurable chance of favorite, rest fresh; records to history"
    set --local fav_file ~/.config/fish/rocket_favorites.txt
    set --local colors

    if test (_rkt_prng_range 1 100) -le $_rkt_favorite_weight; and test -f $fav_file
        set --local favs (cat $fav_file)
        if test (count $favs) -gt 0
            set colors (string split " " $favs[(_rkt_prng_range 1 (count $favs))])
        end
    end

    if test (count $colors) -ne 6
        set colors (_gen_rocket_palette)
    end

    _rocket_record_history $colors

    printf "%s\n" $colors
end


function _star_validate_hexes --description "Validate and normalize hex codes; outputs cleaned hex per line"
    set --local hexes
    for raw in $argv
        set --local cleaned (string replace -r '^#' '' -- "$raw")
        if not string match -qr '^[0-9a-fA-F]{6}$' -- "$cleaned"
            return 1
        end
        set --append hexes $cleaned
    end
    printf "%s\n" $hexes
end


function _star_preview_palette --description "Render rocket art with a temporary 6-color palette"
    set --local h1 $argv[1]
    set --local h2 $argv[2]
    set --local h3 $argv[3]
    set --local h4 $argv[4]
    set --local h5 $argv[5]
    set --local h6 $argv[6]

    set --local saved_tip $_rkt_tip
    set --local saved_win $_rkt_win
    set --local saved_bdy $_rkt_bdy
    set --local saved_top $_rkt_top
    set --local saved_sds $_rkt_sds
    set --local saved_flm $_rkt_flm
    set --local saved_stars $_rocket_stars

    set --global _rkt_tip $h1
    set --global _rkt_win $h2
    set --global _rkt_bdy $h3
    set --global _rkt_top $h4
    set --global _rkt_sds $h5
    set --global _rkt_flm $h6
    set --global _rocket_stars

    _render_row 1 "        |         " "        b         "; echo
    _render_row 2 "       / \\        " "       t t        "; echo
    _render_row 3 "      / _ \\       " "      t t t       "; echo
    _render_row 4 "     |.o '.|      " "     swp wws      "; echo
    _render_row 5 "     |'._.'|      " "     swwwwws      "; echo
    _render_row 6 "     |     |      " "     b     b      "; echo
    _render_row 7 "   ,'|  |  |`.    " "   ssb  b  bss    "; echo
    _render_row 8 "  /  |  |  |  \\   " "  s  b  b  b  s   "; echo
    _render_row 9 "  |,-'--|--'-.|   " "  bsssttbttsssb   "; echo
    _render_flame; echo

    set --global _rkt_tip $saved_tip
    set --global _rkt_win $saved_win
    set --global _rkt_bdy $saved_bdy
    set --global _rkt_top $saved_top
    set --global _rkt_sds $saved_sds
    set --global _rkt_flm $saved_flm
    set --global _rocket_stars $saved_stars
end


function star --description "Save / browse / preview rocket palettes"
    set --local fav_file ~/.config/fish/rocket_favorites.txt
    set --local hist_file ~/.config/fish/rocket_history.txt

    if test (count $argv) -eq 0
        if not set --query _rkt_bdy
            echo "No active palette. Open a new tab first."
            return 1
        end
        set --local palette "$_rkt_tip $_rkt_win $_rkt_bdy $_rkt_top $_rkt_sds $_rkt_flm"

        if test -f $fav_file; and grep -Fxq "$palette" $fav_file
            echo "Already in favorites."
            return 0
        end

        mkdir -p (dirname $fav_file)
        echo $palette >> $fav_file

        set_color $_rkt_tip; echo -n "★ "
        set_color $_rkt_win; echo -n "★ "
        set_color $_rkt_bdy; echo -n "★ "
        set_color $_rkt_top; echo -n "★ "
        set_color $_rkt_sds; echo -n "★ "
        set_color $_rkt_flm; echo -n "★"
        set_color normal
        echo "  saved! ("(count (cat $fav_file))" total)"
        return 0
    end

    switch $argv[1]
        case list ls
            if not test -f $fav_file
                echo "No favorites yet. Use 'star' to save the current palette."
                return 0
            end
            set --local i 1
            for line in (cat $fav_file)
                _rocket_print_star_row $i $line
                set i (math $i + 1)
            end

        case remove rm
            if not test -f $fav_file
                echo "No favorites to remove."
                return 1
            end
            set --local n $argv[2]
            if not string match -qr '^\d+$' -- "$n"
                echo "Usage: star remove <number>"
                return 1
            end
            set --local lines (cat $fav_file)
            set --local total (count $lines)
            if test $n -lt 1; or test $n -gt $total
                echo "Out of range. You have $total favorites."
                return 1
            end
            set --erase lines[$n]
            if test (count $lines) -eq 0
                rm $fav_file
            else
                printf "%s\n" $lines > $fav_file
            end
            echo "Removed #$n."

        case history hist
            if not test -f $hist_file
                echo "No history yet."
                return 0
            end
            set --local lines (cat $hist_file)
            set --local total (count $lines)

            if test "$argv[2]" = "clear"
                rm $hist_file
                echo "History cleared."
                return 0
            end

            if test (count $argv) -ge 2
                if not string match -qr '^\d+$' -- "$argv[2]"
                    echo "Usage: star history [N | clear]"
                    return 1
                end
                set --local n $argv[2]
                if test $n -lt 1; or test $n -gt $total
                    echo "Out of range. History has $total entries."
                    return 1
                end
                set --local idx (math "$total - $n + 1")
                set --local palette $lines[$idx]

                if test -f $fav_file; and grep -Fxq "$palette" $fav_file
                    echo "Already in favorites."
                    return 0
                end
                mkdir -p (dirname $fav_file)
                echo $palette >> $fav_file

                set --local cs (string split " " $palette)
                set_color $cs[1]; echo -n "★ "
                set_color $cs[2]; echo -n "★ "
                set_color $cs[3]; echo -n "★ "
                set_color $cs[4]; echo -n "★ "
                set_color $cs[5]; echo -n "★ "
                set_color $cs[6]; echo -n "★"
                set_color normal
                echo "  saved to favorites from history #$n!"
                return 0
            end

            set --local limit 20
            set --local shown 0
            for i in (seq $total -1 1)
                if test $shown -ge $limit
                    break
                end
                set --local display_n (math "$total - $i + 1")
                if test $display_n -eq 1
                    _rocket_print_star_row $display_n $lines[$i] "(Current) 1. "
                else
                    _rocket_print_star_row $display_n $lines[$i] (printf "        %3d. " $display_n)
                end
                set shown (math $shown + 1)
            end
            if test $total -gt $limit
                echo ""
                echo "(showing last $limit of $total; full log at $hist_file)"
            end

        case show preview
            if test (count $argv) -lt 7
                echo "Usage: star show <h1> <h2> <h3> <h4> <h5> <h6>"
                echo "Renders a mini rocket preview with the given 6-color palette."
                echo "Order: porthole, window, body, top, window-sides, flame."
                return 1
            end
            set --local hexes (_star_validate_hexes $argv[2..7])
            or begin
                echo "Invalid hex code. Each must be 6 hex digits (e.g., ff0066 or #ff0066)."
                return 1
            end

            echo ""
            set_color $hexes[1]; echo -n "  ★ Porthole      "; set_color normal; echo "  $hexes[1]"
            set_color $hexes[2]; echo -n "  ★ Window        "; set_color normal; echo "  $hexes[2]"
            set_color $hexes[3]; echo -n "  ★ Body          "; set_color normal; echo "  $hexes[3]"
            set_color $hexes[4]; echo -n "  ★ Top           "; set_color normal; echo "  $hexes[4]"
            set_color $hexes[5]; echo -n "  ★ Window-sides  "; set_color normal; echo "  $hexes[5]"
            set_color $hexes[6]; echo -n "  ★ Flame         "; set_color normal; echo "  $hexes[6]"
            echo ""
            _star_preview_palette $hexes[1] $hexes[2] $hexes[3] $hexes[4] $hexes[5] $hexes[6]
            echo ""
            echo "  star add $hexes[1] $hexes[2] $hexes[3] $hexes[4] $hexes[5] $hexes[6]"
            echo "  (^ run that to save to favorites)"

        case add
            if test (count $argv) -lt 7
                echo "Usage: star add <h1> <h2> <h3> <h4> <h5> <h6>"
                echo "Order: porthole, window, body, top, window-sides, flame."
                return 1
            end
            set --local hexes (_star_validate_hexes $argv[2..7])
            or begin
                echo "Invalid hex code. Each must be 6 hex digits (e.g., ff0066 or #ff0066)."
                return 1
            end

            set --local palette "$hexes[1] $hexes[2] $hexes[3] $hexes[4] $hexes[5] $hexes[6]"
            if test -f $fav_file; and grep -Fxq "$palette" $fav_file
                echo "Already in favorites."
                return 0
            end
            mkdir -p (dirname $fav_file)
            echo $palette >> $fav_file

            set_color $hexes[1]; echo -n "★ "
            set_color $hexes[2]; echo -n "★ "
            set_color $hexes[3]; echo -n "★ "
            set_color $hexes[4]; echo -n "★ "
            set_color $hexes[5]; echo -n "★ "
            set_color $hexes[6]; echo -n "★"
            set_color normal
            echo "  added to favorites! ("(count (cat $fav_file))" total)"

        case explore browse
            set --local n 5
            if test (count $argv) -ge 2; and string match -qr '^\d+$' -- "$argv[2]"
                set n $argv[2]
            end

            echo ""
            for i in (seq $n)
                set --local p (_gen_rocket_palette)
                printf "%3d. " $i
                set_color $p[1]; echo -n "★ "
                set_color $p[2]; echo -n "★ "
                set_color $p[3]; echo -n "★ "
                set_color $p[4]; echo -n "★ "
                set_color $p[5]; echo -n "★ "
                set_color $p[6]; echo -n "★"
                set_color normal
                echo "  $p[1] $p[2] $p[3] $p[4] $p[5] $p[6]"
            end
            echo ""
            echo "  star show <h1>..<h6>   preview a full rocket"
            echo "  star add  <h1>..<h6>   save directly to favorites"

        case weight w
            _rkt_load_settings

            if test (count $argv) -eq 1
                echo "Favorite weight: $_rkt_favorite_weight%"
                echo ""
                echo "  Roughly $_rkt_favorite_weight out of every 100 new shells will roll"
                echo "  a saved favorite. The rest generate fresh palettes."
                echo ""
                echo "Usage: star weight <0-100>"
                echo "  0    = never use favorites (always fresh)"
                echo "  100  = always use favorites"
                return 0
            end

            set --local n $argv[2]
            if not string match -qr '^\d+$' -- "$n"
                echo "Weight must be a number between 0 and 100."
                return 1
            end
            if test $n -lt 0; or test $n -gt 100
                echo "Weight must be between 0 and 100."
                return 1
            end
            set --global _rkt_favorite_weight $n
            _rkt_save_settings
            echo "Set favorite weight to $n%."

        case color colors
            _rkt_load_settings

            if test (count $argv) -eq 1
                if not set --query _rkt_bdy
                    echo "No active palette. Open a new tab first."
                    return 1
                end
                echo ""
                set_color $_rkt_tip; echo -n "  ★ Porthole      "; set_color normal; echo "  $_rkt_tip"
                set_color $_rkt_win; echo -n "  ★ Window        "; set_color normal; echo "  $_rkt_win"
                set_color $_rkt_bdy; echo -n "  ★ Body          "; set_color normal; echo "  $_rkt_bdy"
                set_color $_rkt_top; echo -n "  ★ Top           "; set_color normal; echo "  $_rkt_top"
                set_color $_rkt_sds; echo -n "  ★ Window-sides  "; set_color normal; echo "  $_rkt_sds"
                set_color $_rkt_flm; echo -n "  ★ Flame         "; set_color normal; echo "  $_rkt_flm"
                echo ""
                _star_preview_palette $_rkt_tip $_rkt_win $_rkt_bdy $_rkt_top $_rkt_sds $_rkt_flm
                return 0
            end

            if test "$argv[2]" = reset
                set --global _rkt_random_star_mode white
                set --global _rkt_favorite_star_mode gold
                set --global _rkt_terminal_theme dark
                _rkt_save_settings
                echo "Reset: theme=dark, random=white, favorite=gold"
                return 0
            end

            if test (count $argv) -lt 3
                echo "Usage: star color <theme|random|favorite> <value>"
                return 1
            end

            set --local ctx $argv[2]
            set --local val $argv[3]

            switch $ctx
                case theme
                    if not contains -- $val dark light
                        echo "Theme must be 'dark' or 'light'."
                        return 1
                    end
                    set --global _rkt_terminal_theme $val
                    _rkt_save_settings
                    echo "Set terminal theme to $val."
                case random
                    if not contains -- $val white gold neon
                        echo "Random mode must be 'white' or 'neon'."
                        return 1
                    end
                    set --global _rkt_random_star_mode $val
                    _rkt_save_settings
                    if test "$val" = gold
                        echo "Set random-palette stars to $val. :)"
                    else
                        echo "Set random-palette stars to $val."
                    end
                case favorite favorites fav
                    if not contains -- $val white gold neon
                        echo "Favorite mode must be 'gold' or 'neon'."
                        return 1
                    end
                    set --global _rkt_favorite_star_mode $val
                    _rkt_save_settings
                    if test "$val" = white
                        echo "Set favorite-palette stars to $val. :)"
                    else
                        echo "Set favorite-palette stars to $val."
                    end
                case '*'
                    echo "Context must be 'theme', 'random', or 'favorite'."
                    return 1
            end

        case help -h --help
            _rkt_load_settings
            echo "star                          save current palette to favorites"
            echo "star list                     show all favorites"
            echo "star remove N                 delete favorite #N"
            echo ""
            echo "star history                  show last 20 palettes (most recent first)"
            echo "star history N                save palette #N from history to favorites"
            echo "star history clear            wipe history"
            echo ""
            echo "star show H1..H6              preview a custom palette (mini rocket)"
            echo "star add  H1..H6              add a custom palette directly to favorites"
            echo "star explore [N]              browse N random palettes (default 5)"
            echo ""
            echo "star color                    show current palette preview"
            echo -n "star color theme <d|l>        terminal theme: "
            _rkt_print_option $_rkt_terminal_theme dark light
            echo
            echo -n "star color random <mode>      random-palette stars: "
            _rkt_print_option $_rkt_random_star_mode white neon
            echo
            echo -n "star color favorite <mode>    favorite-palette stars: "
            _rkt_print_option $_rkt_favorite_star_mode gold neon
            echo
            echo -n "star weight <0-100>           ratio of favorites to random rockets. Currently: "
            set_color --bold --italics
            echo -n "$_rkt_favorite_weight%"
            set_color normal
            echo
            echo "star color reset              restore defaults"
            echo ""
            echo "  Favorites: $fav_file"
            echo "  History:   $hist_file (last 100 launches)"
            echo "  Settings:  ~/.config/fish/rocket_settings.fish"

        case '*'
            echo "Unknown subcommand: $argv[1]"
            echo "Try: star, star list, star show, star add, star explore, star color, star weight, star help"
            return 1
    end
end


function _rkt_hw_info --description "Load OS/CPU/RAM into globals; cache to disk, refresh once a day"
    set --local cache ~/.config/fish/rocket_hw_cache.fish

    # Fresh cache (< 24h old)? Just source it. Otherwise regenerate.
    if test -f $cache; and test (count (find $cache -mmin -1440 2>/dev/null)) -gt 0
        source $cache
        return
    end

    mkdir -p (dirname $cache)
    set --local os_type (uname -s)
    set --local os_str (uname -sm)
    set --local cpu_str ""
    set --local mem_str ""

    if test "$os_type" = "Darwin"
        # One system_profiler call serves both CPU and memory parsing
        set --local hw_info (system_profiler SPHardwareDataType 2>/dev/null)
        set --local chip_name (sysctl -n machdep.cpu.brand_string)
        set --local cores_n (printf '%s\n' $hw_info | grep "Total Number of Cores" | cut -d ":" -f2 | string trim)
        set cpu_str "$chip_name, $cores_n"
        set mem_str (printf '%s\n' $hw_info | grep "Memory:" | cut -d ":" -f 2 | tr -d " ")
    else if test "$os_type" = "Linux"
        set --local procs_n (grep -c "^processor" /proc/cpuinfo)
        set --local cores_n (grep "cpu cores" /proc/cpuinfo | head -1 | cut -d ":" -f2 | tr -d " ")
        set --local cpu_type (grep "model name" /proc/cpuinfo | head -1 | cut -d ":" -f2)
        set cpu_str "$procs_n processors, $cores_n cores, $cpu_type"
        set mem_str (free -h | grep "Mem" | cut -d " " -f 11)
    end

    printf 'set -g _rkt_os %s\n' (string escape -- "$os_str")  > $cache
    printf 'set -g _rkt_cpu %s\n' (string escape -- "$cpu_str") >> $cache
    printf 'set -g _rkt_mem %s\n' (string escape -- "$mem_str") >> $cache

    source $cache
end


function _rkt_net_info --description "Load IP/gateway into globals; cache 5min to skip ifconfig+netstat on rapid shell opens"
    set --local cache ~/.config/fish/rocket_net_cache.fish

    # Fresh cache (< 5min old)? Just source it.
    if test -f $cache; and test (count (find $cache -mmin -5 2>/dev/null)) -gt 0
        source $cache
        return
    end

    mkdir -p (dirname $cache)
    set --local os_type (uname -s)
    set --local ip ""
    set --local gw ""

    if test "$os_type" = "Darwin"
        set ip (ifconfig | grep -v "127.0.0.1" | grep "inet " | head -1 | cut -d " " -f2)
        set gw (netstat -nr | grep -E "default.*UGSc" | cut -d " " -f13)
    else if test "$os_type" = "Linux"
        set ip (ip address show | grep -E "inet .* brd .* dynamic" | cut -d " " -f6)
        set gw (ip route | grep default | cut -d " " -f3)
    end

    printf 'set -g _rkt_ip %s\n' (string escape -- "$ip") > $cache
    printf 'set -g _rkt_gw %s\n' (string escape -- "$gw") >> $cache

    source $cache
end


function fish_greeting -d "Greeting message on shell session start up"

    _rkt_prng_seed
    _rkt_hw_info
    _rkt_net_info
    _rkt_load_settings

    set --local colors (_rocket_pick_palette)
    set --global _rkt_tip $colors[1]
    set --global _rkt_win $colors[2]
    set --global _rkt_bdy $colors[3]
    set --global _rkt_top $colors[4]
    set --global _rkt_sds $colors[5]
    set --global _rkt_flm $colors[6]
    set --global _RKT_PALETTE_BYTES \
        (math --scale=0 "0x"(string sub --start 1 --length 2 -- $_rkt_tip)) \
        (math --scale=0 "0x"(string sub --start 3 --length 2 -- $_rkt_tip)) \
        (math --scale=0 "0x"(string sub --start 5 --length 2 -- $_rkt_tip)) \
        (math --scale=0 "0x"(string sub --start 1 --length 2 -- $_rkt_win)) \
        (math --scale=0 "0x"(string sub --start 3 --length 2 -- $_rkt_win)) \
        (math --scale=0 "0x"(string sub --start 5 --length 2 -- $_rkt_win)) \
        (math --scale=0 "0x"(string sub --start 1 --length 2 -- $_rkt_bdy)) \
        (math --scale=0 "0x"(string sub --start 3 --length 2 -- $_rkt_bdy)) \
        (math --scale=0 "0x"(string sub --start 5 --length 2 -- $_rkt_bdy)) \
        (math --scale=0 "0x"(string sub --start 1 --length 2 -- $_rkt_top)) \
        (math --scale=0 "0x"(string sub --start 3 --length 2 -- $_rkt_top)) \
        (math --scale=0 "0x"(string sub --start 5 --length 2 -- $_rkt_top)) \
        (math --scale=0 "0x"(string sub --start 1 --length 2 -- $_rkt_sds)) \
        (math --scale=0 "0x"(string sub --start 3 --length 2 -- $_rkt_sds)) \
        (math --scale=0 "0x"(string sub --start 5 --length 2 -- $_rkt_sds)) \
        (math --scale=0 "0x"(string sub --start 1 --length 2 -- $_rkt_flm)) \
        (math --scale=0 "0x"(string sub --start 3 --length 2 -- $_rkt_flm)) \
        (math --scale=0 "0x"(string sub --start 5 --length 2 -- $_rkt_flm))
    set --global _rocket_stars (_compute_star_positions)

    if _palette_is_favorite
        set --global _rkt_star_mode $_rkt_favorite_star_mode
    else
        set --global _rkt_star_mode $_rkt_random_star_mode
    end

    echo ""

    _render_row 0 "                  " "                  "
    echo

    _render_row 1 "        |         " "        b         "
    echo -en " "(welcome_message)"\n"

    _render_row 2 "       / \\        " "       t t        "
    echo

    _render_row 3 "      / _ \\       " "      t t t       "
    echo -en " "(show_date_info)"\n"

    _render_row 4 "     |.o '.|      " "     swp wws      "
    echo

    _render_row 5 "     |'._.'|      " "     swwwwws      "
    echo -en " Space Vessel:\n"

    _render_row 6 "     |     |      " "     b     b      "
    echo -en " "(show_os_info)"\n"

    _render_row 7 "   ,'|  |  |`.    " "   ssb  b  bss    "
    echo -en " "(show_cpu_info)"\n"

    _render_row 8 "  /  |  |  |  \\   " "  s  b  b  b  s   "
    echo -en " "(show_mem_info)"\n"

    _render_row 9 "  |,-'--|--'-.|   " "  bsssttbttsssb   "
    echo -en " "(show_net_info)"\n"

    _render_flame
    echo

    _render_row 11 "                  " "                  "
    echo

    echo
    set_color grey
    echo "Have a Nice Trip!"
    set_color normal
end


function welcome_message -d "Say welcome to user"
    set -l cols (_rkt_cols)
    set -l prefix_len 19
    set -l available (math "$cols - $prefix_len - 2")
    set -l value "Welcome Aboard, Captain "(whoami)"!"

    if test (string length -- "$value") -gt $available
        echo -en (string sub -l (math "$available - 1") -- "$value")…
    else
        echo -en "Welcome Aboard, "
        set_color $_rkt_bdy
        echo -en "Captain "
        set_color FFF
        echo -en (whoami) "!"
    end
    set_color normal
end


function show_date_info -d "Prints information about date"
    set -l cols (_rkt_cols)
    set -l prefix_len 19
    set -l available (math "$cols - $prefix_len - 2")
    set --local up_time (uptime | awk -F '(up |,)' '{print $2}' | sed 's/^ *//g')
    set -l value "Today is "(date +%Y.%m.%d)", we are up and running for $up_time."

    if test (string length -- "$value") -gt $available
        echo -en (string sub -l (math "$available - 1") -- "$value")…
    else
        echo -en "Today is "
        set_color cyan
        echo -en (date +%Y.%m.%d)
        set_color normal
        echo -en ", we are up and running for "
        set_color cyan
        echo -en "$up_time"
        set_color normal
        echo -en "."
    end
    set_color normal
end


function _rkt_cols
    tput cols 2>/dev/null; or echo 80
end

function show_os_info -d "Prints operating system info"
    set -l cols (_rkt_cols)
    set -l prefix_len 28
    set -l available (math "$cols - $prefix_len - 2")
    set -l value $_rkt_os

    set_color yellow
    echo -en "\tOS: "
    set_color 0F0
    if test (string length -- "$value") -gt $available
        echo -en (string sub -l (math "$available - 1") -- "$value")…
    else
        echo -en $value
    end
    set_color normal
end


function show_cpu_info -d "Prints information about cpu"
    set -l cols (_rkt_cols)
    set -l prefix_len 29
    set -l available (math "$cols - $prefix_len - 2")
    set -l value $_rkt_cpu

    set_color yellow
    echo -en "\tCPU: "
    set_color 0F0
    if test (string length -- "$value") -gt $available
        echo -en (string sub -l (math "$available - 1") -- "$value")…
    else
        echo -en $value
    end
    set_color normal
end


function show_mem_info -d "Prints memory information"
    set -l cols (_rkt_cols)
    set -l prefix_len 32
    set -l available (math "$cols - $prefix_len - 2")
    set -l value $_rkt_mem

    set_color yellow
    echo -en "\tMemory: "
    set_color 0F0
    if test (string length -- "$value") -gt $available
        echo -en (string sub -l (math "$available - 1") -- "$value")…
    else
        echo -en $value
    end
    set_color normal
end


function show_net_info -d "Prints information about network"
    set -l cols (_rkt_cols)
    set -l prefix_len 29
    set -l available (math "$cols - $prefix_len - 2")
    set -l value "IP Address: $_rkt_ip, Default Gateway: $_rkt_gw"

    set_color yellow
    echo -en "\tNet: "
    set_color 0F0
    if test (string length -- "$value") -gt $available
        echo -en (string sub -l (math "$available - 1") -- "$value")…
    else
        echo -en $value
    end
    set_color normal
end
