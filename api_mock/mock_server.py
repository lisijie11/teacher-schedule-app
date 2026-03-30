#!/usr/bin/env python3
"""
模拟教务系统API的Flask服务器
为教师日程应用提供Mock数据
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
import json
from datetime import datetime, timedelta
import random

app = Flask(__name__)
CORS(app)  # 允许跨域请求

# 模拟教师信息数据
TEACHER_INFO = {
    "teacher_id": "LSJ2024",
    "name": "李思杰",
    "department": "数字媒体与设计学院",
    "university": "广东东软学院",
    "position": "讲师",
    "avatar_url": "https://example.com/avatar.webp"
}

# 模拟课程分类数据
COURSES_DATA = {
    "courses": [
        {
            "course_id": "DM101",
            "course_name": "数字合成技术（AE）",
            "course_code": "DM101",
            "credits": 3,
            "hours_per_week": 3,
            "semester": "2024-2025-2",
            "classroom": "多媒体实验室302",
            "weeks": "1-16周",
            "students_count": 45,
            "department": "数字媒体与设计学院",
            "description": "Adobe After Effects数字合成技术基础与高级应用"
        },
        {
            "course_id": "DM202",
            "course_name": "数字调色（达芬奇）",
            "course_code": "DM202",
            "credits": 2,
            "hours_per_week": 2,
            "semester": "2024-2025-2",
            "classroom": "影视后期实验室408",
            "weeks": "1-16周",
            "students_count": 30,
            "department": "数字媒体与设计学院",
            "description": "DaVinci Resolve数字调色理论与实践"
        },
        {
            "course_id": "DM303",
            "course_name": "影视综合创作",
            "course_code": "DM303",
            "credits": 4,
            "hours_per_week": 4,
            "semester": "2024-2025-2",
            "classroom": "综合创作实验室101",
            "weeks": "1-16周",
            "students_count": 35,
            "department": "数字媒体与设计学院",
            "description": "影视项目从策划到制作的全流程实践"
        },
        {
            "course_id": "CM101",
            "course_name": "传播学",
            "course_code": "CM101",
            "credits": 2,
            "hours_per_week": 2,
            "semester": "2024-2025-2",
            "classroom": "教学楼A302",
            "weeks": "1-8周",
            "students_count": 60,
            "department": "数字媒体与设计学院",
            "description": "传播学基础理论与新媒体传播"
        }
    ]
}

# 模拟每周课表数据
def generate_weekly_schedule(teacher_id):
    """生成模拟的每周课表"""
    # 基本时间段定义 (对应Flutter中的ScheduleMode)
    periods = [
        {"index": 0, "name": "第一节", "start": "08:00", "end": "08:45"},
        {"index": 1, "name": "第二节", "start": "08:55", "end": "09:40"},
        {"index": 2, "name": "第三节", "start": "10:00", "end": "10:45"},
        {"index": 3, "name": "第四节", "start": "10:55", "end": "11:40"},
        {"index": 4, "name": "第五节", "start": "14:00", "end": "14:45"},
        {"index": 5, "name": "第六节", "start": "14:55", "end": "15:40"},
        {"index": 6, "name": "第七节", "start": "16:00", "end": "16:45"},
        {"index": 7, "name": "第八节", "start": "16:55", "end": "17:40"},
        {"index": 8, "name": "第九节", "start": "19:00", "end": "19:45"},
        {"index": 9, "name": "第十节", "start": "19:55", "end": "20:40"},
    ]
    
    # 工作日课程安排
    weekday_courses = [
        # 周一
        {"day": 1, "period": 0, "course_id": "DM101", "classroom": "多媒体实验室302"},
        {"day": 1, "period": 1, "course_id": "DM101", "classroom": "多媒体实验室302"},
        {"day": 1, "period": 2, "course_id": "CM101", "classroom": "教学楼A302"},
        # 周二
        {"day": 2, "period": 4, "course_id": "DM202", "classroom": "影视后期实验室408"},
        {"day": 2, "period": 5, "course_id": "DM202", "classroom": "影视后期实验室408"},
        # 周三
        {"day": 3, "period": 0, "course_id": "DM303", "classroom": "综合创作实验室101"},
        {"day": 3, "period": 1, "course_id": "DM303", "classroom": "综合创作实验室101"},
        {"day": 3, "period": 2, "course_id": "DM303", "classroom": "综合创作实验室101"},
        # 周四 - 无课（准备时间）
        # 周五
        {"day": 5, "period": 4, "course_id": "DM101", "classroom": "多媒体实验室302"},
        {"day": 5, "period": 5, "course_id": "DM101", "classroom": "多媒体实验室302"},
    ]
    
    # 周末安排（汕尾校区，假设周五晚上到周日）
    weekend_courses = [
        {"day": 5, "period": 8, "course_id": "DM202", "classroom": "汕尾校区实验室201", "special_note": "汕尾校区"},
        {"day": 5, "period": 9, "course_id": "DM202", "classroom": "汕尾校区实验室201", "special_note": "汕尾校区"},
        {"day": 6, "period": 0, "course_id": "DM101", "classroom": "汕尾校区实验室202", "special_note": "汕尾校区"},
        {"day": 6, "period": 1, "course_id": "DM101", "classroom": "汕尾校区实验室202", "special_note": "汕尾校区"},
    ]
    
    return {
        "teacher_id": teacher_id,
        "periods": periods,
        "weekday_schedule": weekday_courses,
        "weekend_schedule": weekend_courses,
        "last_updated": datetime.now().isoformat()
    }

# 模拟任务数据
def generate_tasks():
    """生成模拟的教学任务数据"""
    tasks = []
    
    # 各种任务类型
    task_types = [
        {"type": "备课", "icon": "book", "color": "#FF6B6B"},
        {"type": "批改作业", "icon": "edit", "color": "#4ECDC4"},
        {"type": "会议", "icon": "groups", "color": "#45B7D1"},
        {"type": "教研", "icon": "science", "color": "#96CEB4"},
        {"type": "论文", "icon": "description", "color": "#FFEAA7"},
        {"type": "监考", "icon": "assignment", "color": "#DDA0DD"},
    ]
    
    # 生成最近一周的任务
    today = datetime.now()
    for i in range(10):
        task_type = random.choice(task_types)
        days_offset = random.randint(-2, 5)
        due_date = today + timedelta(days=days_offset)
        
        task = {
            "task_id": f"TASK{i+1:03d}",
            "title": f"{task_type['type']}：{random.choice(['周报', '教案', '期中检查', '期末评审', '学生指导'])}",
            "description": f"需要完成{random.choice(['第3章', '第5-7节', '实验项目', '案例分析'])}相关内容",
            "type": task_type['type'],
            "icon": task_type['icon'],
            "color": task_type['color'],
            "due_date": due_date.strftime("%Y-%m-%d"),
            "priority": random.choice(["低", "中", "高"]),
            "status": random.choice(["待处理", "进行中", "已完成"]),
            "estimated_hours": random.randint(1, 4),
            "course_id": random.choice(["DM101", "DM202", "DM303", "CM101"]),
            "created_at": today.strftime("%Y-%m-%d %H:%M:%S"),
        }
        tasks.append(task)
    
    return {"tasks": tasks}

@app.route('/')
def index():
    return jsonify({"message": "教师教务系统Mock API服务运行中", "version": "1.0.0"})

@app.route('/api/teacher/info', methods=['GET'])
def get_teacher_info():
    """获取教师基本信息"""
    return jsonify(TEACHER_INFO)

@app.route('/api/teacher/courses', methods=['GET'])
def get_teacher_courses():
    """获取教师所授课程列表"""
    semester = request.args.get('semester', '2024-2025-2')
    # 这里可以按学期过滤
    filtered_courses = [c for c in COURSES_DATA['courses'] if c['semester'] == semester]
    return jsonify({
        "semester": semester,
        "courses": filtered_courses,
        "total": len(filtered_courses)
    })

@app.route('/api/schedule/weekly', methods=['GET'])
def get_weekly_schedule():
    """获取每周课表"""
    teacher_id = request.args.get('teacher_id', 'LSJ2024')
    week = request.args.get('week', None)  # 可选：指定周次
    
    schedule = generate_weekly_schedule(teacher_id)
    if week:
        schedule['current_week'] = week
    
    return jsonify(schedule)

@app.route('/api/schedule/daily', methods=['GET'])
def get_daily_schedule():
    """获取当日课表"""
    teacher_id = request.args.get('teacher_id', 'LSJ2024')
    date_str = request.args.get('date', datetime.now().strftime("%Y-%m-%d"))
    
    try:
        date_obj = datetime.strptime(date_str, "%Y-%m-%d")
        day_of_week = date_obj.weekday() + 1  # 1-7, 1=周一
        
        # 生成完整周表，然后提取当日
        weekly = generate_weekly_schedule(teacher_id)
        
        if day_of_week <= 5:  # 工作日
            day_courses = [c for c in weekly['weekday_schedule'] if c['day'] == day_of_week]
        else:  # 周末
            day_courses = [c for c in weekly['weekend_schedule'] if c['day'] == day_of_week]
        
        # 补充课程详情
        detailed_courses = []
        for course in day_courses:
            course_detail = next((c for c in COURSES_DATA['courses'] if c['course_id'] == course['course_id']), {})
            detailed_courses.append({**course, **course_detail})
        
        return jsonify({
            "date": date_str,
            "day_of_week": day_of_week,
            "courses": detailed_courses,
            "total_courses": len(detailed_courses),
            "total_hours": len(detailed_courses)  # 简化：每节课1小时
        })
    except ValueError:
        return jsonify({"error": "日期格式错误，请使用YYYY-MM-DD格式"}), 400

@app.route('/api/tasks', methods=['GET'])
def get_tasks():
    """获取教学任务"""
    status = request.args.get('status', None)  # 可选：按状态过滤
    course_id = request.args.get('course_id', None)  # 可选：按课程过滤
    
    tasks_data = generate_tasks()
    filtered_tasks = tasks_data['tasks']
    
    if status:
        filtered_tasks = [t for t in filtered_tasks if t['status'] == status]
    if course_id:
        filtered_tasks = [t for t in filtered_tasks if t['course_id'] == course_id]
    
    return jsonify({
        "tasks": filtered_tasks,
        "total": len(filtered_tasks),
        "filters": {
            "status": status,
            "course_id": course_id
        }
    })

@app.route('/api/classrooms/available', methods=['GET'])
def get_available_classrooms():
    """查询可用教室"""
    date_str = request.args.get('date', datetime.now().strftime("%Y-%m-%d"))
    period = request.args.get('period', None)
    building = request.args.get('building', None)
    
    # 模拟可用教室数据
    classrooms = [
        {"room_id": "A301", "building": "教学楼A", "capacity": 60, "type": "多媒体教室", "available": True},
        {"room_id": "A302", "building": "教学楼A", "capacity": 60, "type": "多媒体教室", "available": True},
        {"room_id": "A303", "building": "教学楼A", "capacity": 45, "type": "普通教室", "available": False},
        {"room_id": "B201", "building": "教学楼B", "capacity": 80, "type": "阶梯教室", "available": True},
        {"room_id": "LAB302", "building": "实验室楼", "capacity": 35, "type": "多媒体实验室", "available": True},
        {"room_id": "LAB408", "building": "实验室楼", "capacity": 30, "type": "影视后期实验室", "available": True},
        {"room_id": "LAB101", "building": "实验室楼", "capacity": 40, "type": "综合创作实验室", "available": True},
    ]
    
    # 应用过滤条件
    available_rooms = [r for r in classrooms if r['available']]
    if building:
        available_rooms = [r for r in available_rooms if r['building'] == building]
    
    return jsonify({
        "date": date_str,
        "period": period,
        "building": building,
        "classrooms": available_rooms,
        "total_available": len(available_rooms)
    })

@app.route('/api/system/health', methods=['GET'])
def health_check():
    """健康检查接口"""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "service": "teacher-system-mock-api",
        "version": "1.0.0"
    })

if __name__ == '__main__':
    print("启动教师教务系统Mock API服务...")
    print("API端点:")
    print("  GET /api/teacher/info     - 教师信息")
    print("  GET /api/teacher/courses  - 课程列表")
    print("  GET /api/schedule/weekly  - 周课表")
    print("  GET /api/schedule/daily   - 日课表")
    print("  GET /api/tasks            - 教学任务")
    print("  GET /api/classrooms/available - 可用教室")
    print("  GET /api/system/health    - 健康检查")
    print("\n服务地址: http://127.0.0.1:5000")
    app.run(host='0.0.0.0', port=5000, debug=True)