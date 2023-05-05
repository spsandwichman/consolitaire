#   ╭──╮
#   │consolitaire by sandwichman - https://sandwichman.dev/github/consolitaire
#   ╰──╯

import std/[os, sequtils, random, strutils]
import illwill
#randomize()

type
    Suit = enum
        Spades, Hearts, Clubs, Diamonds
    Card = object
        suit: Suit
        rank: int   #1 = ace, 11 = jack, 12 = queen, 13 = king
        visible: bool

const
    STOCK = 0
    WASTE = 1
    FOUNDATIONS = 2
    TABLEAU = 6

var 
    board: array[13, seq[Card]] # 0 = stock, 1 = waste, 2-5 is foundations, 6-12 is tableau

    select_pos = 0
    select_len = 1
    selection_buffer: seq[Card]

    color_hidden = fgBlue
    color_empty = fgCyan
    color_select = fgYellow
    use_ascii_suits = false
    show_help = false
    in_place_mode = false
    last_select_pos = 0
    last_select_len = 1
    min_height = 28
    min_width = 87
    bottom_text = "press `h` to toggle help - press ESC to quit"  # lmao

proc color(card: Card): int = (if card.suit == Spades or card.suit == Clubs: 0 else: 1)

proc pop_single(source, dest: var seq[Card]) =
    dest.add source[source.high]
    source.delete(source.high)

proc pop_multiple(source, dest: var seq[Card], amount: int) =
    dest = concat(dest, source[(source.high-amount+1)..source.high])
    source.delete((source.high-amount+1)..source.high)

proc pop_multiple_in_order(source, dest: var seq[Card], amount: int) =
    var i = amount
    while i > 0:
        pop_single(source, dest)
        i -= 1

proc write_card_template(tb: var TerminalBuffer, x, y: int) =
    tb.write(x, y,   "╭─────────╮")
    tb.write(x, y+1, "│         │")
    tb.write(x, y+2, "│         │")
    tb.write(x, y+3, "│         │")
    tb.write(x, y+4, "│         │")
    tb.write(x, y+5, "│         │")
    tb.write(x, y+6, "╰─────────╯")

proc write_stock(tb: var TerminalBuffer, x, y: int, stack: seq[Card]) =

    if stack.len != 0:
        tb.setForegroundColor(color_hidden)
    else:
        tb.setForegroundColor(color_empty)
    
    tb.write_card_template(x,y)
    tb.setForegroundColor(fgWhite)
    tb.write(x+3,y+2, "press" )
    tb.write(x+2,y+3, "\'e\' to" )
    if stack.len != 0:
        tb.write(x+3,y+4, "draw" )
    else:
        tb.write(x+2,y+4, "restock")

proc write_empty(tb: var TerminalBuffer, x, y: int) =
    tb.setForegroundColor(color_empty)
    
    tb.write_card_template(x,y)
    tb.write(x+5, y+3, "X")

proc write_card(tb: var TerminalBuffer, x, y: int, card: Card, dataOnLeft: bool) =

    var suitstr = ""
    var rankstr = ""

    case card.suit
    of Spades:
        suitstr = if use_ascii_suits: "S" else: "♠"
        tb.setForegroundColor(fgWhite)
    of Hearts:
        suitstr = if use_ascii_suits: "H" else: "♥"
        tb.setForegroundColor(fgRed)
    of Clubs:
        suitstr = if use_ascii_suits: "C" else: "♣"
        tb.setForegroundColor(fgWhite)
    of Diamonds:
        suitstr = if use_ascii_suits: "D" else: "♦"
        tb.setForegroundColor(fgRed)
    
    case card.rank
    of 1:
        rankstr = "A"
    of 11:
        rankstr = "J"
    of 12:
        rankstr = "Q"
    of 13:
        rankstr = "K"
    else:
        rankstr = $card.rank

    if (not card.visible):
        tb.setForegroundColor(color_hidden)
    
    tb.write_card_template(x,y)

    if not card.visible: return

    if dataOnLeft:
        tb.write(x, y+1, suitstr)
        tb.write(x, y+2, rankstr)
    else:
        tb.write(x+1, y, " " & suitstr & " " & rankstr & " ")

