# Adding CORS to APIcast

This example shows how CORS ([Cross Origin Resource Sharing](https://developer.mozilla.org/en-US/docs/Web/HTTP/Access_control_CORS)) handling can be added to APIcast.

## How it works

There are two code snippets that do the following:

1. `apicast_cors.lua` is a custom module (see [this example](https://github.com/3scale/apicast/tree/master/examples/custom-module) for more info) that overrides the default APIcast's rewrite phase handler to include the following logic:

  when the request method is `OPTIONS`, and `Origin` and `Access-Control-Request-Method` headers are present, the request is considered to be CORS preflight request, and APIcast returns a `204` request with the response headers defined in `set_cors_headers()` method. In this case the request will not pass through 3scale access control.

2. `cors.conf` is a configuration file that should be added to `apicast.d` directory to be included in the configuration. It sets the CORS `Access-Control-Allow-*` response headers for each request (not only CORS preflight).

## Adding the customization to APIcast

**Note:** the example commands are supposed to be run from the root of the local copy of the `apicast` repository.

### Native APIcast

Place `apicast_cors.lua` to `apicast/src`, and `cors.conf` to `apicast/apicast.d` and start APIcast:

```
THREESCALE_PORTAL_ENDPOINT=https://ACCESS-TOKEN@ACCOUNT-admin.3scale.net APICAST_MODULE=apicast_cors bin/apicast
```

### Docker

Attach the above files as volumes to the container and set `APICAST_MODULE` environment variable.

```
docker run --name apicast --rm -p 8080:8080 -v $(pwd)/examples/cors/apicast_cors.lua:/opt/app-root/src/src/apicast_cors.lua:ro -v $(pwd)/examples/cors/cors.conf:/opt/app-root/src/apicast.d/cors.conf:ro -e THREESCALE_PORTAL_ENDPOINT=https://ACCESS-TOKEN@ACCOUNT-admin.3scale.net -e APICAST_MODULE=apicast_cors quay.io/3scale/apicast:master
```

### OpenShift

The customization can also be applied to APIcast deployed in OpenShift. There are several options to achieve it:

#### Rebuid the image

A new image with the customization can be rebuild, using a simple `Dockerfile` (save it in the current directory), such as:

```
FROM quay.io/3scale/apicast:master

# Copy customized source code to the appropriate directories
COPY ./examples/cors/apicast_cors.lua /opt/app-root/src/src/
COPY ./examples/cors/cors.conf /opt/app-root/src/apicast.d/
```

Build the image, push it to your Docker registry, then follow the normal deployment steps described in the [APIcast on OpenShift guide](/doc/openshift-guide.md). At the `oc new-app` step add the parameter `IMAGE_NAME`, replacing the placeholders with your own image nam:

```
oc new-app -f https://raw.githubusercontent.com/3scale/apicast/master/openshift/apicast-template.yml -p IMAGE_NAME=<YOUR_DOCKER_REGISTRY>/<USERNAME>/<YOUR_IMAGE_NAME>:<TAG>
```

Set the environment variable `APICAST_MODULE`:

```
oc env dc/apicast APICAST_MODULE=apicast_cors
```

Alternatively, you can add the above Dockerfile to your own fork of the `apicast` Git repository, and have OpenShift do the build:
```
oc new-build https://github.com/example/apicast --strategy=docker
```


#### Use ConfigMaps

You can add the customized files as ConfigMaps and mount them as volumes. You can use the template `apicast-cors.yml` provided in this example to deploy APIcast with CORS:

```
oc new-app -f $(pwd)/examples/cors/apicast-cors.yml
```

As in previous example, set the environment variable `APICAST_MODULE`:

```
oc env dc/apicast APICAST_MODULE=apicast_cors
```

The change can also be applied to an existing APIcast instance by adding the ConfigMaps from the template, and modifying the APIcast deployment configuration following the example in the template.
