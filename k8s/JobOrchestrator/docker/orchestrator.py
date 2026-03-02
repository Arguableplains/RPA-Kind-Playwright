import redis
import json

REDIS_HOST = "redis-server.redis-server.svc.cluster.local"
REDIS_PORT = 6379
QUEUE_NAME = "task_queue"

r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)

task_json = r.rpop(QUEUE_NAME)

if not task_json:
    print("No task found.")
    exit(0)

task = json.loads(task_json)

task_type = task.get("taskType")

print(f"Received task type: {task_type}")

# Action based on TaskType
if task_type == "GENERATE_REPORT":
    print(f"Generating report for user {task['id']}")
    print(f"From {task['startDate']} to {task['endDate']}")

elif task_type == "SEND_EMAIL":
    print(f"Sending email to {task['to']}")

elif task_type == "CLEANUP_CACHE":
    print("Running cleanup process")

else:
    print("Unknown task type")