proc render_everything(tb: var TerminalBuffer, bx, by: int) = # EVERYTHINGGGGGGGG

    let bottom_text_offset = (terminalWidth() - (bottom_text.len + 4)) div 2

    # draw text elements
    tb.setBackgroundColor(bgBlack)
    tb.setForegroundColor(fgCyan)
    tb.write(bottom_text_offset, terminalHeight()-1, "~ " & spaces(bottom_text.len) & " ~")
    tb.setForegroundColor(fgWhite)
    tb.write(bottom_text_offset+2, terminalHeight()-1, bottom_text)

    #draw help
    if show_help:
        tb.write(bottom_text_offset+5, terminalHeight()-5, " wasd  move cursor around the board")
        tb.write(bottom_text_offset+5, terminalHeight()-4, "space  pick up / place cards")
        tb.write(bottom_text_offset+5, terminalHeight()-3, "    r  toggle suit chars / letters")

    #draw selection box
    var selbox_x = 0
    var selbox_y = 1
    var selbox_width = 12
    case select_pos          # writing this late and cant be fucked to optimize it - do later probably
        of 0:
            selbox_x = select_pos * 12
        of 1:
            selbox_x = select_pos * 12
            selbox_width += (min(max(board[WASTE].len,1),3)-1)*3
        of 2,3,4,5:
            selbox_x = select_pos * 12 + 12
        of 6,7,8,9,10,11,12:
            selbox_x = (select_pos-6) * 12
            selbox_y = board[select_pos].len - select_len + 8
            if board[select_pos].len == 0: selbox_y += 1
        else: discard
    
    if not in_place_mode:
        tb.setForegroundColor(color_select)
        tb.drawRect(bx+selbox_x, by+selbox_y, bx+selbox_x+selbox_width, by+selbox_y+5+select_len)

    # draw stock
    tb.write_stock(bx+1, by+1, board[STOCK])

    # draw waste
    if board[WASTE].len == 0:
        tb.write_empty(bx+13,by+1)
    else:
        let topThree = board[WASTE][(max(0, board[WASTE].high-2))..(board[WASTE].high)]     # beautiful monstrosity - adaptive retrieve top three of the waste stack
        for c in 0..topThree.high:
            tb.write_card(bx+13+(c*3),by+1, topThree[c], true)
    
    # draw foundations
    for i in 0..3:
        if board[FOUNDATIONS+i].len == 0:
            tb.write_empty(bx+(i*12)+37, by+1)
        else:
            tb.write_card(bx+(i*12)+37, by+1, board[FOUNDATIONS+i][board[FOUNDATIONS+i].high], false)
        
    # draw tableau
    for i in 0..6:
        if board[TABLEAU+i].len == 0:
            tb.write_empty(bx+(i*12)+1, by+8)

        for j in 0..board[TABLEAU+i].high:
            tb.write_card(bx+(i*12)+1, by+(j)+8, board[TABLEAU+i][j], false)
    
    # draw selection stack
    if in_place_mode:
        tb.setForegroundColor(color_select)
        tb.write(bx+selbox_x+5, by+selbox_y+3, "^^^")
        for i in 0..selection_buffer.high:
            tb.write_card(bx+selbox_x+1, by+selbox_y+i+5, selection_buffer[i], false)

proc cannot_extend_selection(): bool = 
    return board[select_pos].len < 2 or board[select_pos].len == select_len or (not board[select_pos][board[select_pos].high-select_len].visible)

proc can_place_selection(): bool =
    # run a fuck ton of tests to see if a placement is legal
    if select_pos <= WASTE: return false                    # cant place on waste or stock
    if select_pos >= FOUNDATIONS and select_pos < TABLEAU:  # inside foundations?
        if selection_buffer.len != 1: return false          # can only place on foundations if placing one card
        if board[select_pos].len == 0 and selection_buffer[0].rank != 1: return false   # cant place anything but ace on empty foundation
        if board[select_pos].len != 0 and selection_buffer[0].suit != board[select_pos][0].suit: return false     # cant place a card that does not match suit
        if board[select_pos].len != 0 and selection_buffer[0].rank != (board[select_pos][board[select_pos].high].rank+1): return false    # cant place out of order
    else:                                                   # inside tableau?
        if board[select_pos].len == 0:                      # is placement stack empty?
            if selection_buffer[0].rank != 13: return false # cant place anything but king on empty tableau
        else:
            if selection_buffer[0].color == board[select_pos][board[select_pos].high].color: return false   # cant place on same color
            if selection_buffer[0].rank != board[select_pos][board[select_pos].high].rank-1: return false    # cant place out of order

    return true

proc exit_proc() {.noconv.} =
    illwillDeinit()
    showCursor()
    quit(0)

