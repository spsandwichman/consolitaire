import std/[os, strutils, random, terminal, sequtils]
randomize()

# nim c -r --warnings:off --hints:off  --verbosity:0 --mm:arc ./solitaire.nim

type Suit = enum
    Spades, Hearts, Clubs, Diamonds

type Card = object
    suit: Suit
    rank: int #1 = ace, 11 = jack, 12 = queen, 13 = king
    visible: bool

type Selection = object
    x: int
    y: int

var useSuitLetters = false

var selection = Selection(x:0,y:1)

var stock: seq[Card]
var waste: seq[Card]
var tableau: array[7, seq[Card]]
var foundations: array[4, seq[Card]]
var selected: seq[Card]

const emptyStackColor = fgCyan
const hiddenCardColor = fgBlue
const selectionColor = fgGreen

proc setFGC(s: ForegroundColor) =
    setForegroundColor(s)
    stdout.setStyle({styleBright})

proc popSingle(srcStack, dstStack: var seq[Card]) =
    dstStack.add srcStack[srcStack.high]
    srcStack.delete(srcStack.high)

proc popMultiple(srcStack, dstStack: var seq[Card], cardAmount: int) =
    dstStack = concat(dstStack, srcStack[(srcStack.high-cardAmount+1)..srcStack.high])
    srcStack.delete((srcStack.high-cardAmount+1)..srcStack.high)

proc displayCardStackOnBoard(stack: seq[Card], showHidden: bool, tableauCoord: int) =
    

    if stack.len == 0:
        setFGC(emptyStackColor)
        
        stdout.write( "╭─────────╮"); cursorDown(); cursorBackward(11)  
        stdout.write( "│         │"); cursorDown(); cursorBackward(11)
        stdout.write( "│         │"); cursorDown(); cursorBackward(11)
        stdout.write( "│    X    │"); cursorDown(); cursorBackward(11)
        stdout.write( "│         │"); cursorDown(); cursorBackward(11)
        stdout.write( "│         │"); cursorDown(); cursorBackward(11)
        stdout.write( "╰─────────╯")
        
        return


    for c in 0..stack.high:
        
        var suitChar = ""
        var rankChar = ""
        var isCardVisible = showHidden or stack[c].visible

        case stack[c].suit
        of Spades:
            suitChar = if useSuitLetters: "S" else: "♠"
            setFGC(fgWhite)
        of Hearts:
            suitChar = if useSuitLetters: "H" else: "♥"
            setFGC(fgRed)
        of Clubs:
            suitChar = if useSuitLetters: "C" else: "♣"
            setFGC(fgWhite)
        of Diamonds:
            suitChar = if useSuitLetters: "D" else: "♦"
            setFGC(fgRed)
        
        
        case stack[c].rank
        of 1:
            rankChar = "A ─"
        of 2,3,4,5,6,7,8,9:
            rankChar = $stack[c].rank & " ─"
        of 10:
            rankChar = "10 "
        of 11:
            rankChar = "J ─"
        of 12:
            rankChar = "Q ─"
        of 13:
            rankChar = "K ─"
        else:
            discard

        if not isCardVisible:
            setFGC(hiddenCardColor)

        if (selection.x == tableauCoord and selection.y <= (c+1)) and selection.y != 0:
            setFGC(selectionColor)

        if c == stack.high:

            if not isCardVisible:
                stdout.write( "╭─────────╮"); cursorDown(); cursorBackward(11)
            else:
                stdout.write( "╭ " & suitChar & " " & rankChar & "───╮"); cursorDown(); cursorBackward(11)
            
            stdout.write( "│         │"); cursorDown(); cursorBackward(11)
            stdout.write( "│         │"); cursorDown(); cursorBackward(11)
            stdout.write( "│         │"); cursorDown(); cursorBackward(11)
            stdout.write( "│         │"); cursorDown(); cursorBackward(11)
            stdout.write( "│         │"); cursorDown(); cursorBackward(11)
            stdout.write( "╰─────────╯"); cursorDown(); cursorBackward(11)
            
        else:
            if not isCardVisible:
                stdout.write("╭─────────╮"); cursorDown(); cursorBackward(11)
            else:
                stdout.write( "╭ " & suitChar & " " & rankChar & "───╮"); cursorDown(); cursorBackward(11)
    var f = 7+(if stack.len > 1: stack.len-1 else: 0)
    while f<19:
        stdout.write( "           "); cursorDown(); cursorBackward(11)
        f += 1
    stdout.write( "           ")
        

