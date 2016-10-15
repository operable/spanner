ci: deps compile test

deps:
	mix deps.get

compile:
	mix compile --warnings-as-errors

test:
	mix test

.PHONY: test
