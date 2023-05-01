import os
import illwill

type Suit = enum
    Spades, Hearts, Clubs, Diamonds

type Card = object
    suit: Suit
    rank: int #1 = ace, 11 = jack, 12 = queen, 13 = king
    visible: bool


var board: array[13, seq[Card]] # 0 = stock, 1 = waste, 2-5 is foundations, 6-12 is tableau

var useSuitLetters = false

proc generateCard(card: Card, dataOnLeft, ignoreHidden: bool): string =
    return ""

proc exitProc() {.noconv.} =
    illwillDeinit()
    showCursor()
    quit(0)

proc main() =
    illwillInit(fullscreen=true)
    setControlCHook(exitProc)
    hideCursor()

    
    while true:
        var tb = newTerminalBuffer(terminalWidth(), terminalHeight())

        var key = getKey()
        case key
            of Key.Q, Key.Escape: exitProc()
            else: discard
        
        if terminalWidth() < 86 or terminalHeight() < 26:
            tb.write(0, 0, "terminal window is (" & $terminalWidth() & ", " & $terminalHeight() & "), must be (>86, >26).")
            tb.write(0, 1, "please resize your terminal or press ESC or Q to quit.")
            tb.display
            continue

        tb.setForegroundColor(fgWhite)
        tb.write(terminalWidth()-4, terminalHeight()-1, "v1.0")
        tb.write(0, terminalHeight()-1, "solitaire")
        tb.resetAttributes()
        tb.write(" by ")
        tb.setForegroundColor(fgCyan)
        tb.write("sandwichman")
        tb.setForegroundColor(fgWhite)
        tb.write(((terminalWidth()-10) div 2), terminalHeight()-1, "use ESC or Q to quit")
        try:
            tb.display()
        except OSError: discard
        #sleep(20)

main()
