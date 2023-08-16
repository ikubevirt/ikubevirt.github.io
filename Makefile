
.PHONY: build
build:
	@mkdocs build -d public -c

.PHONY: deploy
deploy:
	@mkdocs gh-deploy -d public

.PHONY: serve
serve:
	@python -m mkdocs serve
