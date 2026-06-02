# CORS Configuration

To show images on the web version of this app, you must configure your Cloud Storage bucket to allow cross-origin access (CORS).


## Step 1: Download `gsutil`

Download the `gsutil` command line tool, which is a part of [Google Cloud CLI](https://cloud.google.com/storage/docs/gsutil_install). Then run:

```gcloud auth login```

to log into Google Cloud using your Firebase account.

## Step2: Deploy CORS Configuration

If you don't want any domain-based restrictions (the most common scenario), copy this JSON to a file named `cors.json`:

```json
[
  {
    "origin": ["*"],
    "method": ["GET"],
    "maxAgeSeconds": 3600
  }
]
```

Then run:

```gsutil cors set cors.json gs:<your-cloud-storage-bucket>```

to deploy the configuration file to your Cloud Storage bucket. You can find the bucket URL in Firebase Console.
