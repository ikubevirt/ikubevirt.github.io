
.PHONY: build
build:
	@mkdocs build -d public -c

.PHONY: deploy
deploy:
	@python -m mkdocs gh-deploy --force -d public

.PHONY: serve
serve:
	@python -m mkdocs serve
