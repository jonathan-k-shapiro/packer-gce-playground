# Building a GCE image using Packer

In this project, we're going to learn how to build a GCE image using packer. In particular, we want to build an image that includes a binary compliled from Golang which is set up to run as a service whenever a VM instantiated from the image boots up.

## Install packer (mac)

```sh
brew tap hashicorp/tap
brew install hashicorp/tap/packer
```

Verify by running `packer` without errors.

## Set up new GCP project

```sh
gcloud projects create "jks-gce-packer-240828"
```

It's helpful to re-init with `gcloud init`, selecting the new project id

Enable the project for billing:

* In Billing console, with project selected you'll see something like "this project has no linked billing account"
* Follow prompts to link the project to the billing account

The following command is required, but will not work until billing is enabled

```sh
gcloud services enable compute.googleapis.com
```

Create GCP application default credentials for the local machine

```sh
gcloud auth application-default login
```

## Packer build command

```sh
packer init build.pkr.hcl 
packer build --force -var-file=variables.pkrvars.hcl build.pkr.hcl
```

`packer build` notes:

* Use `--force` to allow rebuilding an image with the same name multiple times (deletes any pre-existing image)
* Use `--debug` to allow  stepping through the build process. You can ssh into the build instance and debug lots of problems this way. Packer will drop a PEM file in the working directory which you can use to ssh in:  `ssh -i <pem.file> ubuntu@<external_ip>`

## Open a firewall to enable remote testing

Create a new firewall rule that allows INGRESS tcp:8080 with VMs containing tag 'allow-tcp-8080'

```sh
gcloud compute firewall-rules create rule-allow-tcp-8080 --source-ranges 0.0.0.0/0 --target-tags allow-tcp-8080 --allow tcp:8080
```

## testing the image

Create a vm manually, then try to talk to `profilesvc` on port 8080. Note that the full path to the packer-created image is `projects/jks-gce-packer-240828/global/images/my-custom-image-1234` appears in the `--create-disk` option below.

```sh
gcloud compute instances create instance-20240830-193224 \
    --project=jks-gce-packer-240828 \
    --zone=us-east4-a \
    --machine-type=e2-micro \
    --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account=492756965829-compute@developer.gserviceaccount.com \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append \
    --tags=allow-tcp-8080 \
    --create-disk=auto-delete=yes,boot=yes,device-name=instance-20240830-193224,image=projects/jks-gce-packer-240828/global/images/my-custom-image-1234,mode=rw,size=20,type=pd-balanced \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ec-src=vm_add-gcloud \
    --reservation-affinity=any
```

The following works (because the firewall rule targeting tag `allow-tcp-8080` allows ingress on port 8080

```sh
## Output from compute instances create command above...
## Created [https://www.googleapis.com/compute/v1/projects/jks-gce-packer-240828/zones/us-east4-a/instances/instance-20240830-193224].
## NAME                      ZONE        MACHINE_TYPE  PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP   STATUS
## instance-20240830-193224  us-east4-a  e2-micro                   10.150.0.29  34.48.22.171  RUNNING

curl -d '{"id":"1234","Name":"Go Kit"}' -H "Content-Type: application/json" -X POST http://34.48.22.171:8080/profiles/
## {}

curl http://34.48.22.171:8080/profiles/1234
## {"profile":{"id":"1234","name":"Go Kit"}}
```
