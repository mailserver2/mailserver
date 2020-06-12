# About Versioning

This guidelines apply to versioning of docker images in mailserver2 repos:

- mailserver
- debian-mail-overlay
- postfixadmin
- rainloop

Historically the old [hardware/debian-mail-overlay](https://hub.docker.com/r/hardware/debian-mail-overlay/tags) image seemed to be versioned after `rspamd` it includes. However, apart of `rspamd` the image contains a lot of other differently versioned software. In this regard, it's more logical to have an independent version, and note down the version of individual software component in the commit messages and/or release history. 

For `rainloop` and `postfixadmin` it makes sense to continue to version the images after the respective software versions, since it's not likely that they may require a version bump for any other reason.

In certain case it's also possible for the `Dockerfile` itself to change without individual components updates. Finally, it could be that the `Dockerfile` does not change either, but the change is effected by update in an upstream software repository, for example `clamav` updates in `mailserver` are handled this way.

Follow these steps when an update is ready to be pushed to Docker Hub:

- Tag the current GitHub commit in the `mailserver2` repo with the next version, e.g. `git tag -a v1.0.1 -m "update postfixadmin to version 1.0.1, ... other changes here"`
- Build the new image
- Label it with the version you tagged the current commit with
- Push this image version with the label above as well as with the `latest` label

## Build Example

```
docker build . -t debian-mail-overlay
docker tag debian-mail-overlay mailserver2/debian-mail-overlay:0.0.0
docker push mailserver2/debian-mail-overlay:0.0.0
docker tag debian-mail-overlay mailserver2/debian-mail-overlay:latest
docker push mailserver2/debian-mail-overlay:latest
```

