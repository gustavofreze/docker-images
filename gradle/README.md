# Gradle

* [Quick reference](#reference)
* [Supported tags and respective Dockerfile links](#tags)
* [What is Gradle?](#gradle)
* [How to use this image?](#use)

<div id='reference'></div> 

## Quick reference

- **Maintained by**: [Gustavo](https://github.com/gustavofreze)

<div id='tags'></div> 

## Supported tags and respective Dockerfile links

- [`7.1.1`](https://github.com/gustavofreze/docker-images/blob/main/gradle/7.1.1/Dockerfile)

<div id='gradle'></div> 

## What is Gradle?

[Gradle](https://gradle.org) is an open-source build automation tool focused on flexibility and performance. Gradle build scripts
are written using a Groovy or Kotlin DSL.

<div id='use'></div> 

## How to use this image?

Create a Dockerfile in your project:

```dockerfile
FROM gustavofreze/gradle:7.1.1
COPY 7.1.1 /usr/src/myapp
WORKDIR /usr/src/myapp
```

You can then run and build the Docker image:

```shell
> docker build -t my-gradle-app .
```

After the image is built:

```shell
> docker run -it --rm --name my-running-app my-gradle-app
```
