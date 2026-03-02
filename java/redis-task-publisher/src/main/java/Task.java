public class Task {
    private String taskType;
    private String id;
    private String startDate;
    private String endDate;

    public Task() {}

    public Task(String taskType, String id, String startDate, String endDate) {
        this.taskType = taskType;
        this.id = id;
        this.startDate = startDate;
        this.endDate = endDate;
    }

    public String getTaskType() { return taskType; }
    public void setTaskType(String taskType) { this.taskType = taskType; }
    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    public String getStartDate() { return startDate; }
    public void setStartDate(String startDate) { this.startDate = startDate; }
    public String getEndDate() { return endDate; }
    public void setEndDate(String endDate) { this.endDate = endDate; }
}
