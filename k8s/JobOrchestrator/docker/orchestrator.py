import redis
import json
import time
from kubernetes import client, config

REDIS_HOST = "redis-server.redis-server.svc.cluster.local"
REDIS_PORT = 6379
QUEUE_NAME = "task_queue"

r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)

config.load_incluster_config()
k8s_batch = client.BatchV1Api()

def create_job(task_type, task_id, namespace="robots"):
    task_type_k8s = task_type.lower().replace("_", "-")
    job_manifest = {
        "apiVersion": "batch/v1",
        "kind": "Job",
        "metadata": {
            "generateName": f"{task_type_k8s}-",
            "namespace": namespace,
            "labels": {
                "taskType": task_type,
                "taskId": task_id
            }
        },
        "spec": {
            "ttlSecondsAfterFinished": 300,
            "backoffLimit": 3,
            "successfulJobsHistoryLimit": 1,
            "failedJobsHistoryLimit": 3,
            "template": {
                "spec": {
                    "restartPolicy": "OnFailure",
                    "containers": [{
                        "name": task_type_k8s,
                        "image": f"rpa_kind_playwright/{task_type_k8s}:1.0",
                        "env": [
                            {"name": "TASK_ID", "value": task_id},
                            {"name": "BROWSERLESS_HOST", "value": "browserless-service.browserless.svc.cluster.local"},
                            {"name": "BROWSERLESS_PORT", "value": "3000"}
                        ],
                        "envFrom": [
                            {"secretRef": {"name": "browserless-token"}}
                        ],
                        "volumeMounts": [
                            {"name": "output-volume", "mountPath": "/data/output"}
                        ]
                    }],
                    "volumes": [
                        {"name": "output-volume", "persistentVolumeClaim": {"claimName": "robots-output"}}
                    ]
                }
            }
        }
    }
    
    return k8s_batch.create_namespaced_job(namespace=namespace, body=job_manifest)

task_json = r.brpop(QUEUE_NAME, timeout=2)

if not task_json:
    print("No task found.")
    exit(0)

_, task_json = task_json  # brpop returns (key, value)
task = json.loads(task_json)

task_type = task.get("taskType")
task_id = task.get("id")

print(f"Received task type: {task_type}")

try:
    result = create_job(task_type, task_id)
    print(f"Created job: {result.metadata.name}")
except Exception as e:
    print(f"Failed to create job: {e}")