proc displayTopThreeHorizontally(s: seq[Card]) =
    if s.len == 0:
        setFGC(emptyStackColor)
        stdout.write( "╭─────────╮      "); cursorDown(); cursorBackward(17)  
        stdout.write( "│         │      "); cursorDown(); cursorBackward(17)
        stdout.write( "│         │      "); cursorDown(); cursorBackward(17)
        stdout.write( "│    X    │      "); cursorDown(); cursorBackward(17)
        stdout.write( "│         │      "); cursorDown(); cursorBackward(17)
        stdout.write( "│         │      "); cursorDown(); cursorBackward(17)
        stdout.write( "╰─────────╯      ")
        
        return

    let topThree = s[(max(0, s.high-2))..(s.high)]     # beautiful monstrosity
    for c in 0..topThree.high:

        var suitChar = ""
        var rankChar = ""
        let card = topThree[c]

        case card.suit
        of Spades:
            suitChar = if useSuitLetters: "S" else: "♠"
            setFGC(fgWhite)
        of Hearts:
            suitChar = if useSuitLetters: "H" else: "♥"
            setFGC(fgRed)
        of Clubs:
            suitChar = if useSuitLetters: "C" else: "♣"
            setFGC(fgWhite)
        of Diamonds:
            suitChar = if useSuitLetters: "D" else: "♦"
            setFGC(fgRed)
        
        
        case card.rank
        of 1:
            rankChar = "A "
        of 2,3,4,5,6,7,8,9:
            rankChar = $card.rank & " "
        of 10:
            rankChar = "10"
        of 11:
            rankChar = "J "
        of 12:
            rankChar = "Q "
        of 13:
            rankChar = "K "
        else:
            discard

        if (c == topThree.high) and (selection.x == 1 and selection.y == 0):
            setFGC(selectionColor)

        stdout.write( "╭─────────╮"); cursorDown(); cursorBackward(11)
        stdout.write( suitChar & "         │"); cursorDown(); cursorBackward(11)
        stdout.write( rankChar & "        │"); cursorDown(); cursorBackward(11)
        stdout.write( "│         │"); cursorDown(); cursorBackward(11)
        stdout.write( "│         │"); cursorDown(); cursorBackward(11)
        stdout.write( "│         │"); cursorDown(); cursorBackward(11)
        stdout.write( "╰─────────╯")

        cursorup(6); cursorBackward(8)

        

proc displayTop(s: seq[Card]) =
    if s.len == 0:
        setFGC(emptyStackColor)
        stdout.write( "╭─────────╮"); cursorDown(); cursorBackward(11)  
        stdout.write( "│         │"); cursorDown(); cursorBackward(11)
        stdout.write( "│  press  │"); cursorDown(); cursorBackward(11)
        stdout.write( "│ 'e' to  │"); cursorDown(); cursorBackward(11)
        stdout.write( "│ restock │"); cursorDown(); cursorBackward(11)
        stdout.write( "│         │"); cursorDown(); cursorBackward(11)
        stdout.write( "╰─────────╯")
        
    else:
        setFGC(hiddenCardColor)
        stdout.write( "╭─────────╮"); cursorDown(); cursorBackward(11)  
        stdout.write( "│         │"); cursorDown(); cursorBackward(11)
        stdout.write( "│  press  │"); cursorDown(); cursorBackward(11)
        stdout.write( "│ 'e' to  │"); cursorDown(); cursorBackward(11)
        stdout.write( "│ to draw │"); cursorDown(); cursorBackward(11)
        stdout.write( "│         │"); cursorDown(); cursorBackward(11)
        stdout.write( "╰─────────╯")

