#   ╭───────────╮
#   │ solitaire │ by sandwichman - https://sandwichman.dev/github/solitaire
#   ╰───────────╯
#
#   (uHHH technically it's kLoNdiKe uhHHHHHHhh)

import std/[os, sequtils, random, strutils]
import illwill
randomize()

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

    selectPos = 0
    selectLen = 1
    selectionBuffer: seq[Card]

    hiddenColor = fgBlue
    emptyColor = fgCyan
    selectionColor = fgYellow
    useSuitLetters = false
    showHelp = false
    InPlaceMode = false
    lastSelectPos = 0
    lastSelectLen = 1
    minHeight = 28
    minWidth = 87
    bottomText = "press H to toggle help - press ESC to quit"   # lmao

proc color(card: Card): int = (if card.suit == Spades or card.suit == Clubs: 0 else: 1)

proc popSingle(srcStack, dstStack: var seq[Card]) =
    dstStack.add srcStack[srcStack.high]
    srcStack.delete(srcStack.high)

proc popMultiple(srcStack, dstStack: var seq[Card], cardAmount: int) =
    dstStack = concat(dstStack, srcStack[(srcStack.high-cardAmount+1)..srcStack.high])
    srcStack.delete((srcStack.high-cardAmount+1)..srcStack.high)

proc popMultipleInOrder(srcStack, dstStack: var seq[Card], cardAmount: int) =
    var i = cardAmount
    while i > 0:
        popSingle(srcStack, dstStack)
        i -= 1

proc writeCardTemplate(tb: var TerminalBuffer, x, y: int) =
    tb.write(x, y,   "╭─────────╮")
    tb.write(x, y+1, "│         │")
    tb.write(x, y+2, "│         │")
    tb.write(x, y+3, "│         │")
    tb.write(x, y+4, "│         │")
    tb.write(x, y+5, "│         │")
    tb.write(x, y+6, "╰─────────╯")

proc writeStock(tb: var TerminalBuffer, x, y: int, stack: seq[Card]) =

    if stack.len != 0:
        tb.setForegroundColor(hiddenColor)
    else:
        tb.setForegroundColor(emptyColor)
    
    tb.writeCardTemplate(x,y)
    tb.setForegroundColor(fgWhite)
    tb.write(x+3,y+2, "press" )
    tb.write(x+2,y+3, "\'e\' to" )
    if stack.len != 0:
        tb.write(x+3,y+4, "draw" )
    else:
        tb.write(x+2,y+4, "restock")

proc writeEmpty(tb: var TerminalBuffer, x, y: int) =
    tb.setForegroundColor(emptyColor)
    
    tb.writeCardTemplate(x,y)
    tb.write(x+5, y+3, "X")

proc writeCard(tb: var TerminalBuffer, x, y: int, card: Card, dataOnLeft: bool) =

    var suitstr = ""
    var rankstr = ""

    case card.suit
    of Spades:
        suitstr = if useSuitLetters: "S" else: "♠"
        tb.setForegroundColor(fgWhite)
    of Hearts:
        suitstr = if useSuitLetters: "H" else: "♥"
        tb.setForegroundColor(fgRed)
    of Clubs:
        suitstr = if useSuitLetters: "C" else: "♣"
        tb.setForegroundColor(fgWhite)
    of Diamonds:
        suitstr = if useSuitLetters: "D" else: "♦"
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
        tb.setForegroundColor(hiddenColor)
    
    #
    tb.writeCardTemplate(x,y)

    if not card.visible: return

    if dataOnLeft:
        tb.write(x, y+1, suitstr)
        tb.write(x, y+2, rankstr)
    else:
        tb.write(x+1, y, " " & suitstr & " " & rankstr & " ")

