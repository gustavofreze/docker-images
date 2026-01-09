# Python

* [Quick reference](#reference)
* [Supported tags and respective Dockerfile links](#tags)
* [How to use this image?](#use)
* [Extensions and tools](#extensions)
    - [Poetry](#poetry)

<div id='reference'></div> 

## Quick reference

- **Maintained by**: [Gustavo](https://github.com/gustavofreze)

<div id='tags'></div> 

## Supported tags and respective Dockerfile links

[`3.14-alpine`](https://github.com/gustavofreze/docker-images/blob/main/images/python/3.14/alpine/Dockerfile)

<div id='use'></div> 

## How to use this image?

### CLI

#### Running directly

```shell
docker run --rm -v $(pwd):/var/www/html gustavofreze/python:3.14-alpine python your-script.py
```

#### Using as base image

Create a Dockerfile in your project:

```dockerfile
FROM gustavofreze/python:3.14-alpine
COPY . /var/www/html
WORKDIR /var/www/html
RUN poetry install --no-root --only main
CMD ["python", "your-script.py"]
```

Build and run:

```shell
docker build -t my-python-app .
docker run --rm my-python-app
```

<div id='extensions'></div> 

## Extensions and tools

Extensions and tools added to this image.

<div id='poetry'></div> 

### Poetry

[Poetry](https://python-poetry.org/docs)  is a tool for dependency management and packaging in Python. It allows you to
declare the libraries your project depends on, and it will manage (install/update) them for you. Poetry offers a
lockfile
to ensure repeatable installs, and can build your project for distribution.