proc displayTopCardOfStack(s: seq[Card], numba: int) =
    if s.len == 0:
        setFGC(emptyStackColor)
        stdout.write( "╭─────────╮"); cursorDown(); cursorBackward(11)  
        stdout.write( "│         │"); cursorDown(); cursorBackward(11)
        stdout.write( "│         │"); cursorDown(); cursorBackward(11)
        stdout.write( "│    X    │"); cursorDown(); cursorBackward(11)
        stdout.write( "│         │"); cursorDown(); cursorBackward(11)
        stdout.write( "│         │"); cursorDown(); cursorBackward(11)
        stdout.write( "╰─────────╯")
        
    else:
        let card = s[s.high]

        var suitChar = ""
        var rankChar = ""

        case card.suit
        of Spades:
            suitChar = if useSuitLetters: "S" else: "♠"
            setFGC(fgWhite)
        of Hearts:
            suitChar = if useSuitLetters: "H" else: "♥"
            setFGC(fgRed)
        of Clubs:
            suitChar = if useSuitLetters: "C" else: "♣"
            setFGC(fgWhite)
        of Diamonds:
            suitChar = if useSuitLetters: "D" else: "♦"
            setFGC(fgRed)
        
        
        case card.rank
        of 1:
            rankChar = "A ─"
        of 2,3,4,5,6,7,8,9:
            rankChar = $card.rank & " ─"
        of 10:
            rankChar = "10 "
        of 11:
            rankChar = "J ─"
        of 12:
            rankChar = "Q ─"
        of 13:
            rankChar = "K ─"
        else:
            discard

        if selection.x == numba and selection.y == 0:
            setFGC(selectionColor)

        stdout.write( "╭ " & suitChar & " " & rankChar & "───╮"); cursorDown(); cursorBackward(11)
        stdout.write( "│         │"); cursorDown(); cursorBackward(11)
        stdout.write( "│         │"); cursorDown(); cursorBackward(11)
        stdout.write( "│         │"); cursorDown(); cursorBackward(11)
        stdout.write( "│         │"); cursorDown(); cursorBackward(11)
        stdout.write( "│         │"); cursorDown(); cursorBackward(11)
        stdout.write( "╰─────────╯")

proc updateStock() =
    setCursorPos(1,0)
    stock.displayTop()

proc updateWaste() =
    setCursorPos(13,0)
    waste.displayTopThreeHorizontally()

proc updateFoundations() = 
    setCursorPos(37,0)
    for i in 0..3:
        foundations[i].displayTopCardOfStack(i+3)
        cursorForward()
        setCursorYPos(0)

proc updateTableau() =
    setCursorPos(1,7)
    for i in 0..6:
        if tableau[i].len == 0: continue
        tableau[i][tableau[i].high].visible = true
    for i in 0..6:
        tableau[i].displayCardStackOnBoard(false, i)
        setCursorYPos(7)
        cursorForward()

proc updateAll() =

    eraseScreen()

    # display stock
    updateStock()

    # display waste
    updateWaste()

    # display foundations
    updateFoundations()

    # display tableau
    updateTableau()

# ------------------------------------ yo ------------------------------------ #

# construct and shuffle deck
for s in [Spades, Hearts, Clubs, Diamonds]:
    for r in 1..13:
        stock.add Card(suit: s, rank: r, visible: false)        
shuffle(stock)

# spread to tableau
for i in 0..6:
    for j in 0..i:
        popSingle(stock, tableau[i])

setFGC(fgWhite)
stdout.hideCursor()
stdout.write("use letters for suits? y/(any key) > ")
var suitLettersIn = getch().toLowerAscii()
useSuitLetters = (suitLettersIn == 'y')

# popMultiple(stock, foundations[0], 3)
# popMultiple(stock, foundations[1], 3)

setBackgroundColor(bgBlack)
updateAll()

