.PHONY: run
run: dist/elm.js yarn.lock
	node src/index.mjs

dist/elm.js: src/Compiler.elm
	elm make src/Compiler.elm --output dist/compiler.js

yarn.lock: package.json
	yarn
