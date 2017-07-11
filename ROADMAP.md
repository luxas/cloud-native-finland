### Roadmap for the site

It's very early days for this site / initiative.
Here are some technical TODOs for the site:

 - Monitoring the amount of requests / latency with Prometheus using the operator
 - Monitoring all Pods' CPU and memory usage with Heapster
 - Create a Kubernetes CronJob for snapshotting PV data and uploading somewhere
 - Store the LE certs in a PersistentVolume
 - More documentation how to install it yourself
 - Use `hostPort` instead of `hostNetwork` for the Traefik Pod
 - Create "fork me on Github" banner
 - Create a Slackin integration