while true: # main game loop



    # ------------------------------ handling input ------------------------------ #
    setFGC(fgWhite)
    setCursorPos(0,26)
    stdout.write($selection.x & ", " & $selection.y & "  |  " & $(tableau[selection.x].len-selection.y+1) & "     ")
    
    setCursorPos(0,27)
    stdout.write("Move selection with WASD, and press SPACE to move the selection to the next legal spot. Press K to exit.")
    var inChar = getch().toLowerAscii()

    case inChar
    of 'h':
        for i in 0..6:
            if tableau[i].len == 0: continue
            for card in 0..tableau[i].high:
                tableau[i][card].visible = true
        updateTableau()
    of 'e':
        if stock.len == 0:
            while waste.len > 0:
                popSingle(waste, stock)
            updateStock()
        else:
            popSingle(stock, waste)
        updateWaste()
        if stock.len == 0:
            updateStock()
    of 'k':
        setCursorPos(0,28)
        setForegroundColor(fgDefault)
        setBackgroundColor(bgDefault)
        stdout.styledWrite(resetStyle)
        quit(0)
    of ' ':
        if selection.x == 1 and selection.y == 0:
            popSingle(waste, selected)
        elif selection.x >= 3 and selection.x <= 6 and selection.y == 0: 
            popSingle(foundations[selection.x-3], selected)
        else:
            popMultiple(tableau[selection.x], selected, (tableau[selection.x].len-selection.y+1))
        updateAll()

    of 'w':
        if selection.y == 0:
            discard
        elif selection.y == 1 or not tableau[selection.x][selection.y-2].visible:
            if waste.len > 0:
                selection.x = 1
                selection.y = 0
                updateTableau()
                updateWaste()
                updateFoundations()
            elif foundations[0].len > 0:
                selection.x = 3
                selection.y = 0
                updateTableau()
                updateFoundations()
            elif foundations[1].len > 0:
                selection.x = 4
                selection.y = 0
                updateTableau()
                updateFoundations()
            elif foundations[2].len > 0:
                selection.x = 5
                selection.y = 0
                updateTableau()
                updateFoundations()
            elif foundations[3].len > 0:
                selection.x = 6
                selection.y = 0
                updateTableau()
                updateFoundations()
            else:
                discard
        else:
            selection.y -= 1
            updateTableau()
    of 's':
        if selection.y == 0:
            if tableau[selection.x].len == 0:
                for stack in 0..6:
                    if tableau[stack].len != 0: 
                        selection.y = tableau[stack].len
                updateWaste()
            else:
                selection.y = tableau[selection.x].len
            updateFoundations()
            updateTableau()
            updateWaste()
        else:
            if selection.y < tableau[selection.x].len:
                selection.y += 1
                updateTableau()


        #if tableau[selection.x][selection.y-1].visible:
    of 'd':
        if selection.y == 0:
            var startX = selection.x
            selection.x += 1
            while selection.x != startX:
                if selection.x > 6: selection.x -= 7
                if selection.x == 2: selection.x = 3
                if selection.x == 0: selection.x = 1
                if selection.x == 1:
                    if waste.len > 0: break
                else:
                    if foundations[selection.x-3].len > 0: break
                selection.x += 1

            updateWaste()
            updateFoundations()
        else:
            var nextStack = selection.x + 1
            nextStack = nextStack mod 7
            while tableau[nextStack].len == 0:
                inc nextStack
                nextStack = nextStack mod 7
            selection.x = nextStack
            selection.y = tableau[nextStack].len
            updateTableau()
    of 'a':
        if selection.y == 0:
            var startX = selection.x
            selection.x -= 1
            while selection.x != startX:
                if selection.x < 0: selection.x += 7
                if selection.x == 2: selection.x = 1
                if selection.x == 0: selection.x = 6
                if selection.x == 1:
                    if waste.len > 0: break
                else:
                    if foundations[selection.x-3].len > 0: break
                selection.x -= 1

            updateWaste()
            updateFoundations()
                
        else:
            var nextStack = selection.x - 1
            if nextStack < 0: nextStack += 7
            while tableau[nextStack].len == 0:
                dec nextStack
                if nextStack < 0: nextStack += 7
            selection.x = nextStack
            selection.y = tableau[nextStack].len
            updateTableau()
    else:
        discard


setCursorPos(0,28)
setForegroundColor(fgDefault)
setBackgroundColor(bgDefault)
stdout.styledWrite(resetStyle)
#stdout.write("")