proc renderEverything(tb: var TerminalBuffer, bx, by: int) = # EVERYTHINGGGGGGGG

    let bottomTextOffset = (terminalWidth() - (bottomText.len + 4)) div 2
    #let bottomTextOffset = (85 - (bottomText.len + 4)) div 2

    # draw text elements
    tb.setBackgroundColor(bgBlack)
    tb.setForegroundColor(fgCyan)
    tb.write(bottomTextOffset, terminalHeight()-1, "~ " & spaces(bottomText.len) & " ~")
    tb.setForegroundColor(fgWhite)
    tb.write(bottomTextOffset+2, terminalHeight()-1, bottomText)

    #draw help
    if showHelp:
        tb.write(bottomTextOffset+5, terminalHeight()-5, " WASD  move cursor around the board")
        tb.write(bottomTextOffset+5, terminalHeight()-4, "Space  pick up / place cards")
        tb.write(bottomTextOffset+5, terminalHeight()-3, "    R  toggle suit chars / letters")

    #draw selection box
    var selboxX = 0
    var selboxY = 1
    var selboxWidth = 12
    case selectPos                          # writing this late and cant be fucked to optimize it - do later probably
        of 0:
            selboxX = selectPos * 12
        of 1:
            selboxX = selectPos * 12
            selboxWidth += (min(max(board[WASTE].len,1),3)-1)*3
        of 2,3,4,5:
            selboxX = selectPos * 12 + 12
        of 6,7,8,9,10,11,12:
            selboxX = (selectPos-6) * 12
            selboxY = board[selectPos].len - selectLen + 8
            if board[selectPos].len == 0: selBoxY += 1
        else: discard
    
    if not InPlaceMode:
        tb.setForegroundColor(selectionColor)
        tb.drawRect(bx+selboxX, by+selboxY, bx+selboxX+selboxWidth, by+selboxY+5+selectLen)

    # draw stock
    tb.writeStock(bx+1, by+1, board[STOCK])

    # draw waste
    if board[WASTE].len == 0:
        tb.writeEmpty(bx+13,by+1)
    else:
        let topThree = board[WASTE][(max(0, board[WASTE].high-2))..(board[WASTE].high)]     # beautiful monstrosity
        for c in 0..topThree.high:
            tb.writeCard(bx+13+(c*3),by+1, topThree[c], true)
    
    # draw foundations
    for i in 0..3:
        if board[FOUNDATIONS+i].len == 0:
            tb.writeEmpty(bx+(i*12)+37, by+1)
        else:
            tb.writeCard(bx+(i*12)+37, by+1, board[FOUNDATIONS+i][board[FOUNDATIONS+i].high], false)
        
    # draw tableau
    for i in 0..6:
        if board[TABLEAU+i].len == 0:
            tb.writeEmpty(bx+(i*12)+1, by+8)

        for j in 0..board[TABLEAU+i].high:
            tb.writeCard(bx+(i*12)+1, by+(j)+8, board[TABLEAU+i][j], false)
    
    # draw selection stack
    if InPlaceMode:
        tb.setForegroundColor(selectionColor)
        tb.write(bx+selboxX+5, by+selboxY+3, "^^^")
        for i in 0..selectionBuffer.high:
            tb.writeCard(bx+selboxX+1, by+selboxY+i+5, selectionBuffer[i], false)

proc cannot_extend_selection(): bool = 
    return board[selectPos].len < 2 or board[selectPos].len == selectLen or (not board[selectPos][board[selectPos].high-selectLen].visible)

proc can_place_selection(): bool =
    # run a fuck ton of tests to see if a placement is legal
    if selectPos <= WASTE: return false                     # cant place on waste or stock
    if selectPos >= FOUNDATIONS and selectPos < TABLEAU:    # inside foundations?
        if selectionBuffer.len != 1: return false           # can only place on foundations if placing one card
        if board[selectPos].len == 0 and selectionBuffer[0].rank != 1: return false # cant place anything but ace on empty foundation
        if board[selectPos].len != 0 and (selectionBuffer[0].suit != board[selectPos][0].suit): return false    # cant place a card that does not match suit
    else:                                                   # inside tableau?
        if board[selectPos].len == 0:                       # is placement stack empty?
            if selectionBuffer[0].rank != 13: return false  # cant place anything but king on empty tableau
        else:
            if selectionBuffer[0].rank != board[selectPos][board[selectPos].high].rank-1: return false # cant place out of order
            if selectionBuffer[0].color == board[selectPos][board[selectPos].high].color: return false # cant place on same color

    return true

proc exitProc() {.noconv.} =
    illwillDeinit()
    showCursor()
    quit(0)