proc main() =
    illwillInit(fullscreen = true)
    setControlCHook(exit_proc)
    hideCursor()

    # construct and shuffle deck
    for s in [Spades, Hearts, Clubs, Diamonds]:
        for r in 1..13:
            board[STOCK].add Card(suit: s, rank: r, visible: false)        
    shuffle(board[STOCK])

    # spread to tableau
    for i in 0..6:
        for j in 0..i:
            pop_single(board[STOCK], board[TABLEAU+i])

    # main loop
    while true:
        var tb = newTerminalBuffer(terminalWidth(), terminalHeight())
        tb.setBackgroundColor(bgBlack)
        tb.clear()

        # block if terminal is not the right size
        if terminalWidth() < min_width or terminalHeight() < min_height:
            var key = getKey()
            case key
                of Key.Escape: exit_proc()
                else: discard
            
            tb.setForegroundColor(fgRed)
            tb.drawRect(0, 0, terminalWidth()-1, terminalHeight()-1)
            tb.setForegroundColor(fgWhite)
            tb.write(1, 1, "terminal window is (" & $terminalWidth() & ", " & $terminalHeight() & "), must be (>" & $min_width & ", >" & $min_height & ").")
            tb.write(1, 2, "please resize your terminal or press ESC to quit.")
            tb.display()
            continue

        # handle input
        var key = getKey()
        case key
            of Key.Escape: exit_proc()
            of Key.R, Key.ShiftR: 
                use_ascii_suits = not use_ascii_suits
            of Key.H, Key.ShiftH: 
                show_help = not show_help
                # for i in 0..6:
                #     if board[TABLEAU+i].len == 0: continue
                #     for card in 0..board[TABLEAU+i].high:
                #         board[TABLEAU+i][card].visible = true
            of Key.E, Key.ShiftE:
                if board[STOCK].len != 0:
                    pop_single(board[STOCK], board[WASTE])
                    board[WASTE][board[WASTE].high].visible = true
                else:
                    pop_multiple_in_order(board[WASTE], board[STOCK], board[WASTE].len)
            of Key.A, Key.ShiftA, Key.Left:
                if select_pos == 0: select_pos = 6
                elif select_pos == 6: select_pos = 13
                select_pos -= 1
                select_len = 1

            of Key.D, Key.ShiftD, Key.Right:
                if select_pos == 5: select_pos = -1
                elif select_pos == 12: select_pos = 5
                select_pos += 1
                select_len = 1
            of Key.W, Key.ShiftW, Key.Up:
                if select_pos < TABLEAU:
                    if select_pos > 1:   # adjust for the gap between waste and foundations
                        select_pos += 1
                    select_pos += TABLEAU
                else:
                    if cannot_extend_selection() or in_place_mode:
                        if select_pos < 8:
                            select_pos -= 6
                        elif select_pos == 8:
                            select_pos = 1
                        else:
                            select_pos -= 7
                        select_len = 1
                    else:
                        select_len += 1
            of Key.S, Key.ShiftS, Key.Down:
                if select_pos < TABLEAU:
                    if select_pos > 1:   # adjust for the gap between waste and foundations
                        select_pos += 1
                    select_pos += 6
                else:
                    if select_len < 2:
                        if select_pos < 8:
                            select_pos -= 6
                        elif select_pos == 8:
                            select_pos = 1
                        else:
                            select_pos -= 7
                        select_len = 1
                    else:
                        select_len -= 1
            of Key.Space:
                if not in_place_mode:
                    if board[select_pos].len > 0 and select_pos != 0:
                        last_select_pos = select_pos
                        last_select_len = select_len
                        pop_multiple(board[select_pos], selection_buffer, select_len)
                        in_place_mode = true
                        select_len = 1
                else:
                    if can_place_selection():
                        pop_multiple(selection_buffer, board[select_pos], selection_buffer.len):
                    else:
                        pop_multiple(selection_buffer, board[last_select_pos], selection_buffer.len)
                        select_pos = last_select_pos
                        select_len = last_select_len
                    in_place_mode = false
            else: discard

        #unhide top cards in tableau decks
        for i in 0..6:
            if board[TABLEAU+i].len == 0 or in_place_mode: continue
            board[TABLEAU+i][board[TABLEAU+i].high].visible = true

        tb.render_everything((terminalWidth()-min_width-2) div 2,0)
        tb.display()
        sleep(20)   # slows the program down so it doesn't re-render as much when there isn't anything going on - no more 17% cpu usage

main()