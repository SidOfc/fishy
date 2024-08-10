.PHONY: build
build:
	rm -rf Fishy.zip
	mkdir Fishy
	cp Fishy.{lua,toc} Fishy
	zip -r Fishy.zip Fishy
	rm -rf Fishy
