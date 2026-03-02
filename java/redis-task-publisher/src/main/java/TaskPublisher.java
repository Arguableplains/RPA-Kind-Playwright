import redis.clients.jedis.Jedis;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.UUID;

public class TaskPublisher {

    private static final String REDIS_HOST = "redis-server.redis-server.svc.cluster.local";
    private static final int REDIS_PORT = 6379;
    private static final String QUEUE_NAME = "task_queue";

    private static final ObjectMapper mapper = new ObjectMapper();

    public static void main(String[] args) {
        try (Jedis jedis = new Jedis(REDIS_HOST, REDIS_PORT)) {

            TaskType randomType = TaskType.values()[(int) (Math.random() * TaskType.values().length)];

            Task task = new Task(
                    randomType.name(),
                    UUID.randomUUID().toString(),
                    "2026-03-01",
                    "2026-03-31"
            );

            String jsonTask = mapper.writeValueAsString(task);

            jedis.rpush(QUEUE_NAME, jsonTask);

            System.out.println("Task pushed to Redis:");
            System.out.println(jsonTask);

        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
