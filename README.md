# Adapter for MQTT <-> Google Cloud Pub/Sub

The adapter interfaces with RabbitMQ (any AMQP-compliant broker should work), and sends/receives messages to Google Cloud Pub/Sub.

## Deprecation Notice:

Now that Google's [Cloud IoT Core](https://cloud.google.com/iot-core/) has gone GA, we recommend that people use IoT Core instead of this IOT Adapter. IoT Core will scale far beyond a single RabbitMQ instance, and does not require management of a VM. It also has a stronger device authentication model.

The gcp-iot-adapter will remain available, but will not be actively maintained.

## Super-quick-start:

Make sure that docker is installed, then run this:

 `./build_with_docker.sh`

You'll end up with a tarball: `amqp_pubsub.tar.gz` and a Debian package: `gcp-iot-adapter_*.deb`.  All dependencies are included.

See the [GCP IoT Connection Broker Quickstart](https://docs.google.com/document/d/1vp4VY1SiconpbxyGpRqshwfqJV-rBTTt2sX4oJyYQYU/edit?usp=sharing) for a walkthrough.

## Not-so-quick start:

See the `build_adapter.sh` script.

## Using the adapter

Install the adapter on the server running RabbitMQ. Edit the config file: `/etc/gcp-iot-adapter.conf`. Restart the service. See the Quickstart for more info.

## Known Issues/Limitations

* MQTT Topic names should not have periods `.` in them. This is the separator used in AMQP topics.
* The adapter doesn't support TLS for the connection to RabbitMQ - but this shouldn't be a problem when running on the local RabbitMQ server.  It _does_ connect to Pub/Sub via TLS.
* Buildng the adapter from scratch requires Erlang 18.3 and Elixir 1.2. The packages (tarball and .deb) include this, and building with Docker will take care of those dependencies.