proc main() =
    illwillInit(fullscreen=true)
    setControlCHook(exitProc)
    hideCursor()

    # construct and shuffle deck
    for s in [Spades, Hearts, Clubs, Diamonds]:
        for r in 1..13:
            board[STOCK].add Card(suit: s, rank: r, visible: false)        
    shuffle(board[STOCK])

    # spread to tableau
    for i in 0..6:
        for j in 0..i:
            popSingle(board[STOCK], board[TABLEAU+i])

    # main loop
    while true:
        var tb = newTerminalBuffer(terminalWidth(), terminalHeight())
        tb.setBackgroundColor(bgBlack)
        tb.clear()

        # block if terminal is not the right size
        if terminalWidth() < minWidth or terminalHeight() < minHeight:
            var key = getKey()
            case key
                of Key.Escape: exitProc()
                else: discard
            
            tb.setForegroundColor(fgRed)
            tb.drawRect(0, 0, terminalWidth()-1, terminalHeight()-1)
            tb.setForegroundColor(fgWhite)
            tb.write(1, 1, "terminal window is (" & $terminalWidth() & ", " & $terminalHeight() & "), must be (>" & $minWidth & ", >" & $minHeight & ").")
            tb.write(1, 2, "please resize your terminal or press ESC to quit.")
            tb.display()
            continue

        # handle input
        var key = getKey()
        case key
            of Key.Escape: exitProc()
            of Key.R: 
                useSuitLetters = not useSuitLetters
            of Key.H: 
                showHelp = not showHelp
                # for i in 0..6:
                #     if board[TABLEAU+i].len == 0: continue
                #     for card in 0..board[TABLEAU+i].high:
                #         board[TABLEAU+i][card].visible = true
            of Key.E:
                if board[STOCK].len != 0:
                    popSingle(board[STOCK], board[WASTE])
                    board[WASTE][board[WASTE].high].visible = true
                else:
                    popMultipleInOrder(board[WASTE], board[STOCK], board[WASTE].len)
            of Key.A:
                if selectPos == 0: selectPos = 6
                elif selectPos == 6: selectPos = 13
                selectPos -= 1
                selectLen = 1

            of Key.D:
                if selectPos == 5: selectPos = -1
                elif selectPos == 12: selectPos = 5
                selectPos += 1
                selectLen = 1
            of Key.W:
                if selectPos < TABLEAU:
                    if selectPos > 1:   # adjust for the gap between waste and foundations
                        selectPos += 1
                    selectPos += TABLEAU
                else:
                    if cannot_extend_selection() or InPlaceMode:
                        if selectPos < 8:
                            selectPos -= 6
                        elif selectPos == 8:
                            selectPos = 1
                        else:
                            selectPos -= 7
                        selectLen = 1
                    else:
                        selectLen += 1
            of Key.S:
                if selectPos < TABLEAU:
                    if selectPos > 1:   # adjust for the gap between waste and foundations
                        selectPos += 1
                    selectPos += 6
                else:
                    if selectLen < 2:
                        if selectPos < 8:
                            selectPos -= 6
                        elif selectPos == 8:
                            selectPos = 1
                        else:
                            selectPos -= 7
                        selectLen = 1
                    else:
                        selectLen -= 1
            of Key.Space:
                if not InPlaceMode:
                    if board[selectPos].len > 0 and selectPos != 0:
                        lastSelectPos = selectPos
                        lastSelectLen = selectLen
                        popMultiple(board[selectPos], selectionBuffer, selectLen)
                        InPlaceMode = true
                        selectLen = 1
                else:
                    if can_place_selection():
                        popMultiple(selectionBuffer, board[selectPos], selectionBuffer.len):
                    else:
                        popMultiple(selectionBuffer, board[lastSelectPos], selectionBuffer.len)
                        selectPos = lastSelectPos
                        selectLen = lastSelectLen
                    InPlaceMode = false
            else: discard

        #unhide top cards in tableau decks
        for i in 0..6:
            if board[TABLEAU+i].len == 0 or InPlaceMode: continue
            board[TABLEAU+i][board[TABLEAU+i].high].visible = true

        tb.renderEverything((terminalWidth()-minWidth-2) div 2,0)
        tb.display()
        sleep(20)   # slows the program down so it doesn't re-render as much when there isn't anything going on - no more 17% cpu usage

main()