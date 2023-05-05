all: compile

compile:
	@-nim c -x --verbosity:0 --mm:arc --hints:off --warnings:off -d:release solitaire.nim

run:
	@nim c -r -x --verbosity:0 --mm:arc --hints:off --warnings:off -d:release solitaire.nim
	